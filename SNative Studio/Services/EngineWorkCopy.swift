import Foundation

struct EngineWorkLayout: Equatable, Sendable {
    var engine: URL
    var nugetPackages: URL
    var temporaryDirectory: URL
    var dotnetHome: URL
    var intermediateOutput: URL
    var buildOutput: URL
}

enum EngineWorkCopyError: Error {
    case supportInsideApplication
    case unreadableEngine
}

enum EngineWorkCopy {
    /// An engine shipped inside the app cannot receive `obj/`, `Gen/` or host object files.
    static func needsWritableCopy(_ engineRoot: String) -> Bool {
        engineRoot.contains(".app/Contents/")
    }

    static func defaultSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("SNative Studio", isDirectory: true)
    }

    /// Copies a bundled engine into Application Support. An external checkout is returned unchanged.
    static func prepare(engineRoot: URL, projectID: UUID, supportDirectory: URL, fileManager: FileManager = .default) throws -> EngineWorkLayout {
        if needsWritableCopy(supportDirectory.path) {
            throw EngineWorkCopyError.supportInsideApplication
        }
        let project = supportDirectory.appendingPathComponent("engine-work/\(projectID.uuidString)", isDirectory: true)
        let layout = EngineWorkLayout(
            engine: project.appendingPathComponent("source", isDirectory: true),
            nugetPackages: supportDirectory.appendingPathComponent("nuget", isDirectory: true),
            temporaryDirectory: project.appendingPathComponent("tmp", isDirectory: true),
            dotnetHome: supportDirectory.appendingPathComponent("dotnet-home", isDirectory: true),
            intermediateOutput: project.appendingPathComponent("msbuild/obj", isDirectory: true),
            buildOutput: project.appendingPathComponent("msbuild/bin", isDirectory: true)
        )
        guard !needsWritableCopy(engineRoot.path) else {
            try materializeEngine(from: engineRoot, to: layout.engine, fileManager: fileManager)
            try createWorkDirectories(layout, fileManager: fileManager)
            try installBuildProps(in: layout.engine, fileManager: fileManager)
            try removeGeneratedProjectOutputs(in: layout.engine, fileManager: fileManager)
            return layout
        }
        return EngineWorkLayout(
            engine: engineRoot.standardizedFileURL,
            nugetPackages: layout.nugetPackages,
            temporaryDirectory: layout.temporaryDirectory,
            dotnetHome: layout.dotnetHome,
            intermediateOutput: layout.intermediateOutput,
            buildOutput: layout.buildOutput
        )
    }

    private static func materializeEngine(from source: URL, to destination: URL, fileManager: FileManager) throws {
        let script = source.appendingPathComponent("scripts/build_ipa_from_nsp.py")
        guard fileManager.isReadableFile(atPath: script.path) else { throw EngineWorkCopyError.unreadableEngine }
        let token = stamp(source: source, script: script, fileManager: fileManager)
        let stampURL = destination.appendingPathComponent(".snative-engine-stamp")
        if fileManager.fileExists(atPath: destination.path),
           fileManager.isWritableFile(atPath: destination.path),
           (try? String(contentsOf: stampURL, encoding: .utf8)) == token {
            return
        }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: destination)
        try Data(token.utf8).write(to: stampURL)
    }

    /// Imported by MSBuild before the default `**/*.cs` glob. The redirected obj directory is absolute, so the SDK no longer excludes the project's own `obj/`.
    static let buildPropsRelativePath = "Directory.Build.props"

    static func buildPropsXML() -> String {
        """
        <Project>
          <PropertyGroup>
            <!-- SNative Studio: generated files stay outside the project tree and are not compiled twice. -->
            <DefaultItemExcludes>$(DefaultItemExcludes);obj/**;bin/**</DefaultItemExcludes>
          </PropertyGroup>
        </Project>
        """
    }

    private static func installBuildProps(in engine: URL, fileManager: FileManager) throws {
        let props = engine.appendingPathComponent(buildPropsRelativePath)
        try fileManager.createDirectory(at: props.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(buildPropsXML().utf8).write(to: props)
    }

    /// Removes only the generated folders MSBuild would otherwise compile from the project directory.
    private static func removeGeneratedProjectOutputs(in engine: URL, fileManager: FileManager) throws {
        for relative in ["dm/tools/nx_extract/obj", "dm/tools/nx_extract/bin"] {
            let url = engine.appendingPathComponent(relative)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            try fileManager.removeItem(at: url)
        }
    }

    private static func createWorkDirectories(_ layout: EngineWorkLayout, fileManager: FileManager) throws {
        for directory in [layout.nugetPackages, layout.temporaryDirectory, layout.dotnetHome, layout.intermediateOutput, layout.buildOutput] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private static func stamp(source: URL, script: URL, fileManager: FileManager) -> String {
        let values = try? fileManager.attributesOfItem(atPath: script.path)
        let size = (values?[.size] as? NSNumber)?.int64Value ?? 0
        let modified = (values?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(source.standardizedFileURL.path)\n\(size)\n\(modified)"
    }
}
