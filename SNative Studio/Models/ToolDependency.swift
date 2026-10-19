import Foundation

struct ToolDependency: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let purpose: String
    let executable: String
    let state: State

    enum State: Equatable, Sendable {
        case available(path: String)
        case missing
    }

    var isAvailable: Bool {
        if case .available = state { return true }
        return false
    }

    var statusTitle: String {
        switch state {
        case .available: "Disponible"
        case .missing: "No encontrado"
        }
    }

    var location: String {
        switch state {
        case .available(let path): path
        case .missing: "No está en las rutas habituales"
        }
    }
}
