import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case light
    case dark
    case automatic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Claro"
        case .dark: "Oscuro"
        case .automatic: "Automático"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .automatic: nil
        }
    }

    static let fallback: AppearancePreference = .light
}
