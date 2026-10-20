import XCTest
@testable import SNativeStudio

final class BuildEngineTests: XCTestCase {
    func testLocatorWalksUpAndDoesNotDependOnASingleDirectory() throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        let deep = root.appendingPathComponent("anidado/profundo/nota.txt")
        try FileManager.default.createDirectory(at: deep.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("nota".utf8).write(to: deep)
        let unrelated = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: unrelated) }

        XCTAssertEqual(EngineLocator.locate(startingAt: [unrelated, deep], packagedDirectory: nil)?.standardizedFileURL.path, root.standardizedFileURL.path)
        XCTAssertNil(EngineLocator.locate(startingAt: [unrelated], packagedDirectory: nil))
    }

    func testCommandUsesDocumentedArgumentsWithoutJoiningUserText() {
        let draft = sampleDraft(base: "/tmp/Mario's Wonder/Game [010015100B514000][v0].nsp")
        let result = BuildPlanner.decide(draft: draft, facts: sampleFacts(draft: draft), allowOverwrite: false)
        guard case .ready(let command, let summary) = result else {
            return XCTFail("Se esperaba un comando listo, llegó \(result)")
        }
        let folder = URL(fileURLWithPath: "/tmp/Mario's Wonder").resolvingSymlinksInPath().standardizedFileURL.path
        XCTAssertEqual(command.arguments, [
            "/repo/scripts/build_ipa_from_nsp.py",
            folder,
            "-k",
            draft.prodKeys,
            "-o",
            "/tmp/salida/SMBWMobile.ipa",
            "--progress",
            "lines"
        ])
        XCTAssertEqual(command.executable, "/usr/bin/python3")
        XCTAssertEqual(command.workingDirectory, "/repo")
        XCTAssertFalse(command.arguments.contains { $0.contains(" -k ") || $0.contains(" && ") || $0.contains("bash") })
        XCTAssertEqual(command.environment["PYTHONUNBUFFERED"], "1")
        XCTAssertEqual(command.environment["DOTNET_ROOT"], "/Users/test/.dotnet")
        XCTAssertEqual(command.environment["DOTNET_ROOT_ARM64"], "/Users/test/.dotnet")
        XCTAssertTrue(summary.contains("/repo"))
        XCTAssertFalse(summary.contains("CLAVE"))
    }

    func testPlannerNeverCopiesKeyMaterialIntoTheCommand() throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        let game = root.appendingPathComponent("juego", isDirectory: true)
        let keysDirectory = root.appendingPathComponent("claves", isDirectory: true)
        let output = root.appendingPathComponent("salida", isDirectory: true)
        try FileManager.default.createDirectory(at: game, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: keysDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let base = game.appendingPathComponent("Super Mario Bros. Wonder [010015100B514000][v0].nsp")
        let update = game.appendingPathComponent("Super Mario Bros. Wonder [010015100B514800][v327680].nsp")
        let keys = keysDirectory.appendingPathComponent("prod.keys")
        let secret = Data("CLAVE_SECRETA_NO_IMPRIMIR_9f3a".utf8)
        try Data("nsp".utf8).write(to: base)
        try Data("nsp".utf8).write(to: update)
        try secret.write(to: keys)

        var draft = sampleDraft(base: base.path)
        draft.updateNSP = update.path
        draft.prodKeys = keys.path
        draft.outputDirectory = output.path
        let planner = LiveBuildPlanner(
            candidates: [root.appendingPathComponent("anidado/nota.txt")],
            packagedEngineDirectory: nil,
            locator: MapLocator(paths: Dictionary(uniqueKeysWithValues: BuildPlanner.requiredTools.map { ($0, "/usr/bin/\($0)") }).merging(["dotnet": "/Users/test/.dotnet/dotnet"]) { _, new in new }),
            missingPythonModules: [],
            environment: ["PATH": "/usr/bin", "HOME": "/Users/test"]
        )
        let result = planner.plan(draft: draft, allowOverwrite: false)
        guard case .ready(let command, let summary) = result else {
            return XCTFail("Se esperaba un comando listo, llegó \(result)")
        }
        let rendered = ([command.executable] + command.arguments + command.environment.values + [summary]).joined(separator: "\n")
        XCTAssertFalse(rendered.contains("CLAVE_SECRETA_NO_IMPRIMIR_9f3a"))
        XCTAssertEqual(try Data(contentsOf: keys), secret)
        XCTAssertEqual(command.arguments[command.arguments.firstIndex(of: "-k")! + 1], keys.path)
    }

    func testBlocksMissingEngineToolsModulesAndSplitFolders() throws {
        var draft = sampleDraft(base: "/juegos/base [010015100B514000].nsp")
        draft.updateNSP = "/otra/update [010015100B514800].nsp"
        var facts = sampleFacts(draft: draft)
        facts.engineRoot = nil
        facts.scriptExists = false
        XCTAssertTrue(message(BuildPlanner.decide(draft: draft, facts: facts, allowOverwrite: false)).contains("No se encuentra el motor"))

        facts = sampleFacts(draft: draft)
        facts.tools["xcodegen"] = nil
        XCTAssertTrue(message(BuildPlanner.decide(draft: draft, facts: facts, allowOverwrite: false)).contains("xcodegen"))

        facts = sampleFacts(draft: draft)
        facts.missingPythonModules = ["capstone"]
        XCTAssertTrue(message(BuildPlanner.decide(draft: draft, facts: facts, allowOverwrite: false)).contains("capstone"))
        XCTAssertTrue(message(BuildPlanner.decide(draft: draft, facts: facts, allowOverwrite: false)).contains("no los instala"))

        facts = sampleFacts(draft: draft)
        let split = BuildPlanner.decide(draft: draft, facts: facts, allowOverwrite: false)
        XCTAssertTrue(message(split).contains("misma carpeta"))

        var empty = sampleFacts(draft: sampleDraft(base: "/tmp/Mario's Wonder/Game [010015100B514000][v0].nsp"))
        let base = sampleDraft(base: "/tmp/Mario's Wonder/Game [010015100B514000][v0].nsp").baseNSP
        var inspection = try XCTUnwrap(empty.files[base])
        inspection.byteCount = 0
        empty.files[base] = inspection
        XCTAssertTrue(message(BuildPlanner.decide(draft: sampleDraft(base: "/tmp/Mario's Wonder/Game [010015100B514000][v0].nsp"), facts: empty, allowOverwrite: false)).contains("vacío"))
    }

    func testBlocksSeveralGamesUnknownTitlesAndExistingIPA() {
        let draft = sampleDraft(base: "/tmp/Mario's Wonder/Game [010015100B514000][v0].nsp")
        var facts = sampleFacts(draft: draft)
        facts.siblingNSPNames.append("Other [0100000000010000][v0].nsp")
        XCTAssertTrue(message(BuildPlanner.decide(draft: draft, facts: facts, allowOverwrite: false)).contains("más de un juego"))

        var unnamed = sampleDraft(base: "/tmp/Mario's Wonder/juego.nsp")
        unnamed.updateNSP = "/tmp/Mario's Wonder/update.nsp"
        var unnamedFacts = sampleFacts(draft: unnamed)
        unnamedFacts.siblingNSPNames = ["juego.nsp", "update.nsp"]
        XCTAssertTrue(message(BuildPlanner.decide(draft: unnamed, facts: unnamedFacts, allowOverwrite: false)).contains("no abre el NSP"))

        facts = sampleFacts(draft: draft)
        let ipa = "/tmp/salida/SMBWMobile.ipa"
        facts.files[ipa] = FileInspection(exists: true, isDirectory: false, isReadable: true, isWritable: true, byteCount: 10)
        guard case .needsOverwrite(let path, let command, _) = BuildPlanner.decide(draft: draft, facts: facts, allowOverwrite: false) else {
            return XCTFail("Debía pedir autorización")
        }
        XCTAssertEqual(path, ipa)
        guard case .ready(let allowed, _) = BuildPlanner.decide(draft: draft, facts: facts, allowOverwrite: true) else {
            return XCTFail("Con autorización debía quedar listo")
        }
        XCTAssertEqual(allowed, command)
    }

    func testParserShowsRealPhasesAndOnlyReliablePercents() throws {
        var snapshot = BuildSnapshot.idle
        snapshot.status = .running
        BuildLogReducer.apply("[15:24:28] [2/4] survey: RomFS manifest …", to: &snapshot)
        XCTAssertEqual(snapshot.phases[1].title, "survey: RomFS manifest")
        XCTAssertEqual(snapshot.phases[1].state, .running)
        XCTAssertEqual(snapshot.phases[0].state, .pending)
        XCTAssertNil(snapshot.progress)

        BuildLogReducer.apply("[15:24:28] [2/4] survey: RomFS manifest: 42%, 1.9/~4.5 GB, 0:30 · ETA 0:35", to: &snapshot)
        XCTAssertNil(snapshot.progress)
        XCTAssertTrue(snapshot.phases[1].summary.contains("1.9/~4.5 GB"))

        BuildLogReducer.apply("[15:24:28] [3/7] rewrite · main: 50%, 2/4 modules, 0:10", to: &snapshot)
        XCTAssertEqual(try XCTUnwrap(snapshot.progress), 0.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.phases[2].title, "rewrite")
        XCTAssertEqual(snapshot.phases[2].state, .running)

        BuildLogReducer.apply("[15:24:28] nota suelta 80%", to: &snapshot)
        XCTAssertEqual(try XCTUnwrap(snapshot.progress), 0.5, accuracy: 0.001)

        BuildLogReducer.apply("[15:24:28] ✓ [3/7] rewrite (0:10): main, sdk", to: &snapshot)
        XCTAssertEqual(snapshot.phases[2].state, .completed)
        XCTAssertEqual(snapshot.phases[2].summary, "main, sdk")
        XCTAssertNil(snapshot.progress)

        BuildLogReducer.apply("[15:24:28] ✗ [4/7] iOS shaders (1:00): tabla distinta", to: &snapshot)
        XCTAssertEqual(snapshot.phases[3].state, .failed)
        XCTAssertEqual(snapshot.phases[3].summary, "tabla distinta")

        BuildLogReducer.apply("[15:24:28] 完成 | done: /tmp/salida/SMBWMobile.ipa（4.1 GB）", to: &snapshot)
        XCTAssertEqual(snapshot.announcedIPA, "/tmp/salida/SMBWMobile.ipa")
    }

    func testSuccessRequiresExitCodeAndTheIPAFile() {
        let ipa = "/tmp/salida/SMBWMobile.ipa"
        var snapshot = runningSnapshot(ipa: ipa)
        BuildLogReducer.finish(&snapshot, exitCode: 0, plannedIPA: ipa, ipaExists: { _ in true })
        XCTAssertEqual(snapshot.status, .succeeded)
        XCTAssertEqual(snapshot.ipaPath, ipa)

        snapshot = runningSnapshot(ipa: ipa)
        snapshot.announcedIPA = ipa
        BuildLogReducer.finish(&snapshot, exitCode: 0, plannedIPA: ipa, ipaExists: { _ in false })
        XCTAssertEqual(snapshot.status, .failed)
        XCTAssertNil(snapshot.ipaPath)
        XCTAssertTrue(snapshot.message.contains("no hay una IPA"))

        snapshot = runningSnapshot(ipa: ipa)
        BuildLogReducer.finish(&snapshot, exitCode: 1, plannedIPA: ipa, ipaExists: { _ in true })
        XCTAssertEqual(snapshot.status, .failed)
        XCTAssertNil(snapshot.ipaPath)
        XCTAssertTrue(snapshot.message.contains("código 1"))
        XCTAssertTrue(snapshot.message.contains("no se da por válida"))
    }

    func testTitleAndProfileParsersFollowTheScript() {
        XCTAssertEqual(
            TitleIdentity.applicationID(in: "Super Mario Bros. Wonder [010015100B514000][v0].nsp"),
            "010015100B514000"
        )
        XCTAssertEqual(
            TitleIdentity.applicationID(in: "Super Mario Bros. Wonder [010015100B514800][v327680].nsp"),
            "010015100B514000"
        )
        XCTAssertEqual(ProfileIPA.fileName(in: "# nota\nipa\tSMBWMobile.ipa\n"), "SMBWMobile.ipa")
        XCTAssertNil(ProfileIPA.fileName(in: "ipa\t../SMBWMobile.ipa\n"))
        XCTAssertEqual(ElapsedTime.text(65), "1:05")
        XCTAssertEqual(ElapsedTime.text(3661), "1:01:01")
    }

    private func message(_ result: BuildPlanResult) -> String {
        if case .blocked(let message) = result { return message }
        return ""
    }

    private func sampleDraft(base: String) -> ProjectDraft {
        ProjectDraft(
            id: UUID(),
            name: "Prueba",
            createdAt: Date(),
            updatedAt: Date(),
            baseNSP: base,
            updateNSP: base.replacingOccurrences(of: "[010015100B514000][v0]", with: "[010015100B514800][v327680]"),
            prodKeys: "/claves/prod.keys",
            outputDirectory: "/tmp/salida",
            isTracked: true
        )
    }

    private func sampleFacts(draft: ProjectDraft) -> BuildFacts {
        let paths = [draft.baseNSP, draft.updateNSP, draft.prodKeys]
        var files: [String: FileInspection] = [:]
        for path in paths {
            files[path] = FileInspection(exists: true, isDirectory: false, isReadable: true, isWritable: true, byteCount: 32)
        }
        files[draft.outputDirectory] = FileInspection(exists: true, isDirectory: true, isReadable: true, isWritable: true, byteCount: 0)
        return BuildFacts(
            engineRoot: "/repo",
            scriptExists: true,
            translatorExists: true,
            tools: Dictionary(uniqueKeysWithValues: BuildPlanner.requiredTools.map { ($0, "/usr/bin/\($0)") }).merging(["dotnet": "/Users/test/.dotnet/dotnet"]) { _, new in new },
            missingPythonModules: [],
            environment: ["PATH": "/usr/bin"],
            files: files,
            siblingNSPNames: [
                URL(fileURLWithPath: draft.baseNSP).lastPathComponent,
                URL(fileURLWithPath: draft.updateNSP).lastPathComponent
            ],
            profileIPANames: ["010015100B514000": "SMBWMobile.ipa"],
            prefersPackagedTools: false
        )
    }

    private func runningSnapshot(ipa: String) -> BuildSnapshot {
        var snapshot = BuildSnapshot.idle
        snapshot.status = .running
        snapshot.phases = []
        return snapshot
    }

    private func makeRepository() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("snative-engine-\(UUID().uuidString)", isDirectory: true)
        let paths = [
            "scripts/build_ipa_from_nsp.py",
            "dm/tools/nx_extract/Program.cs",
            "dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate",
            "dm/games/010015100B514000/game.tsv"
        ]
        for relative in paths {
            let url = root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        try Data("script".utf8).write(to: root.appendingPathComponent("scripts/build_ipa_from_nsp.py"))
        try Data("program".utf8).write(to: root.appendingPathComponent("dm/tools/nx_extract/Program.cs"))
        try Data("translator".utf8).write(to: root.appendingPathComponent("dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate"))
        try Data("ipa\tSMBWMobile.ipa\n".utf8).write(to: root.appendingPathComponent("dm/games/010015100B514000/game.tsv"))
        return root
    }
}

