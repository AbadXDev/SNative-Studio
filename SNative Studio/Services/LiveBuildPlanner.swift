import Foundation

enum PythonModules {
    static let imports = [("lz4.block", "lz4"), ("capstone", "capstone"), ("fontTools", "fonttools")]

    static func missing(python: String) -> [String] {
        imports.compactMap { module, label in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = ["-c", "import \(module)"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                return label
            }
            process.waitUntilExit()
            return process.terminationStatus == 0 ? nil : label
        }
    }
}

struct LiveBuildPlanner: BuildPlanning {
    var candidates: [URL]
    var packagedEngineDirectory: URL?
    var locator: any ExecutableLocating
    var missingPythonModules: [String]?
    var environment: [String: String]
    var workSupportDirectory: URL

    init(
        candidates: [URL]? = nil,
        packagedEngineDirectory: URL? = nil,
        locator: any ExecutableLocating = FileSystemLocator(),
        missingPythonModules: [String]? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        workSupportDirectory: URL? = nil
    ) {
        self.candidates = candidates ?? EngineLocator.defaultCandidates()
        self.packagedEngineDirectory = packagedEngineDirectory ?? EngineLocator.bundledEngineDirectory()
        self.locator = locator
        self.missingPythonModules = missingPythonModules
        self.environment = environment
        self.workSupportDirectory = workSupportDirectory ?? EngineWorkCopy.defaultSupportDirectory()
    }

    func plan(draft: ProjectDraft, allowOverwrite: Bool) -> BuildPlanResult {
        let location = EngineLocator.resolve(packagedDirectory: packagedEngineDirectory, externalCandidates: candidates)
        let root: URL?
        let prefersPackagedTools: Bool
        switch location {
        case .incomplete(let directory, let missing):
            return .blocked(EngineLocator.incompleteMessage(directory: directory, missing: missing))
        case .absent:
            root = nil
            prefersPackagedTools = false
        case .packaged(let url):
            root = url
            prefersPackagedTools = true
        case .external(let url):
            root = url
            prefersPackagedTools = false
        }
        let modules = resolvedModules()
        var tools: [String: String] = [:]
        for name in BuildPlanner.requiredTools {
            if let path = locator.path(for: name) {
                tools[name] = path
            }
        }

        var files: [String: FileInspection] = [:]
        for path in [draft.baseNSP, draft.updateNSP, draft.prodKeys, draft.outputDirectory] where !path.isEmpty {
            if let inspection = inspect(path) {
                files[path] = inspection
            }
        }

        let siblings = siblingNames(basePath: draft.baseNSP)
        let profiles = profileNames(root: root, basePath: draft.baseNSP)
        if let output = BuildPlanner.outputIPAPath(draft: draft, profileIPANames: profiles),
           let inspection = inspect(output) {
            files[output] = inspection
        }

        let facts = BuildFacts(
            engineRoot: root?.path,
            scriptExists: root.map { EngineLocator.isRepository($0) } ?? false,
            translatorExists: root.map {
                FileManager.default.fileExists(atPath: $0.appendingPathComponent(EngineLocator.translatorRelativePath).path)
            } ?? false,
            tools: tools,
            missingPythonModules: modules,
            environment: environment,
            files: files,
            siblingNSPNames: siblings,
            profileIPANames: profiles,
            prefersPackagedTools: prefersPackagedTools
        )
        let planned = BuildPlanner.decide(draft: draft, facts: facts, allowOverwrite: allowOverwrite)
        guard let root, EngineWorkCopy.needsWritableCopy(root.path) else { return planned }
        switch planned {
        case .blocked:
            return planned
        case .ready, .needsOverwrite:
            do {
                let layout = try EngineWorkCopy.prepare(engineRoot: root, projectID: draft.id, supportDirectory: workSupportDirectory)
                return BuildPlanner.applyingWritableEngine(planned, from: root.path, to: layout.engine.path, layout: layout)
            } catch {
                return .blocked("No se puede preparar una copia escribible del motor. SNative Studio no escribe dentro de la aplicación.")
            }
        }
    }

    private func resolvedModules() -> [String] {
        if let missingPythonModules {
            return missingPythonModules
        }
        guard let python = locator.path(for: "python3") else {
            return PythonModules.imports.map(\.1)
        }
        return PythonModules.missing(python: python)
    }

    private func siblingNames(basePath: String) -> [String] {
        guard !basePath.isEmpty else { return [] }
        let directory = URL(fileURLWithPath: basePath).deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return names.map(\.lastPathComponent).filter { $0.lowercased().hasSuffix(".nsp") }
    }

    private func profileNames(root: URL?, basePath: String) -> [String: String] {
        guard let root, !basePath.isEmpty else { return [:] }
        let fileName = URL(fileURLWithPath: basePath).lastPathComponent
        guard let identifier = TitleIdentity.applicationID(in: fileName) else { return [:] }
        let profile = root.appendingPathComponent("dm/games/\(identifier)/game.tsv")
        guard let text = try? String(contentsOf: profile, encoding: .utf8),
              let ipa = ProfileIPA.fileName(in: text) else { return [:] }
        return [identifier: ipa]
    }

    private func inspect(_ path: String) -> FileInspection? {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return nil }
        let byteCount: Int64
        if let values = try? fileManager.attributesOfItem(atPath: path), let number = values[.size] as? NSNumber {
            byteCount = number.int64Value
        } else {
            byteCount = 0
        }
        return FileInspection(
            exists: true,
            isDirectory: isDirectory.boolValue,
            isReadable: fileManager.isReadableFile(atPath: path),
            isWritable: fileManager.isWritableFile(atPath: path),
            byteCount: byteCount
        )
    }
}
