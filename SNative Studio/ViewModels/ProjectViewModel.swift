import Foundation
import Observation

@MainActor
@Observable
final class ProjectViewModel {
    private(set) var draft: ProjectDraft
    var onChange: ((ProjectDraft) -> Void)?

    init(draft: ProjectDraft = .blank()) {
        self.draft = draft
    }

    var validation: ProjectValidation {
        ProjectValidation.evaluate(draft)
    }

    func replace(_ draft: ProjectDraft) {
        self.draft = draft
    }

    func startNew() -> ProjectDraft {
        var created = ProjectDraft.blank()
        created.isTracked = true
        draft = created
        onChange?(draft)
        return draft
    }

    func updateName(_ name: String) {
        draft.name = name.isEmpty ? "Proyecto nuevo" : name
        draft.updatedAt = Date()
        publish()
    }

    func setBaseNSP(_ path: String) { assign(\.baseNSP, path) }
    func setUpdateNSP(_ path: String) { assign(\.updateNSP, path) }
    func setProdKeys(_ path: String) { assign(\.prodKeys, path) }
    func setOutputDirectory(_ path: String) { assign(\.outputDirectory, path) }

    func clearBaseNSP() { assign(\.baseNSP, "") }
    func clearUpdateNSP() { assign(\.updateNSP, "") }
    func clearProdKeys() { assign(\.prodKeys, "") }
    func clearOutputDirectory() { assign(\.outputDirectory, "") }

    private func assign(_ keyPath: WritableKeyPath<ProjectDraft, String>, _ value: String) {
        draft[keyPath: keyPath] = value
        draft.updatedAt = Date()
        publish()
    }

    private func publish() {
        guard draft.isTracked else { return }
        onChange?(draft)
    }
}