@MainActor
final class BuildSessionTests: XCTestCase {
    func testSessionTracksPhasesFailureAndCancellation() async {
        let ipa = "/tmp/salida/SMBWMobile.ipa"
        let launcher = ManualLauncher()
        let model = BuildViewModel(
            planner: StubPlanner(result: .ready(sampleCommand(ipa: ipa), summary: "listo")),
            launcher: launcher,
            ipaExists: { $0 == ipa }
        )
        await model.generate(draft: ProjectDraft.blank())
        XCTAssertEqual(model.snapshot.status, .running)
        launcher.handle?.emit("[15:24:28] [1/1] IPA pack · zip …")
        launcher.handle?.emit("[15:24:28] [1/1] IPA pack · zip: 42%, 1.0/~2.0 GB, 0:10")
        XCTAssertNil(model.snapshot.progress)
        XCTAssertEqual(model.snapshot.phases.first?.state, .running)
        launcher.handle?.emit("[15:24:28] ✓ [1/1] IPA pack (0:10): listo")
        launcher.handle?.emit("[15:24:28] 完成 | done: \(ipa)（1.0 GB）")
        launcher.handle?.finish(0)
        XCTAssertEqual(model.snapshot.status, .succeeded)
        XCTAssertEqual(model.snapshot.ipaPath, ipa)
    }

