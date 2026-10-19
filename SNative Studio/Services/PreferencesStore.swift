import Foundation

struct PreferencesStore {
    private let defaults: UserDefaults
    private let key = "snative.appearance"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAppearance() -> AppearancePreference {
        guard let raw = defaults.string(forKey: key),
              let value = AppearancePreference(rawValue: raw) else {
            return .fallback
        }
        return value
    }

    func saveAppearance(_ value: AppearancePreference) {
        defaults.set(value.rawValue, forKey: key)
    }
}
