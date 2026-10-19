import XCTest
@testable import SNativeStudio

@MainActor
final class ProjectViewModelTests: XCTestCase {
    func testNewProjectIsTrackedAndDoesNotInventPaths() {
        let model = ProjectViewModel()
        var saved: ProjectDraft?
        model.onChange = { saved = $0 }
        let created = model.startNew()
        XCTAssertTrue(created.isTracked)
        XCTAssertEqual(created.baseNSP, "")
        XCTAssertEqual(created.updateNSP, "")
        XCTAssertEqual(created.prodKeys, "")
        XCTAssertEqual(created.outputDirectory, "")
        XCTAssertEqual(saved?.id, created.id)
    }

    func testUntrackedEditsAreNotPublished() {
        let model = ProjectViewModel()
        var calls = 0
        model.onChange = { _ in calls += 1 }
        model.setBaseNSP("/tmp/base.nsp")
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(model.draft.baseNSP, "/tmp/base.nsp")
    }
}
