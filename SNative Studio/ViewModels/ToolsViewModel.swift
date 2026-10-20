import Foundation
import Observation

@MainActor
@Observable
final class ToolsViewModel {
    private let probe: EnvironmentProbe
    private var generation = 0
    private(set) var tools: [ToolDependency] = []
    private(set) var isChecking = false

    init(probe: EnvironmentProbe = .live) {
        self.probe = probe
        refresh()
    }

    var availableCount: Int { tools.filter(\.isAvailable).count }

    var summary: String {
        if isChecking, tools.isEmpty { return "Comprobando…" }
        guard !tools.isEmpty else { return "Sin comprobación" }
        return "\(availableCount) de \(tools.count) requisitos encontrados"
    }

    var blockingSummary: String {
        let names = tools.filter(\.blocksCompilation).map(\.name)
        if names.isEmpty {
            return "Ningún requisito obligatorio figura como pendiente. Generar una IPA sigue usando Xcode, el SDK de iOS y Metal en este Mac."
        }
        return "Impiden generar una IPA: \(names.joined(separator: ", "))."
    }

    var optionalSummary: String {
        "Swift y Homebrew son opcionales. Su ausencia no impide generar una IPA."
    }

    var compilationBlock: String? {
        Self.compilationBlock(isChecking: isChecking, tools: tools)
    }

    static func compilationBlock(isChecking: Bool, tools: [ToolDependency]) -> String? {
        if isChecking {
            return "La comprobación del entorno todavía no ha terminado. SNative Studio no inicia la compilación."
        }
        let names = tools.filter(\.blocksCompilation).map(\.name)
        guard !names.isEmpty else { return nil }
        return "Impiden generar una IPA: \(names.joined(separator: ", ")). SNative Studio no las instala. En Herramientas están el estado y las instrucciones."
    }

    func refresh() {
        if probe.checksExternally {
            generation += 1
            let generation = generation
            let probe = probe
            isChecking = true
            Task.detached {
                let tools = probe.inspect()
                await MainActor.run {
                    guard generation == self.generation else { return }
                    self.tools = tools
                    self.isChecking = false
                }
            }
        } else {
            isChecking = false
            tools = probe.inspect()
        }
    }
}
