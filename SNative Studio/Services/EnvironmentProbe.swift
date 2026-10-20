import Foundation

protocol ExecutableLocating: Sendable {
    func path(for executable: String) -> String?
}

struct FileSystemLocator: ExecutableLocating {
    var directories: [String]

    init(directories: [String]? = nil, resources: URL? = Bundle.main.resourceURL) {
        self.directories = directories ?? Self.defaultDirectories(resources: resources)
    }

    /// Packaged tools come first, then the usual macOS locations, then any other directory already on PATH.
    static func defaultDirectories(resources: URL?, path: String? = ProcessInfo.processInfo.environment["PATH"]) -> [String] {
        var directories: [String] = []
        if let resources {
            let tools = BundledLayout.toolsDirectory(resources: resources)
            directories.append(tools.appendingPathComponent("bin").path)
            directories.append(tools.appendingPathComponent("python/bin").path)
            directories.append(tools.appendingPathComponent("dotnet").path)
            directories.append(tools.path)
        }
        directories.append(contentsOf: externalDirectories)
        for extra in (path ?? "").split(separator: ":").map(String.init) where !extra.isEmpty && !directories.contains(extra) {
            directories.append(extra)
        }
        return directories
    }

    static let externalDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        NSHomeDirectory() + "/.dotnet",
        "/usr/local/share/dotnet"
    ]

    func path(for executable: String) -> String? {
        let found = candidates(for: executable)
        if executable == "dotnet" {
            return Self.preferredDotNet(found)
        }
        return found.first
    }

    func candidates(for executable: String) -> [String] {
        var found: [String] = []
        var seen = Set<String>()
        let fileManager = FileManager.default
        for directory in directories {
            let candidate = (directory as NSString).appendingPathComponent(executable)
            let key = URL(fileURLWithPath: candidate).standardizedFileURL.path
            guard seen.insert(key).inserted else { continue }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: candidate, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
            guard fileManager.isExecutableFile(atPath: candidate) else { continue }
            found.append(candidate)
        }
        return found
    }

    /// A .NET SDK 10 wins over an earlier SDK, including when the earlier one is found first.
    static func preferredDotNet(_ candidates: [String]) -> String? {
        var fallback: String?
        for candidate in candidates {
            let version = CommandOutput.firstLine(executable: candidate, arguments: ["--version"])
            if let version, DependencyGuide.isDotNetSDK10(version) {
                return candidate
            }
            if fallback == nil { fallback = candidate }
        }
        return fallback
    }
}

struct DependencyMeasurement: Sendable, Equatable {
    var versions: [String: String] = [:]
    var missingPythonModules: [String]? = nil
    var engine: EngineLocation = .absent
    var iosSDKPath: String? = nil
    var metalPath: String? = nil
    var libHacPath: String? = nil
}

enum ProbeSource: Sendable {
    case supplied(DependencyMeasurement)
    case live
}

struct EnvironmentProbe: Sendable {
    var locator: any ExecutableLocating
    var bundledPrefixes: [String]
    var source: ProbeSource

    static let live = EnvironmentProbe(
        locator: FileSystemLocator(),
        bundledPrefixes: liveBundledPrefixes,
        source: .live
    )

    init(locator: any ExecutableLocating, bundledPrefixes: [String] = [], source: ProbeSource = .supplied(DependencyMeasurement())) {
        self.locator = locator
        self.bundledPrefixes = bundledPrefixes
        self.source = source
    }

    var checksExternally: Bool {
        if case .live = source { return true }
        return false
    }

    func inspect() -> [ToolDependency] {
        let measurement = resolvedMeasurement()
        let brewDetected = acceptedExecutable(locator.path(for: "brew")) != nil
        let pythonPath = acceptedExecutable(locator.path(for: "python3"))
        return DependencyCatalog.specs.map { spec in
            item(spec, measurement: measurement, brewDetected: brewDetected, pythonPath: pythonPath)
        }
    }

    private func resolvedMeasurement() -> DependencyMeasurement {
        switch source {
        case .supplied(let measurement):
            return measurement
        case .live:
            return Self.measureLive(locator: locator)
        }
    }