    func testExitZeroWithoutFileAndNonZeroWithFileAreFailures() async {
        let ipa = "/tmp/salida/SMBWMobile.ipa"
        let missing = ManualLauncher()
        let missingModel = BuildViewModel(
            planner: StubPlanner(result: .ready(sampleCommand(ipa: ipa), summary: "listo")),
            launcher: missing,
            ipaExists: { _ in false }
        )
        await missingModel.generate(draft: ProjectDraft.blank())
        missing.handle?.finish(0)
        XCTAssertEqual(missingModel.snapshot.status, .failed)
        XCTAssertNil(missingModel.snapshot.ipaPath)

        let present = ManualLauncher()
        let presentModel = BuildViewModel(
            planner: StubPlanner(result: .ready(sampleCommand(ipa: ipa), summary: "listo")),
            launcher: present,
            ipaExists: { $0 == ipa }
        )
        await presentModel.generate(draft: ProjectDraft.blank())
        present.handle?.finish(1)
        XCTAssertEqual(presentModel.snapshot.status, .failed)
        XCTAssertTrue(presentModel.snapshot.message.contains("código 1"))
    }

    func testCancellationDoesNotBecomeSuccess() async {
        let ipa = "/tmp/salida/SMBWMobile.ipa"
        let launcher = ManualLauncher()
        let model = BuildViewModel(
            planner: StubPlanner(result: .ready(sampleCommand(ipa: ipa), summary: "listo")),
            launcher: launcher,
            ipaExists: { _ in true }
        )
        await model.generate(draft: ProjectDraft.blank())
        launcher.handle?.emit("[15:24:28] [1/2] extract v0 …")
        model.cancel()
        XCTAssertTrue(launcher.handle?.cancelled == true)
        XCTAssertEqual(model.snapshot.status, .cancelled)
        XCTAssertEqual(model.snapshot.phases.first?.state, .failed)
        launcher.handle?.finish(0)
        XCTAssertEqual(model.snapshot.status, .cancelled)
        XCTAssertNil(model.snapshot.ipaPath)
    }

