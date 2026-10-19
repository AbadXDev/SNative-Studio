import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case project
    case build
    case tools
    case settings
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Inicio"
        case .project: "Proyectos"
        case .build: "Compilación"
        case .tools: "Herramientas"
        case .settings: "Ajustes"
        case .about: "Acerca de"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .project: "square.and.pencil"
        case .build: "hammer"
        case .tools: "wrench.and.screwdriver"
        case .settings: "gearshape"
        case .about: "info.circle"
        }
    }
}
