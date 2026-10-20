import XCTest
@testable import SNativeStudio

@MainActor
final class ProjectLibraryTests: XCTestCase {
    func testSavesReloadsEditsAndDuplicatesProjects() throws {
        let studio = try makeStudio()
        defer { try? FileManager.default.removeItem(at: studio.library.fileURL.deletingLastPathComponent()) }
        var first = ProjectDraft.blank()
        first.name = "Mario"
        first.baseNSP = "/juegos/mario/base [010015100B514000].nsp"
        first.prodKeys = "/claves/prod.keys"
        first.outputDirectory = "/salida/mario"
        first.ipaName = "SMBWMobile.ipa"
        studio.saveEditor(first)

        var second = ProjectDraft.blank()
        second.name = "Zelda"
        second.baseNSP = "/juegos/zelda/base.nsp"
        second.outputDirectory = "/salida/zelda"
        second.ipaName = "Zelda.ipa"
        studio.saveEditor(second)

        let reloaded = try StudioViewModel(
            settings: SettingsViewModel(store: PreferencesStore(defaults: suite())),
            build: BuildViewModel(planner: IdlePlanner(), launcher: NoopLauncher()),
            tools: ToolsViewModel(probe: EnvironmentProbe(locator: EmptyLocator())),
            library: ProjectLibrary(fileURL: studio.library.fileURL, legacyProjects: { [] })
        )
        XCTAssertEqual(reloaded.projects.map(\.name).sorted(), ["Mario", "Zelda"])
        XCTAssertEqual(reloaded.projects.first { $0.name == "Mario" }?.ipaName, "SMBWMobile.ipa")
        XCTAssertEqual(reloaded.projects.first { $0.name == "Zelda" }?.baseNSP, "/juegos/zelda/base.nsp")

        var edited = try XCTUnwrap(reloaded.projects.first { $0.name == "Mario" })
        let createdAt = edited.createdAt
        edited.name = "Mario editado"
        edited.ipaName = "Personalizada.ipa"
        reloaded.saveEditor(edited)
        let stored = try XCTUnwrap(reloaded.projects.first { $0.id == edited.id })
        XCTAssertEqual(stored.name, "Mario editado")
        XCTAssertEqual(stored.ipaName, "Personalizada.ipa")
        XCTAssertEqual(stored.createdAt, createdAt)
        XCTAssertEqual(reloaded.projects.count, 2)

        reloaded.duplicate(stored)
        XCTAssertEqual(reloaded.projects.count, 3)
        let copy = try XCTUnwrap(reloaded.projects.first { $0.name == "Copia de Mario editado" })
        XCTAssertNotEqual(copy.id, stored.id)
        XCTAssertEqual(copy.baseNSP, stored.baseNSP)
        XCTAssertEqual(copy.prodKeys, stored.prodKeys)
        XCTAssertEqual(copy.ipaName, stored.ipaName)
    }

    func testDeletionRemovesOnlyTheRecord() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let nsp = directory.appendingPathComponent("base.nsp")
        let keys = directory.appendingPathComponent("prod.keys")
        let secret = Data("CLAVE_SECRETA_NO_GUARDAR".utf8)
        try Data("nsp".utf8).write(to: nsp)
        try secret.write(to: keys)

        let studio = try makeStudio()
        defer { try? FileManager.default.removeItem(at: studio.library.fileURL.deletingLastPathComponent()) }
        var project = ProjectDraft.blank()
        project.name = "Conservar archivos"
        project.baseNSP = nsp.path
        project.prodKeys = keys.path
        project.outputDirectory = directory.path
        studio.saveEditor(project)
        studio.askToDelete(project)
        studio.confirmDeletion()

