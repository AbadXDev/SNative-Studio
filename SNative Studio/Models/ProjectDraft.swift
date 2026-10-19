import Foundation

struct ProjectDraft: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var baseNSP: String
    var updateNSP: String
    var prodKeys: String
    var outputDirectory: String
    var ipaName: String = ""
    var isTracked: Bool

    static func blank() -> ProjectDraft {
        let now = Date()
        return ProjectDraft(
            id: UUID(),
            name: "Proyecto nuevo",
            createdAt: now,
            updatedAt: now,
            baseNSP: "",
            updateNSP: "",
            prodKeys: "",
            outputDirectory: "",
            isTracked: false
        )
    }

    func renamed(_ name: String) -> ProjectDraft {
        var copy = self
        copy.name = name
        copy.updatedAt = Date()
        return copy
    }

    static func decodeList(from data: Data) -> [ProjectDraft]? {
        if let items = try? JSONDecoder().decode([ProjectDraft].self, from: data) {
            return items
        }
        guard var rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        for index in rows.indices where rows[index]["ipaName"] == nil {
            rows[index]["ipaName"] = ""
        }
        guard let fixed = try? JSONSerialization.data(withJSONObject: rows),
              let items = try? JSONDecoder().decode([ProjectDraft].self, from: fixed) else { return nil }
        return items
    }
}
