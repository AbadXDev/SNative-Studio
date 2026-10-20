import XCTest
@testable import SNativeStudio

final class DependencyDiagnosisTests: XCTestCase {
    func testCatalogSeparatesRequiredToolsFromOptionalOnes() {
        let required = Set(DependencyCatalog.specs.filter { $0.requirement == .required }.map(\.id))
        XCTAssertEqual(required, Set([
            "engine", "python", "python-modules", "xcode", "ios-sdk", "metal", "make",
            "xcodegen", "dotnet", "libhac", "zstd", "spirv", "zip"
        ]))
        XCTAssertEqual(DependencyCatalog.specs.filter { $0.requirement == .optional }.map(\.id), ["swift", "brew"])
    }

    func testInvalidPathsAreNotAvailable() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let probe = EnvironmentProbe(locator: MapLocator(paths: [
            "swift": "",
            "xcodegen": directory.path,
            "zstd": directory.appendingPathComponent("ausente").path
        ]))
        let tools = probe.inspect()
        XCTAssertEqual(tools.first { $0.id == "swift" }?.state, .missing)
        XCTAssertEqual(tools.first { $0.id == "xcodegen" }?.state, .missing)
        XCTAssertEqual(tools.first { $0.id == "zstd" }?.state, .missing)
        XCTAssertFalse(tools.contains { $0.isAvailable && $0.location.isEmpty })
    }

    func testLocatorIgnoresANonExecutableFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("texto".utf8).write(to: directory.appendingPathComponent("zstd"))
        let locator = FileSystemLocator(directories: [directory.path])
        XCTAssertNil(locator.path(for: "zstd"))
        XCTAssertNil(locator.path(for: "make"))
    }

    func testAToolInsideTheBundleIsIncludedAndAnExternalOneIsOnlyAvailable() throws {
        let resources = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: resources) }
        let bundled = BundledLayout.toolsDirectory(resources: resources).appendingPathComponent("bin/zstd")
        try writeExecutable(bundled)
        let external = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: external) }
        let externalTool = external.appendingPathComponent("make")
        try writeExecutable(externalTool)

        let probe = EnvironmentProbe(
            locator: FileSystemLocator(directories: [bundled.deletingLastPathComponent().path, external.path]),
            bundledPrefixes: [BundledLayout.toolsDirectory(resources: resources).path]
        )
        let tools = probe.inspect()
        XCTAssertEqual(tools.first { $0.id == "zstd" }?.state, .included(path: bundled.path))
        XCTAssertEqual(tools.first { $0.id == "zstd" }?.statusTitle, "Incluida en SNative Studio")
        XCTAssertEqual(tools.first { $0.id == "make" }?.state, .available(path: externalTool.path))
        XCTAssertEqual(tools.first { $0.id == "make" }?.statusTitle, "Disponible")
    }

    func testDotNetMajorVersionIsTheOnlyCompatibilityCheck() {
        let old = EnvironmentProbe(
            locator: MapLocator(paths: ["dotnet": "/bin/echo"]),
            source: .supplied(DependencyMeasurement(versions: ["dotnet": "8.0.100"]))
        ).inspect().first { $0.id == "dotnet" }
        XCTAssertEqual(old?.state, .incompatible(path: "/bin/echo", version: "8.0.100", expected: ".NET SDK 10"))
        XCTAssertEqual(old?.statusTitle, "Versión incompatible")
        XCTAssertTrue(old?.blocksCompilation ?? false)

        let current = EnvironmentProbe(
            locator: MapLocator(paths: ["dotnet": "/bin/echo"]),
            source: .supplied(DependencyMeasurement(versions: ["dotnet": "10.0.402"]))
        ).inspect().first { $0.id == "dotnet" }
        XCTAssertEqual(current?.state, .available(path: "/bin/echo"))
        XCTAssertEqual(current?.version, "10.0.402")
        XCTAssertFalse(current?.blocksCompilation ?? true)
    }

    func testIncompletePackagedEngineIsReportedAndDoesNotUseAnotherCopy() throws {
        let resources = try makeTemporaryDirectory()
        let external = try makeEngine()
        defer { try? FileManager.default.removeItem(at: resources) }
        defer { try? FileManager.default.removeItem(at: external) }
        let packaged = BundledLayout.engineDirectory(resources: resources)
        try writeFile(packaged.appendingPathComponent(EngineLocator.scriptRelativePath), contents: "script")
        let location = EngineLocator.resolve(packagedDirectory: packaged, externalCandidates: [external])
        let engine = EnvironmentProbe(
            locator: MapLocator(paths: [:]),
            source: .supplied(DependencyMeasurement(engine: location))
        ).inspect().first { $0.id == "engine" }

        XCTAssertEqual(engine?.statusTitle, "Incompleto")
        XCTAssertNotEqual(engine?.statusTitle, "Incluida en SNative Studio")
        XCTAssertTrue(engine?.blocksCompilation ?? false)
        let text = (engine?.location ?? "") + (engine?.actions.map(actionText).joined(separator: "\n") ?? "")
        XCTAssertTrue(text.contains(EngineLocator.translatorRelativePath))
        XCTAssertFalse(text.contains(external.path))
    }

    func testACompletePackagedEngineIsIncludedAndAnExternalCheckoutStaysSeparate() throws {
        let packaged = try makeEngine()
        let external = try makeEngine()
        defer { try? FileManager.default.removeItem(at: packaged) }
        defer { try? FileManager.default.removeItem(at: external) }

        let included = report(engine: .packaged(packaged))
        XCTAssertEqual(included.statusTitle, "Incluida en SNative Studio")
        XCTAssertTrue(included.actions.isEmpty)
        XCTAssertFalse(included.blocksCompilation)

        let checkout = report(engine: .external(external))
        XCTAssertEqual(checkout.statusTitle, "Disponible")
        XCTAssertNotEqual(checkout.statusTitle, "Incluida en SNative Studio")
        XCTAssertTrue(checkout.note?.contains("Contents/Resources/Engine") ?? false)
        XCTAssertTrue(checkout.actions.isEmpty)
    }

    func testDeveloperPathsMustExistAndAreNeverMarkedIncluded() throws {
        let resources = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: resources) }
        let metal = BundledLayout.toolsDirectory(resources: resources).appendingPathComponent("bin/metal")
        try writeExecutable(metal)
        let tools = EnvironmentProbe(
            locator: MapLocator(paths: [:]),
            bundledPrefixes: [BundledLayout.toolsDirectory(resources: resources).path],
            source: .supplied(DependencyMeasurement(
                iosSDKPath: resources.path,
                metalPath: metal.path
            ))
        ).inspect()
        XCTAssertEqual(tools.first { $0.id == "ios-sdk" }?.state, .available(path: resources.path))
        XCTAssertEqual(tools.first { $0.id == "metal" }?.state, .available(path: metal.path))

        let missing = EnvironmentProbe(
            locator: MapLocator(paths: [:]),
            source: .supplied(DependencyMeasurement(iosSDKPath: "/no/existe/sdk", metalPath: resources.path))
        ).inspect()
        XCTAssertEqual(missing.first { $0.id == "ios-sdk" }?.state, .missing)
        XCTAssertEqual(missing.first { $0.id == "metal" }?.state, .missing)
    }

    func testPythonModulesOfferTheDocumentedCommandOnlyWhenPythonExists() {
        let absent = EnvironmentProbe(locator: MapLocator(paths: [:])).inspect().first { $0.id == "python-modules" }
        XCTAssertEqual(absent?.state, .missing)
        XCTAssertTrue(copyCommands(in: absent?.actions ?? []).isEmpty)
        XCTAssertEqual(absent?.statusTitle, "Requiere instalación manual")

        let partial = EnvironmentProbe(
            locator: MapLocator(paths: ["python3": "/usr/bin/python3"]),
            source: .supplied(DependencyMeasurement(missingPythonModules: ["capstone"]))
        ).inspect().first { $0.id == "python-modules" }
        XCTAssertEqual(partial?.location, "Faltan: capstone.")
        XCTAssertEqual(copyCommands(in: partial?.actions ?? []), [DependencyGuide.pythonModulesCommand])
        XCTAssertEqual(partial?.statusTitle, "No detectada")
    }

    func testHelpActionsStayAsTextAndFollowTheDocumentedCommands() {
        let xcode = DependencyGuide.actions(id: "xcode", brewDetected: true, pythonDetected: true)
        XCTAssertTrue(copyCommands(in: xcode).isEmpty)
        XCTAssertTrue(xcode.contains { action in
            if case .openDocumentation(let url) = action.kind { return url == DependencyGuide.xcodeDocumentation }
            return false
        })

        let xcodegen = DependencyGuide.actions(id: "xcodegen", brewDetected: false, pythonDetected: false)
        XCTAssertTrue(copyCommands(in: xcodegen).isEmpty)
        XCTAssertTrue(actionText(xcodegen[0]).contains("Homebrew no está detectado"))

        let withBrew = DependencyGuide.actions(id: "xcodegen", brewDetected: true, pythonDetected: false)
        XCTAssertEqual(copyCommands(in: withBrew), [DependencyGuide.xcodeGenCommand])

        let dotnet = DependencyGuide.actions(id: "dotnet", brewDetected: true, pythonDetected: false)
        XCTAssertEqual(copyCommands(in: dotnet), [DependencyGuide.dotNetCommand])
        XCTAssertTrue(actionText(dotnet[0]).contains(".NET SDK 10"))

        let homebrew = DependencyGuide.actions(id: "brew", brewDetected: false, pythonDetected: false)
        XCTAssertTrue(copyCommands(in: homebrew).isEmpty)
        XCTAssertTrue(homebrew.contains { action in
            if case .openDocumentation(let url) = action.kind { return url == DependencyGuide.homebrewDocumentation }
            return false
        })

        for id in DependencyCatalog.specs.map(\.id) {
            for action in DependencyGuide.actions(id: id, brewDetected: true, pythonDetected: true) + DependencyGuide.actions(id: id, brewDetected: false, pythonDetected: false) {
                if case .copyCommand(let command) = action.kind {
                    XCTAssertFalse(command.contains("sudo"))
                    XCTAssertFalse(command.contains("curl"))
                }
            }
        }
    }

    @MainActor
    func testMissingEssentialsBlockCompilationAndOptionalToolsDoNot() throws {
        let blocked = ToolsViewModel(probe: EnvironmentProbe(locator: MapLocator(paths: [:])))
        let message = try XCTUnwrap(blocked.compilationBlock)
        XCTAssertTrue(message.contains("nxnative"))
        XCTAssertTrue(message.contains("Python 3"))
        XCTAssertTrue(message.contains("Xcode"))
        XCTAssertTrue(message.contains("SDK de iOS"))
        XCTAssertTrue(message.contains("Metal"))
        XCTAssertFalse(message.contains("Swift"))
        XCTAssertFalse(message.contains("Homebrew"))
        let pending = try XCTUnwrap(ToolsViewModel.compilationBlock(isChecking: true, tools: []))
        XCTAssertTrue(pending.contains("no ha terminado"))

        let engine = try makeEngine()
        let sdk = try makeTemporaryDirectory()
        let metal = sdk.appendingPathComponent("metal")
        defer { try? FileManager.default.removeItem(at: engine) }
        defer { try? FileManager.default.removeItem(at: sdk) }
        try writeExecutable(metal)
        try writeFile(sdk.appendingPathComponent("libhac.0.19.0.nupkg"), contents: "nupkg")
        var paths: [String: String] = [:]
        for name in ["python3", "xcodebuild", "make", "xcodegen", "dotnet", "zstd", "spirv-cross", "zip"] {
            paths[name] = "/bin/echo"
        }
        let ready = ToolsViewModel(probe: EnvironmentProbe(
            locator: MapLocator(paths: paths),
            source: .supplied(DependencyMeasurement(
                versions: ["dotnet": "10.0.402"],
                missingPythonModules: [],
                engine: .packaged(engine),
                iosSDKPath: sdk.path,
                metalPath: metal.path,
                libHacPath: sdk.appendingPathComponent("libhac.0.19.0.nupkg").path
            ))
        ))
        XCTAssertNil(ready.compilationBlock)
        XCTAssertFalse(ready.isChecking)
    }

    @MainActor
    func testSynchronousRefreshDoesNotStayInTheCheckingState() {
        let model = ToolsViewModel(probe: EnvironmentProbe(locator: MapLocator(paths: [:])))
        XCTAssertFalse(model.isChecking)
        XCTAssertEqual(model.tools.count, DependencyCatalog.specs.count)
        XCTAssertTrue(model.blockingSummary.contains("nxnative"))
        XCTAssertTrue(model.optionalSummary.contains("Swift"))
        XCTAssertTrue(model.optionalSummary.contains("Homebrew"))
        model.refresh()
        XCTAssertFalse(model.isChecking)
        XCTAssertEqual(model.tools.count, DependencyCatalog.specs.count)
    }

    private func report(engine: EngineLocation) -> ToolDependency {
        let tool = EnvironmentProbe(
            locator: MapLocator(paths: [:]),
            source: .supplied(DependencyMeasurement(engine: engine))
        ).inspect().first { $0.id == "engine" }
        return tool!
    }

    private func copyCommands(in actions: [DependencyAction]) -> [String] {
        actions.compactMap { action in
            if case .copyCommand(let command) = action.kind { return command }
            return nil
        }
    }

    private func actionText(_ action: DependencyAction) -> String {
        if case .manual(let text) = action.kind { return text }
        return ""
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("snative-diagnosis-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeEngine() throws -> URL {
        let root = try makeTemporaryDirectory()
        try writeFile(root.appendingPathComponent(EngineLocator.scriptRelativePath), contents: "script")
        try writeFile(root.appendingPathComponent(EngineLocator.extractorRelativePath), contents: "program")
        try writeFile(root.appendingPathComponent(EngineLocator.translatorRelativePath), contents: "translator")
        return root
    }

    private func writeFile(_ url: URL, contents: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    func testDotNetSDK10IsChosenAheadOfAnEarlierSDK() throws {
        let earlier = try makeTemporaryDirectory()
        let current = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: earlier) }
        defer { try? FileManager.default.removeItem(at: current) }
        try writeExecutable(earlier.appendingPathComponent("dotnet"), contents: "#!/bin/sh\necho 8.0.100\n")
        try writeExecutable(current.appendingPathComponent("dotnet"), contents: "#!/bin/sh\necho 10.0.402\n")
        let locator = FileSystemLocator(directories: [earlier.path, current.path])
        XCTAssertEqual(locator.path(for: "dotnet"), current.appendingPathComponent("dotnet").path)

        try writeExecutable(earlier.appendingPathComponent("dotnet"), contents: "#!/bin/sh\necho 10.0.402\n")
        try writeExecutable(current.appendingPathComponent("dotnet"), contents: "#!/bin/sh\necho 8.0.100\n")
        XCTAssertEqual(locator.path(for: "dotnet"), earlier.appendingPathComponent("dotnet").path)
    }

    func testCustomPathIsSearchedAfterTheUsualLocations() throws {
        let custom = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: custom) }
        try writeExecutable(custom.appendingPathComponent("snative-audit-tool"))
        let directories = FileSystemLocator.defaultDirectories(resources: nil, path: custom.path)
        XCTAssertLessThan(directories.firstIndex(of: "/usr/bin")!, directories.firstIndex(of: custom.path)!)
        XCTAssertLessThan(directories.firstIndex(of: "/opt/homebrew/bin")!, directories.firstIndex(of: custom.path)!)
        let locator = FileSystemLocator(directories: ["/opt/homebrew/bin", custom.path])
        XCTAssertEqual(locator.path(for: "snative-audit-tool"), custom.appendingPathComponent("snative-audit-tool").path)
        XCTAssertNil(FileSystemLocator(directories: ["/opt/homebrew/bin"]).path(for: "snative-audit-tool"))
    }

    func testLibHacIsRequiredAndDoesNotOfferADownloadCommand() throws {
        let missing = EnvironmentProbe(locator: MapLocator(paths: [:])).inspect().first { $0.id == "libhac" }
        XCTAssertEqual(missing?.requirement, .required)
        XCTAssertEqual(missing?.state, .missing)
        XCTAssertTrue(missing?.blocksCompilation ?? false)
        XCTAssertTrue(copyCommands(in: missing?.actions ?? []).isEmpty)
        XCTAssertTrue(missing?.actions.contains { action in
            if case .openDocumentation(let url) = action.kind { return url == DependencyGuide.libHacDocumentation }
            return false
        } ?? false)

        let package = try makeTemporaryDirectory().appendingPathComponent("libhac.0.19.0.nupkg")
        try writeFile(package, contents: "nupkg")
        defer { try? FileManager.default.removeItem(at: package.deletingLastPathComponent()) }
        let present = EnvironmentProbe(
            locator: MapLocator(paths: [:]),
            source: .supplied(DependencyMeasurement(libHacPath: package.path))
        ).inspect().first { $0.id == "libhac" }
        XCTAssertEqual(present?.state, .available(path: package.path))
        XCTAssertFalse(present?.blocksCompilation ?? true)
    }

    func testProcessPathKeepsTheSelectedToolWithoutChangingOtherEntries() throws {
        let environment = BuildPlanner.pathPrependingToolDirectories(
            ["PATH": "/usr/bin:/bin"],
            tools: ["zstd": "/custom/bin/zstd", "dotnet": "/sdk/dotnet"]
        )
        let path = try XCTUnwrap(environment["PATH"])
        XCTAssertTrue(path.hasSuffix("/usr/bin:/bin"))
        XCTAssertTrue(path.contains("/custom/bin:"))
        XCTAssertTrue(path.contains("/sdk:"))
        XCTAssertFalse(path.contains("/opt/homebrew/bin"))
    }

    private func writeExecutable(_ url: URL, contents: String = "#!/bin/sh\nexit 0\n") throws {
        try writeFile(url, contents: contents)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}

private struct MapLocator: ExecutableLocating {
    var paths: [String: String]
    func path(for executable: String) -> String? { paths[executable] }
}
