import XCTest
@testable import SNativeStudio

final class BuildAndToolsTests: XCTestCase {
    func testIdleBuildHasNoProgressAndNoLog() {
        let snapshot = BuildSnapshot.idle
        XCTAssertNil(snapshot.progress)
        XCTAssertTrue(snapshot.log.isEmpty)
        XCTAssertFalse(snapshot.hasStarted)
        XCTAssertEqual(snapshot.phases.count, 5)
        XCTAssertTrue(snapshot.phases.allSatisfy { $0.state == .pending })
    }

    func testProbeReportsOnlyWhatTheLocatorFinds() {
        let probe = EnvironmentProbe(locator: MapLocator(paths: ["swift": "/usr/bin/swift", "xcodebuild": "/usr/bin/xcodebuild"]))
        let tools = probe.inspect()
        XCTAssertEqual(tools.count, DependencyCatalog.specs.count)
        XCTAssertEqual(tools.first { $0.id == "swift" }?.state, .available(path: "/usr/bin/swift"))
        XCTAssertEqual(tools.first { $0.id == "swift" }?.requirement, .optional)
        XCTAssertEqual(tools.first { $0.id == "brew" }?.state, .missing)
        XCTAssertEqual(tools.first { $0.id == "xcode" }?.requirement, .required)
        XCTAssertFalse(tools.contains { tool in
            if case .available(let path) = tool.state, path.isEmpty { return true }
            return false
        })
    }

    func testIdentity() {
        XCTAssertEqual(AppIdentity.name, "SNative Studio")
        XCTAssertEqual(AppIdentity.signature, "Desarrollado por AbadX.")
        XCTAssertEqual(AppIdentity.version, "0.1.0")
    }
}

private struct MapLocator: ExecutableLocating {
    var paths: [String: String]
    func path(for executable: String) -> String? { paths[executable] }
}
