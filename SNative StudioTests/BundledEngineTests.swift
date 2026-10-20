import XCTest
@testable import SNativeStudio

final class BundledEngineTests: XCTestCase {
    func testPackagedEngineWinsOverAnExternalCheckout() throws {
        let packaged = try makeEngine()
        let external = try makeEngine()
        defer { try? FileManager.default.removeItem(at: packaged) }
        defer { try? FileManager.default.removeItem(at: external) }
        let start = external.appendingPathComponent("anidado/nota.txt")
        try FileManager.default.createDirectory(at: start.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("nota".utf8).write(to: start)

        let resolved = EngineLocator.resolve(packagedDirectory: packaged, externalCandidates: [start])
        XCTAssertEqual(resolved, .packaged(packaged.standardizedFileURL))
        XCTAssertEqual(EngineLocator.locate(startingAt: [start], packagedDirectory: packaged)?.path, packaged.standardizedFileURL.path)
    }

    func testIncompletePackagedEngineDoesNotFallBack() throws {
        let resources = try makeTemporaryDirectory()
        let packaged = BundledLayout.engineDirectory(resources: resources)
        let external = try makeEngine()
        defer { try? FileManager.default.removeItem(at: resources) }
        defer { try? FileManager.default.removeItem(at: external) }
        try writeFile(packaged.appendingPathComponent(EngineLocator.scriptRelativePath), contents: "script")
        let start = external.appendingPathComponent("nota.txt")
        try Data("nota".utf8).write(to: start)

        let resolved = EngineLocator.resolve(packagedDirectory: packaged, externalCandidates: [start])
        guard case .incomplete(let directory, let missing) = resolved else {
            return XCTFail("Se esperaba un motor incompleto, llegó \(resolved)")
        }
        XCTAssertEqual(directory.path, packaged.standardizedFileURL.path)
        XCTAssertEqual(missing, [EngineLocator.extractorRelativePath, EngineLocator.translatorRelativePath])
        XCTAssertNil(EngineLocator.locate(startingAt: [start], packagedDirectory: packaged))

        let planner = LiveBuildPlanner(
            candidates: [start],
            packagedEngineDirectory: packaged,
            locator: FileSystemLocator(directories: []),
            missingPythonModules: [],
            environment: [:]
        )
        let result = planner.plan(draft: ProjectDraft.blank(), allowOverwrite: false)
        guard case .blocked(let message) = result else {
            return XCTFail("Se esperaba un bloqueo, llegó \(result)")
        }
        XCTAssertTrue(message.contains("incompleto"))
        XCTAssertTrue(message.contains(EngineLocator.translatorRelativePath))
        XCTAssertTrue(message.contains("no descarga"))
        XCTAssertFalse(message.contains(external.path))
    }

    func testMissingPackagedDirectoryFallsBackToTheExternalCheckout() throws {
        let resources = try makeTemporaryDirectory()
        let absent = BundledLayout.engineDirectory(resources: resources)
        let external = try makeEngine()
        defer { try? FileManager.default.removeItem(at: resources) }
        defer { try? FileManager.default.removeItem(at: external) }
        let start = external.appendingPathComponent("anidado/nota.txt")
        try FileManager.default.createDirectory(at: start.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("nota".utf8).write(to: start)

        XCTAssertFalse(FileManager.default.fileExists(atPath: absent.path))
        XCTAssertEqual(
            EngineLocator.resolve(packagedDirectory: absent, externalCandidates: [start]),
            .external(external.standardizedFileURL)
        )
    }

    func testAbsentEngineExplainsWhereToLookAndDoesNotOfferADownload() {
        let absent = EngineLocator.resolve(packagedDirectory: nil, externalCandidates: [])
        XCTAssertEqual(absent, .absent)
        XCTAssertTrue(EngineLocator.absentMessage.contains("No se encuentra el motor"))
        XCTAssertTrue(EngineLocator.absentMessage.contains("Contents/Resources/Engine"))
        XCTAssertTrue(EngineLocator.absentMessage.contains("No lo descarga"))
        let result = BuildPlanner.decide(
            draft: ProjectDraft.blank(),
            facts: BuildFacts(
                engineRoot: nil,
                scriptExists: false,
                translatorExists: false,
                tools: [:],
                missingPythonModules: [],
                environment: [:],
                files: [:],
                siblingNSPNames: [],
                profileIPANames: [:],
                prefersPackagedTools: false
            ),
            allowOverwrite: false
        )
        guard case .blocked(let message) = result else {
            return XCTFail("Se esperaba un bloqueo, llegó \(result)")
        }
        XCTAssertEqual(message, EngineLocator.absentMessage)
    }

    func testPackagedExecutableWinsOverALaterExternalDirectory() throws {
        let resources = try makeTemporaryDirectory()
        let external = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: resources) }
        defer { try? FileManager.default.removeItem(at: external) }
        let packagedTool = BundledLayout.toolsDirectory(resources: resources).appendingPathComponent("bin/xcodegen")
        let externalTool = external.appendingPathComponent("xcodegen")
        try writeExecutable(packagedTool)
        try writeExecutable(externalTool)

        let locator = FileSystemLocator(directories: [
            packagedTool.deletingLastPathComponent().path,
            external.path
        ])
        XCTAssertEqual(locator.path(for: "xcodegen"), packagedTool.path)
        XCTAssertNil(locator.path(for: "dotnet"))
    }