        XCTAssertTrue(studio.projects.isEmpty)
        XCTAssertEqual(try Data(contentsOf: nsp), Data("nsp".utf8))
        XCTAssertEqual(try Data(contentsOf: keys), secret)
        let saved = try Data(contentsOf: studio.library.fileURL)
        XCTAssertFalse(String(decoding: saved, as: UTF8.self).contains("CLAVE_SECRETA_NO_GUARDAR"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: nsp.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: keys.path))
    }

    func testOptionalUpdateCustomIPAAndProjectIsolation() {
        var mario = ProjectDraft.blank()
        mario.baseNSP = "/tmp/Mario's Wonder/Game [010015100B514000][v0].nsp"
        mario.updateNSP = ""
        mario.prodKeys = "/claves/mario/prod.keys"
        mario.outputDirectory = "/tmp/salida-mario"
        mario.ipaName = "Personalizada.ipa"
        var facts = readyFacts(draft: mario)
        facts.profileIPANames = [:]
        guard case .ready(let marioCommand, _) = BuildPlanner.decide(draft: mario, facts: facts, allowOverwrite: false) else {
            return XCTFail("El nombre personalizado debía bastar sin el perfil")
        }
        XCTAssertEqual(marioCommand.arguments[marioCommand.arguments.firstIndex(of: "-o")! + 1], "/tmp/salida-mario/Personalizada.ipa")

        var zelda = mario
        zelda.id = UUID()
        zelda.prodKeys = "/claves/zelda/prod.keys"
        zelda.outputDirectory = "/tmp/salida-zelda"
        zelda.ipaName = "Zelda.ipa"
        zelda.baseNSP = "/tmp/Zelda/Game [01007EF00011E000][v0].nsp"
        var zeldaFacts = readyFacts(draft: zelda)
        zeldaFacts.profileIPANames = [:]
        guard case .ready(let zeldaCommand, _) = BuildPlanner.decide(draft: zelda, facts: zeldaFacts, allowOverwrite: false) else {
            return XCTFail("Zelda debía tener su propio comando")
        }
        XCTAssertTrue(marioCommand.arguments.contains("/claves/mario/prod.keys"))
        XCTAssertFalse(marioCommand.arguments.contains("/claves/zelda/prod.keys"))
        XCTAssertTrue(zeldaCommand.arguments.contains("/claves/zelda/prod.keys"))
        XCTAssertFalse(zeldaCommand.arguments.contains("/claves/mario/prod.keys"))
        XCTAssertEqual(zeldaCommand.arguments[zeldaCommand.arguments.firstIndex(of: "-o")! + 1], "/tmp/salida-zelda/Zelda.ipa")

        mario.ipaName = "../fuera.ipa"
        XCTAssertTrue(message(BuildPlanner.decide(draft: mario, facts: facts, allowOverwrite: false)).contains("no es válido"))
    }

    func testValidationAllowsAnIncompleteSaveAndAMissingUpdate() {
        let validation = ProjectValidation.evaluate(.blank()) { _ in nil }
        XCTAssertFalse(validation.isComplete)
        var draft = ProjectDraft.blank()
        draft.baseNSP = "/a/base.nsp"
        draft.prodKeys = "/a/prod.keys"
        draft.outputDirectory = "/a/salida"
        let ready = ProjectValidation.evaluate(draft) { path in
            PathFacts(exists: true, isDirectory: path.hasSuffix("salida"))
        }
        XCTAssertTrue(ready.isComplete)
        XCTAssertEqual(ready.fields.first { $0.title == "NSP de actualización" }?.statusText, "Opcional")
    }

    func testCacheDetectionUsesOnlyTheTitleFolder() {
        let present = CacheStatus.detect(draft: titledDraft()) { $0.hasSuffix("010015100B514000_build") }
        guard case .present(let path) = present else { return XCTFail("\(present)") }
        XCTAssertTrue(path.hasSuffix("010015100B514000_build"))

        let absent = CacheStatus.detect(draft: titledDraft()) { _ in false }
        guard case .absent = absent else { return XCTFail("\(absent)") }

        var unnamed = ProjectDraft.blank()
        unnamed.baseNSP = "/juegos/base.nsp"
        guard case .unknown = CacheStatus.detect(draft: unnamed, directoryExists: { _ in true }) else {
            return XCTFail("Sin título no hay una carpeta fiable")
        }
    }

    func testLegacyProjectsWithoutIPANameStillLoad() throws {
        var draft = ProjectDraft.blank()
        draft.name = "Viejo"
        draft.prodKeys = "/claves/prod.keys"
        let encoded = try JSONEncoder().encode([draft])
        var rows = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        rows[0].removeValue(forKey: "ipaName")
        let stripped = try JSONSerialization.data(withJSONObject: rows)
        XCTAssertNil(try? JSONDecoder().decode([ProjectDraft].self, from: stripped))
        let loaded = try XCTUnwrap(ProjectDraft.decodeList(from: stripped))
        XCTAssertEqual(loaded.first?.name, "Viejo")
        XCTAssertEqual(loaded.first?.ipaName, "")
        XCTAssertEqual(loaded.first?.prodKeys, "/claves/prod.keys")
    }

    func testCompilationUsesTheSelectedProject() async {
        let planner = RecordingPlanner()
        let model = BuildViewModel(planner: planner, launcher: NoopLauncher())
        var mario = ProjectDraft.blank()
        mario.prodKeys = "/claves/mario.keys"
        mario.ipaName = "Mario.ipa"
        var zelda = ProjectDraft.blank()
        zelda.prodKeys = "/claves/zelda.keys"
        zelda.ipaName = "Zelda.ipa"
        await model.generate(draft: zelda)
        XCTAssertEqual(planner.received?.id, zelda.id)
        XCTAssertEqual(planner.received?.prodKeys, "/claves/zelda.keys")
        XCTAssertNotEqual(planner.received?.prodKeys, mario.prodKeys)
        XCTAssertEqual(model.compiledProjectID, zelda.id)
    }

    private func titledDraft() -> ProjectDraft {
        var draft = ProjectDraft.blank()
        draft.baseNSP = "/juegos/mario/Game [010015100B514000][v0].nsp"
        return draft
    }

    private func message(_ result: BuildPlanResult) -> String {
        if case .blocked(let message) = result { return message }
        return ""
    }

    private func readyFacts(draft: ProjectDraft) -> BuildFacts {
        var files: [String: FileInspection] = [:]
        for path in [draft.baseNSP, draft.prodKeys] where !path.isEmpty {
            files[path] = FileInspection(exists: true, isDirectory: false, isReadable: true, isWritable: true, byteCount: 32)
        }
        files[draft.outputDirectory] = FileInspection(exists: true, isDirectory: true, isReadable: true, isWritable: true, byteCount: 0)
        return BuildFacts(
            engineRoot: "/repo",
            scriptExists: true,
            translatorExists: true,
            tools: Dictionary(uniqueKeysWithValues: BuildPlanner.requiredTools.map { ($0, "/usr/bin/\($0)") }),
            missingPythonModules: [],
            environment: ["PATH": "/usr/bin"],
            files: files,
            siblingNSPNames: [URL(fileURLWithPath: draft.baseNSP).lastPathComponent],
            profileIPANames: [:],
            prefersPackagedTools: false
        )
    }

    private func suite() -> UserDefaults {
        let name = "snative.projects.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeStudio() throws -> StudioViewModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return StudioViewModel(
            settings: SettingsViewModel(store: PreferencesStore(defaults: suite())),
            build: BuildViewModel(planner: IdlePlanner(), launcher: NoopLauncher()),
            tools: ToolsViewModel(probe: EnvironmentProbe(locator: EmptyLocator())),
            library: ProjectLibrary(fileURL: directory.appendingPathComponent("projects.json"), legacyProjects: { [] })
        )
    }

}

private struct IdlePlanner: BuildPlanning {
    func plan(draft: ProjectDraft, allowOverwrite: Bool) -> BuildPlanResult { .blocked("sin compilar") }
}

private final class RecordingPlanner: BuildPlanning, @unchecked Sendable {
    var received: ProjectDraft?
    func plan(draft: ProjectDraft, allowOverwrite: Bool) -> BuildPlanResult {
        received = draft
        return .blocked("sin compilar")
    }
}

private struct EmptyLocator: ExecutableLocating {
    func path(for executable: String) -> String? { nil }
}

private final class NoopRunningBuild: RunningBuild, @unchecked Sendable {
    var onLine: (@Sendable (String) -> Void)?
    var onExit: (@Sendable (Int32) -> Void)?
    func start() throws {}
    func cancel() {}
}

private struct NoopLauncher: BuildLaunching {
    func make(_ command: BuildCommand) -> any RunningBuild { NoopRunningBuild() }
}