    func testABlockedEnvironmentDoesNotStartCompilation() async {
        let ipa = "/tmp/salida/SMBWMobile.ipa"
        let launcher = ManualLauncher()
        let model = BuildViewModel(
            planner: StubPlanner(result: .ready(sampleCommand(ipa: ipa), summary: "listo")),
            launcher: launcher,
            ipaExists: { _ in true }
        )
        model.environmentGate = { "Impiden generar una IPA: Xcode, SDK de iOS." }
        await model.generate(draft: ProjectDraft.blank())
        XCTAssertNil(launcher.handle)
        XCTAssertEqual(model.snapshot.status, .idle)
        XCTAssertTrue(model.readiness.contains("Xcode"))
        XCTAssertTrue(model.readiness.contains("SDK de iOS"))
    }

    func testConfirmingAnOverwriteAlsoRespectsTheEnvironmentGate() async {
        let ipa = "/tmp/salida/SMBWMobile.ipa"
        let command = sampleCommand(ipa: ipa)
        let launcher = ManualLauncher()
        let model = BuildViewModel(
            planner: StubPlanner(result: .needsOverwrite(path: ipa, command: command, summary: "ya existe")),
            launcher: launcher,
            ipaExists: { _ in true }
        )
        await model.generate(draft: ProjectDraft.blank())
        XCTAssertEqual(model.overwritePath, ipa)
        model.environmentGate = { "Impiden generar una IPA: Metal." }
        model.confirmOverwrite()
        XCTAssertNil(launcher.handle)
        XCTAssertNil(model.overwritePath)
        XCTAssertEqual(model.snapshot.status, .idle)
        XCTAssertTrue(model.readiness.contains("Metal"))
    }

