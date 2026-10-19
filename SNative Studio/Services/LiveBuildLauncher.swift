import AppKit
import Foundation

enum Clipboard {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

enum LiveIPACheck {
    static func exists(_ path: String) -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
        guard let values = try? fileManager.attributesOfItem(atPath: path),
              let number = values[.size] as? NSNumber else { return false }
        return number.int64Value > 0
    }
}

protocol BuildLaunching: Sendable {
    func make(_ command: BuildCommand) -> any RunningBuild
}

protocol RunningBuild: AnyObject, Sendable {
    var onLine: (@Sendable (String) -> Void)? { get set }
    var onExit: (@Sendable (Int32) -> Void)? { get set }
    func start() throws
    func cancel()
}

struct FoundationBuildLauncher: BuildLaunching {
    func make(_ command: BuildCommand) -> any RunningBuild {
        LiveBuildProcess(command: command)
    }
}

private final class ExitBox: @unchecked Sendable {
    var code: Int32 = 1
}

private final class LineBuffer: @unchecked Sendable {
    private var pending = Data()
    private let lock = NSLock()

    func append(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pending.append(data)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            var chunk = pending.prefix(upTo: newline)
            pending.removeSubrange(..<pending.index(after: newline))
            if chunk.last == 0x0D { chunk.removeLast() }
            lines.append(String(decoding: chunk, as: UTF8.self))
        }
        return lines
    }
}

@_silgen_name("proc_listchildpids")
private func proc_listchildpids(_ parent: Int32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

private enum ProcessTree {
    static func terminate(pid: Int32) {
        for child in children(of: pid) {
            terminate(pid: child)
        }
        kill(pid, SIGTERM)
    }

    private static func children(of pid: Int32) -> [Int32] {
        var buffer = [Int32](repeating: 0, count: 256)
        let bytes = buffer.withUnsafeMutableBytes { raw -> Int32 in
            guard let base = raw.baseAddress else { return 0 }
            return proc_listchildpids(pid, base, Int32(raw.count))
        }
        guard bytes > 0 else { return [] }
        let count = min(buffer.count, Int(bytes) / MemoryLayout<Int32>.size)
        return Array(buffer.prefix(count))
    }
}

private final class LiveBuildProcess: RunningBuild, @unchecked Sendable {
    var onLine: (@Sendable (String) -> Void)?
    var onExit: (@Sendable (Int32) -> Void)?

    private let command: BuildCommand
    private let process = Process()
    private var didStart = false

    init(command: BuildCommand) {
        self.command = command
    }

    func start() throws {
        guard !didStart else { return }
        didStart = true
        let output = onLine
        let exit = onExit
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.environment = command.environment
        process.currentDirectoryURL = URL(fileURLWithPath: command.workingDirectory, isDirectory: true)
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        let group = DispatchGroup()
        let status = ExitBox()
        group.enter()
        process.terminationHandler = { process in
            status.code = process.terminationStatus
            group.leave()
        }
        do {
            try process.run()
        } catch {
            group.leave()
            throw error
        }
        PipeReader(handle: stdout.fileHandleForReading, deliver: output).start(group: group)
        PipeReader(handle: stderr.fileHandleForReading, deliver: output).start(group: group)
        group.notify(queue: .main) {
            exit?(status.code)
        }
    }

    func cancel() {
        guard process.isRunning else { return }
        ProcessTree.terminate(pid: process.processIdentifier)
    }

}

private final class PipeReader: @unchecked Sendable {
    private let handle: FileHandle
    private let deliver: (@Sendable (String) -> Void)?
    private let buffer = LineBuffer()

    init(handle: FileHandle, deliver: (@Sendable (String) -> Void)?) {
        self.handle = handle
        self.deliver = deliver
    }

    func start(group: DispatchGroup) {
        group.enter()
        Thread.detachNewThread { [self] in
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                let lines = buffer.append(data)
                guard !lines.isEmpty else { continue }
                DispatchQueue.main.async {
                    lines.forEach { self.deliver?($0) }
                }
            }
            group.leave()
        }
    }
}
