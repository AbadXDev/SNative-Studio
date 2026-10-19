import Foundation

struct RecentProjectsStore {
    static let limit = 10
    private let defaults: UserDefaults
    private let key = "snative.recentProjects"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [ProjectDraft] {
        guard let data = defaults.data(forKey: key),
              let items = ProjectDraft.decodeList(from: data) else {
            return []
        }
        return items
    }

    func save(_ items: [ProjectDraft]) {
        let trimmed = Array(items.prefix(Self.limit))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: key)
    }

    func upsert(_ draft: ProjectDraft) {
        var items = load().filter { $0.id != draft.id }
        items.insert(draft, at: 0)
        save(items)
    }

    func remove(id: UUID) {
        save(load().filter { $0.id != id })
    }
}