    func testMissingToolsDirectoryStillFindsAnExternalExecutable() throws {
        let resources = try makeTemporaryDirectory()
        let external = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: resources) }
        defer { try? FileManager.default.removeItem(at: external) }
        let externalTool = external.appendingPathComponent("zstd")
        try writeExecutable(externalTool)
        let directories = FileSystemLocator.defaultDirectories(resources: resources).filter { directory in
            directory.hasPrefix(resources.path)
        } + [external.path]
        let locator = FileSystemLocator(directories: directories)
        XCTAssertFalse(FileManager.default.fileExists(atPath: BundledLayout.toolsDirectory(resources: resources).path))
        XCTAssertEqual(locator.path(for: "zstd"), externalTool.path)
        let toolsBin = BundledLayout.toolsDirectory(resources: resources).appendingPathComponent("bin").path
        XCTAssertEqual(directories.first, toolsBin)
        let defaults = FileSystemLocator.defaultDirectories(resources: resources)
        XCTAssertLessThan(defaults.firstIndex(of: toolsBin)!, defaults.firstIndex(of: "/opt/homebrew/bin")!)
    }

    func testBuiltAppUsesThePackagedEngineAndKeepsNoticeFolders() throws {
        let resources = try XCTUnwrap(Bundle.main.resourceURL)
        let engine = BundledLayout.engineDirectory(resources: resources)
        for relative in EngineLocator.packagedRequirements {
            XCTAssertTrue(FileManager.default.fileExists(atPath: engine.appendingPathComponent(relative).path), relative)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: engine.appendingPathComponent(".git").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: engine.appendingPathComponent("dm/ios/Gen").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: engine.appendingPathComponent("SNative Studio").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: BundledLayout.toolsDirectory(resources: resources).path))
        XCTAssertEqual(
            EngineLocator.resolve(packagedDirectory: engine, externalCandidates: []),
            .packaged(engine.standardizedFileURL)
        )
        let nestedLicense = BundledLayout.noticesDirectory(resources: resources)
            .appendingPathComponent("nxnative/third_party/libvpx/LICENSE")
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedLicense.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: resources.appendingPathComponent("LICENSE").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: resources.appendingPathComponent("COPYING").path))
        let packagedScript = try String(contentsOf: engine.appendingPathComponent(EngineLocator.scriptRelativePath), encoding: .utf8)
        XCTAssertTrue(packagedScript.contains("def snative_tool_paths(base):"))
        XCTAssertTrue(packagedScript.contains("SNATIVE_TOOL_PATH"))
        XCTAssertTrue(packagedScript.contains("os.environ.get('PATH', '/usr/bin:/bin:/usr/sbin:/sbin')"))
        XCTAssertFalse(packagedScript.contains("os.pathsep.join(TOOL_PATHS +"))
        let checkout = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("nxnative/scripts/build_ipa_from_nsp.py")
        if FileManager.default.isReadableFile(atPath: checkout.path) {
            let originalScript = try String(contentsOf: checkout, encoding: .utf8)
            XCTAssertFalse(originalScript.contains("def snative_tool_paths(base):"))
            XCTAssertNotEqual(packagedScript, originalScript)
        }

        let external = try makeEngine()
        defer { try? FileManager.default.removeItem(at: external) }
        let start = external.appendingPathComponent("nota.txt")
        try Data("nota".utf8).write(to: start)
        XCTAssertEqual(
            EngineLocator.locate(startingAt: [start], packagedDirectory: nil)?.path,
            external.standardizedFileURL.path
        )
    }

    func testSelectedToolDirectoriesArePlacedAheadOfPath() {
        let environment = BuildPlanner.pathPrependingToolDirectories(
            ["PATH": "/usr/bin:/bin"],
            tools: [
                "python3": "/Apps/SNative Studio.app/Contents/Resources/Tools/python/bin/python3",
                "dotnet": "/Apps/SNative Studio.app/Contents/Resources/Tools/dotnet/dotnet",
                "xcodebuild": "/usr/bin/xcodebuild"
            ]
        )
        XCTAssertEqual(
            environment["PATH"],
            "/Apps/SNative Studio.app/Contents/Resources/Tools/python/bin:/Apps/SNative Studio.app/Contents/Resources/Tools/dotnet:/usr/bin:/bin"
        )
    }

    func testDistributableScriptPatchLeavesTheOriginalUntouched() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("original/scripts/build_ipa_from_nsp.py")
        let copy = root.appendingPathComponent("copy/scripts/build_ipa_from_nsp.py")
        try writeFile(original, contents: scriptFixture())
        try writeFile(copy, contents: scriptFixture())
        let originalBytes = try Data(contentsOf: original)
        try runPatcher(on: copy)
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
        let patched = try String(contentsOf: copy, encoding: .utf8)
        XCTAssertTrue(patched.contains("def snative_tool_paths(base):"))
        XCTAssertTrue(patched.contains("SNATIVE_TOOL_PATH"))
        XCTAssertTrue(patched.contains("os.environ.get('PATH', '/usr/bin:/bin:/usr/sbin:/sbin')"))
        XCTAssertFalse(patched.contains("os.pathsep.join(TOOL_PATHS +"))
        try runPatcher(on: copy)
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), patched)

        let broken = root.appendingPathComponent("broken/scripts/build_ipa_from_nsp.py")
        try writeFile(broken, contents: "#!/usr/bin/env python3\nimport subprocess\nprint('no')\n")
        let brokenBytes = try Data(contentsOf: broken)
        XCTAssertThrowsError(try runPatcher(on: broken))
        XCTAssertEqual(try Data(contentsOf: broken), brokenBytes)

        try FileManager.default.createDirectory(at: root.appendingPathComponent("checkout/.git"), withIntermediateDirectories: true)
        let protected = root.appendingPathComponent("checkout/scripts/build_ipa_from_nsp.py")
        try writeFile(protected, contents: scriptFixture())
        let protectedBytes = try Data(contentsOf: protected)
        XCTAssertThrowsError(try runPatcher(on: protected))
        XCTAssertEqual(try Data(contentsOf: protected), protectedBytes)

        let checkout = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("nxnative/scripts/build_ipa_from_nsp.py")
        if FileManager.default.isReadableFile(atPath: checkout.path) {
            let before = try Data(contentsOf: checkout)
            XCTAssertThrowsError(try runPatcher(on: checkout))
            XCTAssertEqual(try Data(contentsOf: checkout), before)
        }
    }

    func testAnIncompatibleDotNetDoesNotHideALaterSDK10() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bad = root.appendingPathComponent("bad")
        let extra = root.appendingPathComponent("zstdbin")
        let good = root.appendingPathComponent("sdk10")
        let stamp = root.appendingPathComponent("stamp")
        try writeExecutable(bad.appendingPathComponent("dotnet"), contents: "#!/bin/sh\necho 8.0.100\n")
        try writeExecutable(extra.appendingPathComponent("zstd"))
        try writeExecutable(good.appendingPathComponent("dotnet"), contents: "#!/bin/sh\necho 10.0.402\n")
        let copy = root.appendingPathComponent("engine/scripts/build_ipa_from_nsp.py")
        try writeFile(copy, contents: scriptFixture())
        try runPatcher(on: copy)

        let reordered = try pythonOutput(script: copy, toolPath: "\(bad.path):\(extra.path)", sdk: good.path, stamp: stamp)
        XCTAssertEqual(reordered, "\(extra.path):/no/homebrew:/no/local:\(good.path):\(bad.path)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: stamp.path))

        try writeExecutable(good.appendingPathComponent("dotnet"), contents: "#!/bin/sh\ntouch '\(stamp.path)'\necho 10.0.402\n")
        let untouched = try pythonOutput(script: copy, toolPath: "", sdk: good.path, stamp: stamp)
        XCTAssertEqual(untouched, "/no/homebrew:/no/local:\(good.path)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: stamp.path))
    }

    func testPackagedEngineAnnouncesBundledToolsAndKeepsSystemPaths() throws {
        let resources = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: resources) }
        let engine = BundledLayout.engineDirectory(resources: resources)
        let python = BundledLayout.toolsDirectory(resources: resources).appendingPathComponent("python/bin/python3")
        try writeExecutable(python)
        let draft = readyDraft()
        var tools = Dictionary(uniqueKeysWithValues: BuildPlanner.requiredTools.map { ($0, "/usr/bin/\($0)") })
        tools["python3"] = python.path
        tools["dotnet"] = "/Users/test/.dotnet/dotnet"
        let environment = ["PATH": "/usr/bin:/bin", "HOME": "/Users/test"]
        let facts = readyFacts(draft: draft, engine: engine.path, tools: tools, environment: environment, packaged: true)
        let result = BuildPlanner.decide(draft: draft, facts: facts, allowOverwrite: false)
        guard case .ready(let command, _) = result else {
            return XCTFail("Se esperaba un plan listo, llegó \(result)")
        }
        XCTAssertEqual(environment["PATH"], "/usr/bin:/bin")
        XCTAssertEqual(environment["HOME"], "/Users/test")
        XCTAssertEqual(command.environment["HOME"], "/Users/test")
        XCTAssertEqual(command.environment["SNATIVE_TOOL_PATH"], python.deletingLastPathComponent().path)
        XCTAssertFalse(command.environment["SNATIVE_TOOL_PATH"]?.contains(".dotnet") ?? true)
        let path = try XCTUnwrap(command.environment["PATH"])
        XCTAssertTrue(path.contains(python.deletingLastPathComponent().path))
        XCTAssertTrue(path.contains("/usr/bin"))
        XCTAssertTrue(path.contains("/Users/test/.dotnet"))

        var external = facts
        external.prefersPackagedTools = false
        let externalResult = BuildPlanner.decide(draft: draft, facts: external, allowOverwrite: false)
        guard case .ready(let externalCommand, _) = externalResult else {
            return XCTFail("Se esperaba un plan listo, llegó \(externalResult)")
        }
        XCTAssertNil(externalCommand.environment["SNATIVE_TOOL_PATH"])
        XCTAssertTrue(externalCommand.environment["PATH"]?.contains("/usr/bin") ?? false)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("snative-bundle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeEngine() throws -> URL {
        let root = try makeTemporaryDirectory()
        try writeFile(root.appendingPathComponent(EngineLocator.scriptRelativePath), contents: "script")
        try writeFile(root.appendingPathComponent(EngineLocator.extractorRelativePath), contents: "program")
        try writeFile(root.appendingPathComponent(EngineLocator.translatorRelativePath), contents: "translator")
        return root
    }

    private func writeFile(_ url: URL, contents: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    private func writeExecutable(_ url: URL, contents: String = "#!/bin/sh\nexit 0\n") throws {
        try writeFile(url, contents: contents)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func scriptFixture() -> String {
        """
        #!/usr/bin/env python3
        import os, subprocess
        TOOL_PATHS = ['/opt/homebrew/bin', '/usr/local/bin', '/usr/local/share/dotnet', os.path.expanduser('~/.dotnet')]   # GUI apps such as Spyder do not get the shell's PATH

        def main():
            env = dict(os.environ, PATH=os.pathsep.join(TOOL_PATHS + [os.environ.get('PATH', '/usr/bin:/bin:/usr/sbin:/sbin')]))
        """
    }

    private func runPatcher(on script: URL) throws {
        let patcher = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scripts/prepare_distributable_script.py")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [patcher.path, script.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw PatchFailure(status: process.terminationStatus, output: output)
        }
    }

    private func pythonOutput(script: URL, toolPath: String, sdk: String, stamp: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            "-c",
            """
            import importlib.util, os, sys
            os.environ['SNATIVE_TOOL_PATH'] = sys.argv[1]
            os.environ['PATH'] = '/usr/bin:/bin'
            spec = importlib.util.spec_from_file_location('patched', sys.argv[2])
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            result = module.snative_tool_paths(['/no/homebrew', '/no/local', sys.argv[3]])
            if os.environ['PATH'] != '/usr/bin:/bin':
                raise SystemExit('PATH changed')
            print(os.pathsep.join(result))
            """,
            toolPath,
            script.path,
            sdk,
            stamp.path
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw PatchFailure(status: process.terminationStatus)
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func readyDraft() -> ProjectDraft {
        let base = "/juegos/mario/Game [010015100B514000][v0].nsp"
        return ProjectDraft(
            id: UUID(),
            name: "Prueba",
            createdAt: Date(),
            updatedAt: Date(),
            baseNSP: base,
            updateNSP: "/juegos/mario/Game [010015100B514800][v327680].nsp",
            prodKeys: "/claves/prod.keys",
            outputDirectory: "/tmp/salida",
            isTracked: true
        )
    }

    private func readyFacts(draft: ProjectDraft, engine: String, tools: [String: String], environment: [String: String], packaged: Bool) -> BuildFacts {
        let paths = [draft.baseNSP, draft.updateNSP, draft.prodKeys]
        var files: [String: FileInspection] = [:]
        for path in paths {
            files[path] = FileInspection(exists: true, isDirectory: false, isReadable: true, isWritable: true, byteCount: 32)
        }
        files[draft.outputDirectory] = FileInspection(exists: true, isDirectory: true, isReadable: true, isWritable: true, byteCount: 0)
        return BuildFacts(
            engineRoot: engine,
            scriptExists: true,
            translatorExists: true,
            tools: tools,
            missingPythonModules: [],
            environment: environment,
            files: files,
            siblingNSPNames: paths.map { URL(fileURLWithPath: $0).lastPathComponent },
            profileIPANames: ["010015100B514000": "SMBWMobile.ipa"],
            prefersPackagedTools: packaged
        )
    }
}

private struct PatchFailure: Error, CustomStringConvertible {
    var status: Int32
    var output: String = ""
    var description: String { "status \(status): \(output)" }
}
