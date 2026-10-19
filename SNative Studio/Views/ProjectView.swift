import SwiftUI

struct ProjectView: View {
    @Bindable var project: ProjectViewModel
    var changesLocked = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "Proyecto",
                    subtitle: "Selecciona las rutas. El juego base y la actualización tienen que estar en la misma carpeta: el script oficial recibe esa carpeta, no los archivos por separado."
                )

                StudioCard(title: "Identidad") {
                    TextField("Nombre", text: nameBinding)
                        .textFieldStyle(.roundedBorder)
                        .disabled(changesLocked)
                    if changesLocked {
                        Text("La compilación está en curso. Las rutas no se pueden cambiar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if project.draft.isTracked {
                        Text("Este proyecto está en la lista de recientes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Pulsa Crear proyecto en Inicio para guardarlo entre ejecuciones.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                pathCard(
                    title: "NSP del juego base",
                    path: project.draft.baseNSP,
                    kind: .nsp,
                    choose: {
                        if let path = FileDialog.chooseFile(title: "NSP del juego base", extension: "nsp") {
                            project.setBaseNSP(path)
                        }
                    },
                    clear: project.clearBaseNSP
                )
                pathCard(
                    title: "NSP de actualización",
                    path: project.draft.updateNSP,
                    kind: .nsp,
                    choose: {
                        if let path = FileDialog.chooseFile(title: "NSP de actualización", extension: "nsp") {
                            project.setUpdateNSP(path)
                        }
                    },
                    clear: project.clearUpdateNSP
                )
                pathCard(
                    title: "prod.keys",
                    path: project.draft.prodKeys,
                    kind: .prodKeys,
                    choose: {
                        if let path = FileDialog.chooseFile(title: "prod.keys", extension: "keys") {
                            project.setProdKeys(path)
                        }
                    },
                    clear: project.clearProdKeys
                )
                pathCard(
                    title: "Carpeta de salida",
                    path: project.draft.outputDirectory,
                    kind: .directory,
                    choose: {
                        if let path = FileDialog.chooseDirectory(title: "Carpeta de salida") {
                            project.setOutputDirectory(path)
                        }
                    },
                    clear: project.clearOutputDirectory
                )

                StudioCard(title: "Validación") {
                    Text(project.validation.summary)
                        .font(.callout)
                    ForEach(project.validation.fields) { field in
                        HStack {
                            Image(systemName: field.verdict.isValid ? "checkmark.circle" : "circle")
                                .foregroundStyle(field.verdict.isValid ? Color.green : Color.secondary)
                            Text(field.title)
                            Spacer()
                            Text(field.verdict.message)
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
            }
            .padding(28)
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { project.draft.name },
            set: { project.updateName($0) }
        )
    }

    private func pathCard(title: String, path: String, kind: PathKind, choose: @escaping () -> Void, clear: @escaping () -> Void) -> some View {
        let verdict = PathValidation.verdict(path: path, kind: kind, facts: PathValidation.facts(for: path))
        return StudioCard(title: title) {
            HStack(alignment: .firstTextBaseline) {
                Text(path.isEmpty ? "Ningún elemento seleccionado" : path)
                    .font(.callout)
                    .foregroundStyle(path.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: 12)
                StatusBadge(title: verdict.message, isPositive: verdict.isValid)
            }
            HStack {
                Button("Seleccionar…", action: choose)
                    .disabled(changesLocked)
                if !path.isEmpty {
                    Button("Quitar", role: .destructive, action: clear)
                        .disabled(changesLocked)
                }
            }
        }
    }
}
