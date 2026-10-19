import SwiftUI

struct ProjectEditorSheet: View {
    let initial: ProjectDraft
    let isNew: Bool
    let onCancel: () -> Void
    let onSave: (ProjectDraft) -> Void

    @State private var draft: ProjectDraft
    @State private var profileIPA: String?

    init(initial: ProjectDraft, isNew: Bool, onCancel: @escaping () -> Void, onSave: @escaping (ProjectDraft) -> Void) {
        self.initial = initial
        self.isNew = isNew
        self.onCancel = onCancel
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "Crear proyecto" : "Editar proyecto")
                .font(.title2.weight(.semibold))
            Text("Puedes guardar el proyecto aunque falten rutas. La compilación las comprobará antes de empezar. El contenido de prod.keys no se guarda.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Form {
                TextField("Nombre", text: $draft.name)
                fileRow("NSP del juego base", path: draft.baseNSP, choose: chooseBase, clear: { draft.baseNSP = "" })
                fileRow("NSP de actualización (opcional)", path: draft.updateNSP, choose: {
                    if let path = FileDialog.chooseFile(title: "NSP de actualización", extension: "nsp") {
                        draft.updateNSP = path
                    }
                }, clear: { draft.updateNSP = "" })
                fileRow("prod.keys", path: draft.prodKeys, choose: {
                    if let path = FileDialog.chooseFile(title: "prod.keys", extension: "keys") {
                        draft.prodKeys = path
                    }
                }, clear: { draft.prodKeys = "" })
                fileRow("Carpeta de salida", path: draft.outputDirectory, choose: {
                    if let path = FileDialog.chooseDirectory(title: "Carpeta de salida") {
                        draft.outputDirectory = path
                    }
                }, clear: { draft.outputDirectory = "" })
                TextField("Nombre de la IPA", text: $draft.ipaName, prompt: Text(profileIPA ?? "Juego.ipa"))
                if let profileIPA {
                    Button("Usar el nombre del perfil (\(profileIPA))") {
                        draft.ipaName = profileIPA
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel, action: onCancel)
                Button("Guardar") {
                    onSave(draft)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 520)
        .onAppear(perform: refreshSuggestion)
    }

    private func chooseBase() {
        guard let path = FileDialog.chooseFile(title: "NSP del juego base", extension: "nsp") else { return }
        draft.baseNSP = path
        let suggestion = IPANameSuggestion.suggest(forBasePath: path)
        profileIPA = suggestion
        if draft.ipaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let suggestion {
            draft.ipaName = suggestion
        }
    }

    private func refreshSuggestion() {
        profileIPA = IPANameSuggestion.suggest(forBasePath: draft.baseNSP)
    }

    private func fileRow(_ title: String, path: String, choose: @escaping () -> Void, clear: @escaping () -> Void) -> some View {
        LabeledContent(title) {
            HStack {
                Text(path.isEmpty ? "Sin seleccionar" : path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(path.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Seleccionar…", action: choose)
                if !path.isEmpty {
                    Button("Quitar", role: .destructive, action: clear)
                }
            }
        }
    }
}

enum IPANameSuggestion {
    static func suggest(forBasePath path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let identifier = TitleIdentity.applicationID(in: URL(fileURLWithPath: trimmed).lastPathComponent),
              let root = EngineLocator.locate(startingAt: EngineLocator.defaultCandidates()) else { return nil }
        let profile = root.appendingPathComponent("dm/games/\(identifier)/game.tsv")
        guard let text = try? String(contentsOf: profile, encoding: .utf8) else { return nil }
        return ProfileIPA.fileName(in: text)
    }
}
