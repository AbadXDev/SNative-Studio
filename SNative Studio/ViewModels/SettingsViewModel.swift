import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let store: PreferencesStore
    var appearance: AppearancePreference {
        didSet { store.saveAppearance(appearance) }
    }

    init(store: PreferencesStore = PreferencesStore()) {
        self.store = store
        self.appearance = store.loadAppearance()
    }
}