    private func item(_ spec: DependencySpec, measurement: DependencyMeasurement, brewDetected: Bool, pythonPath: String?) -> ToolDependency {
        switch spec.id {
        case "engine":
            return engineItem(spec, location: measurement.engine)
        case "python-modules":
            return modulesItem(spec, pythonPath: pythonPath, missing: measurement.missingPythonModules)
        case "ios-sdk":
            return developerItem(spec, path: measurement.iosSDKPath, directory: true, brewDetected: brewDetected, pythonDetected: pythonPath != nil)
        case "metal":
            return developerItem(spec, path: measurement.metalPath, directory: false, brewDetected: brewDetected, pythonDetected: pythonPath != nil)
        case "libhac":
            return fileItem(spec, path: measurement.libHacPath, brewDetected: brewDetected, pythonDetected: pythonPath != nil)
        default:
            return executableItem(spec, measurement: measurement, brewDetected: brewDetected, pythonDetected: pythonPath != nil)
        }
    }

    private func executableItem(_ spec: DependencySpec, measurement: DependencyMeasurement, brewDetected: Bool, pythonDetected: Bool) -> ToolDependency {
        let path = acceptedExecutable(locator.path(for: spec.executable))
        let version = path == nil ? nil : measurement.versions[spec.executable]
        if let path {
            if spec.id == "dotnet", let version, !DependencyGuide.isDotNetSDK10(version) {
                return make(
                    spec,
                    state: .incompatible(path: path, version: version, expected: DependencyGuide.dotNetRequirement),
                    version: version,
                    note: "Se encontró \(version). El script exige \(DependencyGuide.dotNetRequirement).",
                    actions: DependencyGuide.actions(id: spec.id, brewDetected: brewDetected, pythonDetected: pythonDetected)
                )
            }
            let state: ToolDependency.State = isBundled(path) ? .included(path: path) : .available(path: path)
            return make(spec, state: state, version: version, actions: [])
        }
        return make(
            spec,
            state: .missing,
            actions: DependencyGuide.actions(id: spec.id, brewDetected: brewDetected, pythonDetected: pythonDetected)
        )
    }

    private func engineItem(_ spec: DependencySpec, location: EngineLocation) -> ToolDependency {
        let state: ToolDependency.State
        switch location {
        case .packaged(let url):
            state = .included(path: url.path)
        case .external(let url):
            state = .available(path: url.path)
        case .incomplete(let url, let missing):
            state = .incomplete(path: url.path, missing: missing)
        case .absent:
            state = .missing
        }
        return make(spec, state: state, note: DependencyGuide.engineNote(location), actions: DependencyGuide.engineActions(location))
    }

    private func modulesItem(_ spec: DependencySpec, pythonPath: String?, missing: [String]?) -> ToolDependency {
        guard let pythonPath else {
            return make(spec, state: .missing, actions: DependencyGuide.actions(id: spec.id, brewDetected: false, pythonDetected: false))
        }
        guard let missing else {
            return make(
                spec,
                state: .missing,
                locationNote: "No se ha comprobado la importación.",
                actions: [DependencyAction(id: "manual", kind: .manual("No se ha comprobado la importación de lz4, capstone y fontTools."))]
            )
        }
        if missing.isEmpty {
            return make(spec, state: .available(path: pythonPath), note: "lz4, capstone y fontTools se importan con este Python.", actions: [])
        }
        return make(
            spec,
            state: .missing,
            locationNote: "Faltan: \(missing.joined(separator: ", ")).",
            actions: DependencyGuide.actions(id: spec.id, brewDetected: false, pythonDetected: true)
        )
    }

    private func fileItem(_ spec: DependencySpec, path: String?, brewDetected: Bool, pythonDetected: Bool) -> ToolDependency {
        if let path, Self.isReadableFile(path) {
            let state: ToolDependency.State = isBundled(path) ? .included(path: path) : .available(path: path)
            return make(spec, state: state, actions: [])
        }
        return make(spec, state: .missing, actions: DependencyGuide.actions(id: spec.id, brewDetected: brewDetected, pythonDetected: pythonDetected))
    }

    private static func isReadableFile(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
        return FileManager.default.isReadableFile(atPath: path)
    }

    private func developerItem(_ spec: DependencySpec, path: String?, directory: Bool, brewDetected: Bool, pythonDetected: Bool) -> ToolDependency {
        if let path, acceptedDeveloperPath(path, directory: directory) {
            return make(spec, state: .available(path: path), actions: [])
        }
        return make(spec, state: .missing, actions: DependencyGuide.actions(id: spec.id, brewDetected: brewDetected, pythonDetected: pythonDetected))
    }

    private func make(
        _ spec: DependencySpec,
        state: ToolDependency.State,
        version: String? = nil,
        note: String? = nil,
        locationNote: String? = nil,
        actions: [DependencyAction]
    ) -> ToolDependency {
        ToolDependency(
            id: spec.id,
            name: spec.name,
            purpose: spec.purpose,
            executable: spec.executable,
            requirement: spec.requirement,
            state: state,
            version: version,
            note: note,
            locationNote: locationNote,
            actions: actions
        )
    }

