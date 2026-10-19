import XCTest
@testable import SNativeStudio

final class PathValidationTests: XCTestCase {
    func testEmptyPath() {
        XCTAssertEqual(PathValidation.verdict(path: "   ", kind: .nsp, facts: nil), .empty)
        XCTAssertEqual(PathValidation.verdict(path: "", kind: .directory, facts: nil), .empty)
    }

    func testMissingPath() {
        XCTAssertEqual(
            PathValidation.verdict(path: "/tmp/no-existe.nsp", kind: .nsp, facts: nil),
            .missing
        )
    }

    func testNSPRules() {
        XCTAssertEqual(
            PathValidation.verdict(path: "/juegos/base.txt", kind: .nsp, facts: PathFacts(exists: true, isDirectory: false)),
            .wrongExtension
        )
        XCTAssertEqual(
            PathValidation.verdict(path: "/juegos/base.nsp", kind: .nsp, facts: PathFacts(exists: true, isDirectory: true)),
            .notFile
        )
        XCTAssertEqual(
            PathValidation.verdict(path: "/juegos/base.NSP", kind: .nsp, facts: PathFacts(exists: true, isDirectory: false)),
            .valid
        )
    }

    func testProdKeysName() {
        XCTAssertEqual(
            PathValidation.verdict(path: "/claves/title.keys", kind: .prodKeys, facts: PathFacts(exists: true, isDirectory: false)),
            .wrongFileName
        )
        XCTAssertEqual(
            PathValidation.verdict(path: "/claves/prod.keys", kind: .prodKeys, facts: PathFacts(exists: true, isDirectory: false)),
            .valid
        )
    }

    func testDirectory() {
        XCTAssertEqual(
            PathValidation.verdict(path: "/salida/archivo", kind: .directory, facts: PathFacts(exists: true, isDirectory: false)),
            .notDirectory
        )
        XCTAssertEqual(
            PathValidation.verdict(path: "/salida", kind: .directory, facts: PathFacts(exists: true, isDirectory: true)),
            .valid
        )
    }

    func testIncompleteProjectIsNotReady() {
        let validation = ProjectValidation.evaluate(.blank()) { _ in nil }
        XCTAssertFalse(validation.isComplete)
        XCTAssertEqual(validation.fields.count, 4)
        XCTAssertTrue(validation.summary.contains("Faltan"))
    }

    func testCompleteProjectDoesNotClaimCompilation() {
        let draft = ProjectDraft(
            id: UUID(),
            name: "Prueba",
            createdAt: Date(),
            updatedAt: Date(),
            baseNSP: "/a/base.nsp",
            updateNSP: "/a/update.nsp",
            prodKeys: "/a/prod.keys",
            outputDirectory: "/a/salida",
            isTracked: true
        )
        let validation = ProjectValidation.evaluate(draft) { path in
            PathFacts(exists: true, isDirectory: path.hasSuffix("salida"))
        }
        XCTAssertTrue(validation.isComplete)
        XCTAssertTrue(validation.summary.contains("no procesa"))
    }

    func testFileManagerSeesTemporaryFileWithoutReadingIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let nsp = directory.appendingPathComponent("muestra.nsp")
        try Data().write(to: nsp)
        let verdict = PathValidation.verdict(path: nsp.path, kind: .nsp, facts: PathValidation.facts(for: nsp.path))
        XCTAssertEqual(verdict, .valid)
        XCTAssertEqual(try Data(contentsOf: nsp), Data())
    }
}
