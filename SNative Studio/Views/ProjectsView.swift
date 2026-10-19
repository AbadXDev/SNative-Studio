import SwiftUI

struct ProjectsView: View {
    @Bindable var studio: StudioViewModel

    var body: some View {
        HSplitView {
            list
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .confirmationDialog(
            "¿Eliminar este proyecto de la lista?",
            isPresented: deletionPresented,
            titleVisibility: .visible,
            presenting: studio.projectPendingDeletion
        ) { project in
            Button("Eliminar de la lista", role: .destructive) {
                studio.confirmDeletion()
            }
            Button("Cancelar", role: .cancel) {
                studio.cancelDeletion()
            }
        } message: { project in
            Text("Se quitará «\(project.name)» de SNative Studio. No se borrarán los NSP, prod.keys, la IPA, la caché ni ningún otro archivo.")
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Proyectos")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Crear proyecto") {
                    studio.presentCreate()
                }
                .disabled(studio.build.isRunning)
            }
            if studio.projects.isEmpty {
                Text("Todavía no hay proyectos guardados.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                List(selection: $studio.selectedProjectID) {
                    ForEach(studio.projects) { project in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                            Text(project.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(Optional(project.id))
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
                .frame(maxHeight: .infinity)
            }
            if let statusMessage = studio.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var detail: some View {
        if let project = studio.selectedProject {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(
                        title: project.name,
                        subtitle: "Creado el \(project.createdAt.formatted(date: .abbreviated, time: .shortened)). Última modificación el \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))."
                    )
                    actionRow(project)
                    StudioCard(title: "Rutas") {
                        let validation = ProjectValidation.evaluate(project)
                        Text(validation.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        ForEach(validation.fields) { field in
                            pathRow(field)
                        }
                        labeled("Nombre de la IPA", project.ipaName.isEmpty ? "El del perfil del juego, si se reconoce" : project.ipaName)
                        labeled("Caché", CacheStatus.detect(draft: project).message)
                    }
                }
                .padding(28)
            }
        } else {
            ContentUnavailableView(
                "Ningún proyecto abierto",
                systemImage: "square.stack",
                description: Text("Crea un proyecto o selecciona uno de la lista para ver sus detalles.")
            )
        }
    }

    private func actionRow(_ project: ProjectDraft) -> some View {
        HStack {
            Button("Editar") { studio.presentEdit(project) }
                .disabled(studio.build.isRunning)
            Button("Duplicar") { studio.duplicate(project) }
                .disabled(studio.build.isRunning)
            Button("Abrir carpeta") { studio.openFolder(project) }
            Button("Eliminar", role: .destructive) { studio.askToDelete(project) }
                .disabled(studio.build.isRunning)
        }
    }

    private func pathRow(_ field: ProjectFieldCheck) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(field.title)
                Spacer()
                Text(field.statusText)
                    .foregroundStyle(.secondary)
            }
            Text(field.path.isEmpty ? "Sin ruta" : field.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .font(.callout)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .font(.callout)
    }

    private var deletionPresented: Binding<Bool> {
        Binding(
            get: { studio.projectPendingDeletion != nil },
            set: { isPresented in
                if !isPresented { studio.cancelDeletion() }
            }
        )
    }
}