    private func isBundled(_ path: String) -> Bool {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        return bundledPrefixes.contains { prefix in
            let base = URL(fileURLWithPath: prefix).standardizedFileURL.path
            guard !base.isEmpty, base != "/" else { return false }
            return standardized == base || standardized.hasPrefix(base + "/")
        }
    }

    static func acceptedExecutable(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        return path
    }

    private func acceptedExecutable(_ path: String?) -> String? {
        Self.acceptedExecutable(path)
    }

    private func acceptedDeveloperPath(_ path: String, directory: Bool) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return false }
        if directory { return isDirectory.boolValue }
        return !isDirectory.boolValue && FileManager.default.isExecutableFile(atPath: path)
    }

    private static var liveBundledPrefixes: [String] {
        guard let resources = Bundle.main.resourceURL else { return [] }
        return [
            BundledLayout.toolsDirectory(resources: resources).standardizedFileURL.path,
            BundledLayout.engineDirectory(resources: resources).standardizedFileURL.path
        ]
    }

    private static func measureLive(locator: any ExecutableLocating) -> DependencyMeasurement {
        var versions: [String: String] = [:]
        for spec in DependencyCatalog.specs where !spec.executable.isEmpty {
            guard let path = acceptedExecutable(locator.path(for: spec.executable)) else { continue }
            if let version = version(of: spec.executable, at: path) {
                versions[spec.executable] = version
            }
        }
        let modules: [String]?
        if let python = acceptedExecutable(locator.path(for: "python3")) {
            modules = PythonModules.missing(python: python)
        } else {
            modules = nil
        }
        let engine = EngineLocator.resolve(
            packagedDirectory: EngineLocator.bundledEngineDirectory(),
            externalCandidates: EngineLocator.defaultCandidates()
        )
        let developer = appleDeveloperTools(locator: locator)
        let engineRoot: URL?
        switch engine {
        case .packaged(let url), .external(let url):
            engineRoot = url
        case .incomplete, .absent:
            engineRoot = nil
        }
        return DependencyMeasurement(
            versions: versions,
            missingPythonModules: modules,
            engine: engine,
            iosSDKPath: developer.sdk,
            metalPath: developer.metal,
            libHacPath: libHacPackage(engineRoot: engineRoot)
        )
    }

    private static func version(of executable: String, at path: String) -> String? {
        if executable == "spirv-cross" {
            return cellarVersion(executable: executable, path: path)
        }
        let arguments: [String]
        switch executable {
        case "xcodebuild":
            arguments = ["-version"]
        case "zip":
            return nil
        default:
            arguments = ["--version"]
        }
        return CommandOutput.firstLine(executable: path, arguments: arguments)
    }

    private static func cellarVersion(executable: String, path: String) -> String? {
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        let marker = "/Cellar/\(executable)/"
        guard let range = resolved.range(of: marker) else { return nil }
        let version = resolved[range.upperBound...].prefix { $0 != "/" }
        return version.isEmpty ? nil : String(version)
    }

    /// Looks for the nupkg. Does not restore, download, or contact NuGet.
    static func libHacPackage(engineRoot: URL?) -> String? {
        if let engineRoot {
            let local = engineRoot.appendingPathComponent("local-nuget/libhac.0.19.0.nupkg").path
            if FileManager.default.isReadableFile(atPath: local) { return local }
        }
        let cached = NSHomeDirectory() + "/.nuget/packages/libhac/0.19.0/libhac.0.19.0.nupkg"
        if FileManager.default.isReadableFile(atPath: cached) { return cached }
        return nil
    }

    private static func appleDeveloperTools(locator: any ExecutableLocating) -> (sdk: String?, metal: String?) {
        guard let xcrun = acceptedExecutable(locator.path(for: "xcrun")) else { return (nil, nil) }
        let sdk = CommandOutput.firstLine(executable: xcrun, arguments: ["--sdk", "iphoneos", "--show-sdk-path"])
        let metal = CommandOutput.firstLine(executable: xcrun, arguments: ["--find", "metal"])
        return (sdk, metal)
    }
}

enum CommandOutput {
    static func firstLine(executable: String, arguments: [String], timeout: TimeInterval = 8) -> String? {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        let finished = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            return nil
        }
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return nil
        }
        let out = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else { return nil }
        return (out + "\n" + err)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }
}
