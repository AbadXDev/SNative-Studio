import AppKit
import Foundation
import Observation

struct ProjectEditorRequest: Identifiable, Equatable {
    var id: UUID { draft.id }
    var draft: ProjectDraft
    var isNew: Bool
}

@MainActor
@Observable
final class StudioViewModel {
    var section: AppSection = .home
    let settings: SettingsViewModel
    let build: BuildViewModel
    let tools: ToolsViewModel
    let library: ProjectLibrary
    private(set) var projects: [ProjectDraft] = []
    var selectedProjectID: UUID?
    var buildProjectID: UUID?
    var editor: ProjectEditorRequest?
    var projectPendingDeletion: ProjectDraft?
    var statusMessage: String?

    init(
        settings: SettingsViewModel,
        build: BuildViewModel,
        tools: ToolsViewModel,
        library: ProjectLibrary
    ) {
        self.settings = settings
        self.build = build
        self.tools = tools
        self.library = library
        self.projects = library.load()
    }

    convenience init() {
        let tools = ToolsViewModel()
        let build = BuildViewModel()
        self.init(
            settings: SettingsViewModel(),
            build: build,
            tools: tools,
            library: .live()
        )
        build.environmentGate = { tools.compilationBlock }
    }

    var selectedProject: ProjectDraft? {
        projects.first { $0.id == selectedProjectID }
    }

    var buildProject: ProjectDraft? {
        projects.first { $0.id == buildProjectID }
    }

    func presentCreate() {
        var draft = ProjectDraft.blank()
        draft.isTracked = true
        editor = ProjectEditorRequest(draft: draft, isNew: true)
    }

    func presentEdit(_ project: ProjectDraft) {
        guard !build.isRunning else { return }
        editor = ProjectEditorRequest(draft: project, isNew: false)
    }

    func cancelEditor() {
        editor = nil
    }

    func saveEditor(_ draft: ProjectDraft) {
        guard !build.isRunning else { return }
        let existing = projects.first { $0.id == draft.id }
        let stored = ProjectEditing.preparedForSave(draft, existing: existing)
        if let index = projects.firstIndex(where: { $0.id == stored.id }) {
            projects[index] = stored
        } else {
            projects.insert(stored, at: 0)
        }
        projects.sort { $0.updatedAt > $1.updatedAt }
        selectedProjectID = stored.id
        editor = nil
        persist()
    }

    func duplicate(_ project: ProjectDraft) {
        guard !build.isRunning else { return }
        let copy = ProjectEditing.duplicate(project)
        projects.insert(copy, at: 0)
        selectedProjectID = copy.id
        persist()
    }

    func askToDelete(_ project: ProjectDraft) {
        guard !build.isRunning else { return }
        projectPendingDeletion = project
    }

    func cancelDeletion() {
        projectPendingDeletion = nil
    }

    func confirmDeletion() {
        guard let project = projectPendingDeletion, !build.isRunning else { return }
        projects.removeAll { $0.id == project.id }
        if selectedProjectID == project.id { selectedProjectID = nil }
        if buildProjectID == project.id { buildProjectID = nil }
        projectPendingDeletion = nil
        persist()
    }

    func openFolder(_ project: ProjectDraft) {
        let candidates = [
            project.outputDirectory,
            project.baseNSP.isEmpty ? "" : URL(fileURLWithPath: project.baseNSP).deletingLastPathComponent().path
        ]
        for path in candidates where !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
                statusMessage = nil
                return
            }
        }
        statusMessage = "No hay una carpeta existente para abrir. No se ha creado ni borrado nada."
    }

    private func persist() {
        do {
            try library.save(projects)
            statusMessage = nil
        } catch {
            statusMessage = "No se pudo guardar la lista de proyectos."
        }
    }
}
