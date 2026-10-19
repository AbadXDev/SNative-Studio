import XCTest
@testable import SNativeStudio

final class PreferencesAndRecentsTests: XCTestCase {
    private func suite() -> UserDefaults {
        let name = "snative.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testAppearanceDefaultsToLight() {
        XCTAssertEqual(AppearancePreference.fallback, .light)
        XCTAssertEqual(PreferencesStore(defaults: suite()).loadAppearance(), .light)
        XCTAssertEqual(AppearancePreference.light.colorScheme, .light)
        XCTAssertEqual(AppearancePreference.dark.colorScheme, .dark)
        XCTAssertNil(AppearancePreference.automatic.colorScheme)
    }

    func testAppearancePersists() {
        let defaults = suite()
        let store = PreferencesStore(defaults: defaults)
        store.saveAppearance(.dark)
        XCTAssertEqual(PreferencesStore(defaults: defaults).loadAppearance(), .dark)
        store.saveAppearance(.automatic)
        XCTAssertEqual(store.loadAppearance(), .automatic)
    }

    func testRecentProjectsKeepNewestFirstAndCapTheList() {
        let store = RecentProjectsStore(defaults: suite())
        var first = ProjectDraft.blank()
        first.isTracked = true
        first.name = "Primero"
        store.upsert(first)
        var second = ProjectDraft.blank()
        second.isTracked = true
        second.name = "Segundo"
        store.upsert(second)
        XCTAssertEqual(store.load().map(\.name), ["Segundo", "Primero"])

        var updated = first
        updated.name = "Primero editado"
        store.upsert(updated)
        XCTAssertEqual(store.load().first?.name, "Primero editado")
        XCTAssertEqual(store.load().count, 2)

        for index in 0..<12 {
            var extra = ProjectDraft.blank()
            extra.name = "Extra \(index)"
            store.upsert(extra)
        }
        XCTAssertEqual(store.load().count, RecentProjectsStore.limit)
    }
}
