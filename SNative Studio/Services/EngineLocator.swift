import Foundation

enum BundledLayout {
    static let engineDirectoryName = "Engine"
    static let toolsDirectoryName = "Tools"
    static let noticesDirectoryName = "Notices"

    static func engineDirectory(resources: URL) -> URL {
        resources.appendingPathComponent(engineDirectoryName, isDirectory: true)
    }

    static func toolsDirectory(resources: URL) -> URL {
        resources.appendingPathComponent(toolsDirectoryName, isDirectory: true)
    }

    static func noticesDirectory(resources: URL) -> URL {
        resources.appendingPathComponent(noticesDirectoryName, isDirectory: true)
    }
}

enum EngineLocation: Equatable, Sendable {
    case packaged(URL)
    case external(URL)
    case incomplete(URL, missing: [String])
    case absent
}

enum EngineLocator {
    static let scriptRelativePath = "scripts/build_ipa_from_nsp.py"
    static let extractorRelativePath = "dm/tools/nx_extract/Program.cs"
    static let translatorRelativePath = "dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate"
    static let packagedRequirements = [scriptRelativePath, extractorRelativePath, translatorRelativePath]

    static func bundledEngineDirectory(bundle: Bundle = .main) -> URL? {
        bundle.resourceURL.map(BundledLayout.engineDirectory(resources:))
    }

    static func bundledToolsDirectory(bundle: Bundle = .main) -> URL? {
        bundle.resourceURL.map(BundledLayout.toolsDirectory(resources:))
    }

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

    /// A complete packaged engine wins. A packaged directory that exists but is incomplete does not fall back to an external checkout.
    static func resolve(packagedDirectory: URL?, externalCandidates: [URL], fileManager: FileManager = .default) -> EngineLocation {
        if let packagedDirectory, fileManager.fileExists(atPath: packagedDirectory.path) {
            let missing = missingRequirements(in: packagedDirectory, fileManager: fileManager)
            if missing.isEmpty {
                return .packaged(packagedDirectory.standardizedFileURL)
            }
            return .incomplete(packagedDirectory.standardizedFileURL, missing: missing)
        }
        if let external = walk(externalCandidates, fileManager: fileManager) {
            return .external(external)
        }
        return .absent
    }

    static func locate(startingAt candidates: [URL], packagedDirectory: URL? = bundledEngineDirectory(), fileManager: FileManager = .default) -> URL? {
        switch resolve(packagedDirectory: packagedDirectory, externalCandidates: candidates, fileManager: fileManager) {
        case .packaged(let url), .external(let url):
            return url
        case .incomplete, .absent:
            return nil
        }
    }

    static func isRepository(_ url: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: url.appendingPathComponent(scriptRelativePath).path)
            && fileManager.fileExists(atPath: url.appendingPathComponent(extractorRelativePath).path)
    }

    static func missingRequirements(in root: URL, fileManager: FileManager = .default) -> [String] {
        packagedRequirements.filter { relative in
            !fileManager.fileExists(atPath: root.appendingPathComponent(relative).path)
        }
    }

    static func incompleteMessage(directory: URL, missing: [String]) -> String {
        let names = missing.joined(separator: ", ")
        return "El motor empaquetado en Contents/Resources/Engine está incompleto (\(directory.path)). Falta: \(names). SNative Studio no descarga ni instala nxnative."
    }

    static let absentMessage = "No se encuentra el motor nxnative. SNative Studio lo busca primero dentro de la aplicación, en Contents/Resources/Engine, y después en un checkout local con scripts/build_ipa_from_nsp.py, dm/tools/nx_extract/Program.cs y dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate. No lo descarga ni lo instala."

    private static func walk(_ candidates: [URL], fileManager: FileManager) -> URL? {
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
}
