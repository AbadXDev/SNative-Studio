import Foundation
import Observation

@MainActor
@Observable
final class ToolsViewModel {
    private let probe: EnvironmentProbe
    private(set) var tools: [ToolDependency] = []

    init(probe: EnvironmentProbe = .live) {
        self.probe = probe
        refresh()
    }

    var availableCount: Int { tools.filter(\.isAvailable).count }

    var summary: String {
        guard !tools.isEmpty else { return "Sin comprobación" }
        return "\(availableCount) de \(tools.count) herramientas encontradas"
    }

    func refresh() {
        tools = probe.inspect()
    }
}
