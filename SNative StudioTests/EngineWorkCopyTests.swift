import XCTest
@testable import SNativeStudio

final class EngineWorkCopyTests: XCTestCase {
    func testBundledEngineIsCopiedOutsideTheAppAndTheOriginalStaysUntouched() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = root.appendingPathComponent("SNative Studio.app/Contents/Resources/Engine")
        let support = root.appendingPathComponent("support")
        try makeEngine(at: engine)
        let planted = engine.appendingPathComponent("dm/tools/nx_extract/obj/Release/net10.0/nx_extract.AssemblyInfo.cs")
        try FileManager.default.createDirectory(at: planted.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("// generated\n".utf8).write(to: planted)
        let script = engine.appendingPathComponent("scripts/build_ipa_from_nsp.py")
        let original = try Data(contentsOf: script)
        let projectID = UUID()

        let layout = try EngineWorkCopy.prepare(engineRoot: engine, projectID: projectID, supportDirectory: support)
        XCTAssertFalse(layout.engine.path.contains(".app/"))
        XCTAssertTrue(layout.engine.path.hasPrefix(support.path))
        XCTAssertTrue(FileManager.default.isWritableFile(atPath: layout.engine.path))
        XCTAssertTrue(FileManager.default.isWritableFile(atPath: layout.intermediateOutput.path))
        XCTAssertTrue(FileManager.default.isWritableFile(atPath: layout.nugetPackages.path))
        XCTAssertEqual(try Data(contentsOf: script), original)
        let props = layout.engine.appendingPathComponent(EngineWorkCopy.buildPropsRelativePath)
        let propsText = try String(contentsOf: props, encoding: .utf8)
        XCTAssertTrue(propsText.contains("obj/**"))
        XCTAssertTrue(propsText.contains("bin/**"))
        XCTAssertFalse(propsText.contains("GenerateAssemblyInfo"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: engine.appendingPathComponent(EngineWorkCopy.buildPropsRelativePath).path))
        XCTAssertFalse(layout.intermediateOutput.path.hasPrefix(layout.engine.path + "/"))
        XCTAssertFalse(layout.buildOutput.path.hasPrefix(layout.engine.path + "/"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: planted.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: layout.engine.appendingPathComponent("dm/tools/nx_extract/obj").path))
        let probe = layout.engine.appendingPathComponent("dm/tools/nx_extract/obj/probe.txt")
        let keeper = layout.engine.appendingPathComponent("dm/tools/nx_extract/Program.cs")
        try FileManager.default.createDirectory(at: probe.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("obj".utf8).write(to: probe)
        try Data("program".utf8).write(to: keeper)

        let again = try EngineWorkCopy.prepare(engineRoot: engine, projectID: projectID, supportDirectory: support)
        XCTAssertEqual(again.engine.path, layout.engine.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: probe.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: keeper.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: planted.path))
    }

    func testExternalCheckoutIsNotCopied() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = root.appendingPathComponent("nxnative")
        try makeEngine(at: engine)
        let layout = try EngineWorkCopy.prepare(engineRoot: engine, projectID: UUID(), supportDirectory: root.appendingPathComponent("support"))
        XCTAssertEqual(layout.engine.standardizedFileURL.path, engine.standardizedFileURL.path)
        XCTAssertFalse(EngineWorkCopy.needsWritableCopy(engine.path))
    }

    func testAPlannedBuildDoesNotTargetTheAppBundle() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = root.appendingPathComponent("SNative Studio.app/Contents/Resources/Engine")
        let support = root.appendingPathComponent("support")
        let games = root.appendingPathComponent("juegos")
        let output = root.appendingPathComponent("salida")
        try makeEngine(at: engine)
        try FileManager.default.createDirectory(at: games, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try Data("nsp".utf8).write(to: games.appendingPathComponent("Game [010015100B514000][v0].nsp"))
        try Data("keys".utf8).write(to: games.appendingPathComponent("prod.keys"))

        var draft = ProjectDraft.blank()
        draft.baseNSP = games.appendingPathComponent("Game [010015100B514000][v0].nsp").path
        draft.prodKeys = games.appendingPathComponent("prod.keys").path
        draft.outputDirectory = output.path
        draft.ipaName = "Prueba.ipa"
        let capturedEnvironment = ["PATH": "/usr/bin:/bin", "HOME": "/Users/test"]
        let planner = LiveBuildPlanner(
            candidates: [],
            packagedEngineDirectory: engine,
            locator: MapLocator(paths: Dictionary(uniqueKeysWithValues: BuildPlanner.requiredTools.map { ($0, "/bin/echo") })),
            missingPythonModules: [],
            environment: capturedEnvironment,
            workSupportDirectory: support
        )
        let result = planner.plan(draft: draft, allowOverwrite: true)
        guard case .ready(let command, _) = result else {
            return XCTFail("Se esperaba un plan listo, llegó \(result)")
        }
        XCTAssertEqual(capturedEnvironment["PATH"], "/usr/bin:/bin")
        XCTAssertFalse(command.workingDirectory.contains(".app/"))
        XCTAssertTrue(FileManager.default.isWritableFile(atPath: command.workingDirectory))
        XCTAssertFalse(command.arguments[0].contains(".app/"))
        XCTAssertEqual(command.arguments[2], "-k")
        XCTAssertEqual(command.arguments[3], draft.prodKeys)
        XCTAssertFalse(command.environment["NUGET_PACKAGES"]?.contains(".app/") ?? true)
        XCTAssertFalse(command.environment["TMPDIR"]?.contains(".app/") ?? true)
        XCTAssertFalse(command.environment["BaseIntermediateOutputPath"]?.contains(".app/") ?? true)
        XCTAssertFalse(command.environment["BaseOutputPath"]?.contains(".app/") ?? true)
        XCTAssertTrue(command.environment["BaseIntermediateOutputPath"]?.hasSuffix("/") ?? false)
        XCTAssertTrue(FileManager.default.isWritableFile(atPath: command.environment["NUGET_PACKAGES"] ?? ""))
        let obj = URL(fileURLWithPath: String(command.environment["BaseIntermediateOutputPath"]!.dropLast()))
        try Data("obj".utf8).write(to: obj.appendingPathComponent("probe.txt"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: engine.appendingPathComponent("dm/tools/nx_extract/obj").path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("snative-work-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeEngine(at root: URL) throws {
        for relative in [
            EngineLocator.scriptRelativePath,
            EngineLocator.extractorRelativePath,
            EngineLocator.translatorRelativePath
        ] {
            let url = root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("contenido".utf8).write(to: url)
        }
    }
}

private struct MapLocator: ExecutableLocating {
    var paths: [String: String]
    func path(for executable: String) -> String? { paths[executable] }
}