    func testExistingIPAAsksBeforeLaunching() async {
        let ipa = "/tmp/salida/SMBWMobile.ipa"
        let command = sampleCommand(ipa: ipa)
        let launcher = ManualLauncher()
        let model = BuildViewModel(
            planner: StubPlanner(result: .needsOverwrite(path: ipa, command: command, summary: "ya existe")),
            launcher: launcher,
            ipaExists: { _ in true }
        )
        await model.generate(draft: ProjectDraft.blank())
        XCTAssertNil(launcher.handle)
        XCTAssertEqual(model.snapshot.status, .idle)
        XCTAssertEqual(model.overwritePath, ipa)
        model.confirmOverwrite()
        XCTAssertEqual(model.snapshot.status, .running)
        XCTAssertNotNil(launcher.handle)
    }

    private func sampleCommand(ipa: String) -> BuildCommand {
        BuildCommand(
            executable: "/usr/bin/python3",
            arguments: ["/repo/scripts/build_ipa_from_nsp.py", "/nsp", "-k", "/claves/prod.keys", "-o", ipa, "--progress", "lines"],
            environment: [:],
            workingDirectory: "/repo",
            expectedIPA: ipa,
            nspDirectory: "/nsp"
        )
    }
}

private struct StubPlanner: BuildPlanning {
    var result: BuildPlanResult
    func plan(draft: ProjectDraft, allowOverwrite: Bool) -> BuildPlanResult { result }
}

private final class ManualHandle: RunningBuild, @unchecked Sendable {
    var onLine: (@Sendable (String) -> Void)?
    var onExit: (@Sendable (Int32) -> Void)?
    private(set) var cancelled = false
    func emit(_ line: String) { onLine?(line) }
    func finish(_ code: Int32) { onExit?(code) }
    func start() throws {}
    func cancel() { cancelled = true }
}

private final class ManualLauncher: BuildLaunching, @unchecked Sendable {
    var handle: ManualHandle?
    func make(_ command: BuildCommand) -> any RunningBuild {
        let handle = ManualHandle()
        self.handle = handle
        return handle
    }
}

private struct MapLocator: ExecutableLocating {
    var paths: [String: String]
    func path(for executable: String) -> String? { paths[executable] }
}
