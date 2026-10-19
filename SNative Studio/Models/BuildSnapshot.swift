import Foundation

struct BuildPhase: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var summary: String
    var state: State

    enum State: String, Equatable, Sendable {
        case pending
        case running
        case completed
        case failed

        var title: String {
            switch self {
            case .pending: "Pendiente"
            case .running: "Ejecutando"
            case .completed: "Completado"
            case .failed: "Fallido"
            }
        }
    }
}

struct BuildSnapshot: Equatable, Sendable {
    var phases: [BuildPhase]
    var progress: Double?
    var log: String
    var status: Status = .idle
    var message: String = "Sin compilación en curso"
    var ipaPath: String?
    var announcedIPA: String?
    var startedAt: Date?
    var finishedAt: Date?

    enum Status: String, Equatable, Sendable {
        case idle
        case running
        case succeeded
        case failed
        case cancelled

        var title: String {
            switch self {
            case .idle: "Sin compilación"
            case .running: "Ejecutando"
            case .succeeded: "Completado"
            case .failed: "Fallido"
            case .cancelled: "Cancelada"
            }
        }
    }

    func elapsed(at date: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return max(0, (finishedAt ?? date).timeIntervalSince(startedAt))
    }

    static let idle = BuildSnapshot(
        phases: [
            BuildPhase(id: "identify", title: "Identificación", summary: "Reconocer el juego y la versión.", state: .pending),
            BuildPhase(id: "extract", title: "Extracción", summary: "Preparar los archivos del juego.", state: .pending),
            BuildPhase(id: "rewrite", title: "Reescritura", summary: "Preparar los módulos de código.", state: .pending),
            BuildPhase(id: "shaders", title: "Sombreadores", summary: "Preparar las bibliotecas gráficas.", state: .pending),
            BuildPhase(id: "package", title: "Empaquetado", summary: "Preparar la IPA.", state: .pending)
        ],
        progress: nil,
        log: ""
    )

    var hasStarted: Bool { progress != nil || phases.contains { $0.state != .pending } || !log.isEmpty }
}
