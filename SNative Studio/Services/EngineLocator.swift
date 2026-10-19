import Foundation

enum EngineLocator {
    static func defaultCandidates() -> [URL] {
        var urls = [URL(fileURLWithPath: #filePath)]
        urls.append(Bundle.main.bundleURL)
        if let executable = Bundle.main.executableURL {
            urls.append(executable)
        }
        urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        if let argument = CommandLine.arguments.first {
            urls.append(URL(fileURLWithPath: argument))
        }
        return urls
    }

    static func locate(startingAt candidates: [URL], fileManager: FileManager = .default) -> URL? {
        var seen = Set<String>()
        for start in candidates {
            var current = start.standardizedFileURL
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: current.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                current.deleteLastPathComponent()
            }
            for _ in 0..<16 {
                let path = current.path
                if !seen.insert(path).inserted { break }
                if isRepository(current, fileManager: fileManager) {
                    return current
                }
                let parent = current.deletingLastPathComponent()
                if parent.path == current.path { break }
                current = parent
            }
        }
        return nil
    }

    static func isRepository(_ url: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: url.appendingPathComponent("scripts/build_ipa_from_nsp.py").path)
            && fileManager.fileExists(atPath: url.appendingPathComponent("dm/tools/nx_extract/Program.cs").path)
    }
}
