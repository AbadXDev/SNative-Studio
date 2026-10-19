import Foundation

struct ProjectLibrary: Sendable {
    var fileURL: URL
    var legacyProjects: @Sendable () -> [ProjectDraft]

    static func live() -> ProjectLibrary {
        ProjectLibrary(fileURL: defaultFileURL(), legacyProjects: { RecentProjectsStore().load() })
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("com.abadx.SNativeStudio", isDirectory: true).appendingPathComponent("projects.json")
    }

    func load() -> [ProjectDraft] {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let stored = ProjectDraft.decodeList(from: data) {
            return stored.sorted { $0.updatedAt > $1.updatedAt }
        }
        return legacyProjects().sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ projects: [ProjectDraft]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(projects)
        try data.write(to: fileURL, options: .atomic)
    }
}

enum ProjectEditing {
    static func duplicate(_ project: ProjectDraft, now: Date = Date()) -> ProjectDraft {
        var copy = project
        copy.id = UUID()
        copy.name = "Copia de \(project.name)"
        copy.createdAt = now
        copy.updatedAt = now
        copy.isTracked = true
        return copy
    }

    static func preparedForSave(_ draft: ProjectDraft, existing: ProjectDraft?, now: Date = Date()) -> ProjectDraft {
        var stored = draft
        stored.name = stored.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if stored.name.isEmpty { stored.name = "Proyecto nuevo" }
        stored.createdAt = existing?.createdAt ?? now
        stored.updatedAt = now
        stored.isTracked = true
        return stored
    }
}
