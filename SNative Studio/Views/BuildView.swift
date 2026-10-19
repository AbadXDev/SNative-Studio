import SwiftUI

struct BuildView: View {
    @Bindable var model: BuildViewModel
    @Bindable var studio: StudioViewModel
    @State private var copied = false

    private var selected: ProjectDraft? { studio.buildProject }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "Compilación",
                    subtitle: "Elige un proyecto guardado y ejecuta el script oficial. La IPA queda sin firmar y no se instala."
                )

                StudioCard(title: "Proyecto") {
                    Picker("Proyecto", selection: $studio.buildProjectID) {
                        Text("Selecciona un proyecto").tag(UUID?.none)
                        ForEach(studio.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(model.isRunning)
                    if let selected {
                        projectSummary(selected)
                    } else {
                        Text("No hay un proyecto seleccionado. Puedes crearlo en Proyectos.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                StudioCard(title: "Generar IPA") {
                    Text(model.snapshot.message)
                        .font(.title3.weight(.medium))
                    Text(model.readiness)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text("Tiempo: \(ElapsedTime.text(model.elapsed(at: timeline.date)))")
                            .font(.callout.monospacedDigit())
                    }
                    progressLine
                    if let path = model.snapshot.ipaPath {
                        Text(path)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    if model.compiledProjectID != nil, model.compiledProjectID != selected?.id, !model.snapshot.log.isEmpty {
                        Text("Estos registros pertenecen a la última compilación, no necesariamente al proyecto seleccionado.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Generar IPA") {
                            guard let selected else { return }
                            Task { await model.generate(draft: selected) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selected == nil || model.isRunning || model.isEvaluating)
                        Button("Editar proyecto") {
                            if let selected { studio.presentEdit(selected) }
                        }
                        .disabled(selected == nil || model.isRunning)
                        Button("Cancelar", role: .destructive) {
                            model.cancel()
                        }
                        .disabled(!model.isRunning)
                    }
                }

                StudioCard(title: "Fases") {
                    if model.snapshot.status == .idle {
                        Text("El motor anunciará aquí sus fases. Todavía no hay una compilación.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else if model.snapshot.phases.isEmpty {
                        Text("Esperando la primera fase del motor.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.snapshot.phases) { phase in
                                phaseRow(phase)
                            }
                        }
                    }
                }

                StudioCard(title: "Registros") {
                    HStack {
                        Button("Copiar registros") {
                            Clipboard.copy(model.snapshot.log)
                            copied = true
                        }
                        .disabled(model.snapshot.log.isEmpty)
                        if copied {
                            Text("Copiados")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ScrollView {
                        Text(model.snapshot.log.isEmpty ? "Los registros del script aparecerán aquí." : model.snapshot.log)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(model.snapshot.log.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(minHeight: 180, maxHeight: 320)
                    .padding(12)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(28)
        }
        .task(id: selected) {
            guard let selected else { return }
            await model.refresh(draft: selected)
        }
        .onChange(of: selected) { _, _ in
            model.dismissOverwrite()
        }
        .confirmationDialog(
            "Ya existe una IPA en la ruta de salida.",
            isPresented: overwritePresented,
            titleVisibility: .visible,
            presenting: model.overwritePath
        ) { _ in
            Button("Sobrescribir", role: .destructive) {
                model.confirmOverwrite()
            }
            Button("Cancelar", role: .cancel) {
                model.dismissOverwrite()
            }
        } message: { path in
            Text("Si continúas, el script oficial volverá a escribir \(path). Todavía no se ha iniciado la compilación.")
        }
    }

    private func projectSummary(_ project: ProjectDraft) -> some View {
        let validation = ProjectValidation.evaluate(project)
        let ipaName = project.ipaName.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 8) {
            Text(validation.summary)
                .font(.callout)
            summaryLine("NSP base", project.baseNSP)
            summaryLine("Actualización", project.updateNSP.isEmpty ? "Opcional, sin seleccionar" : project.updateNSP)
            summaryLine("prod.keys", project.prodKeys.isEmpty ? "Sin seleccionar" : project.prodKeys)
            summaryLine("Carpeta de salida", project.outputDirectory.isEmpty ? "Sin seleccionar" : project.outputDirectory)
            summaryLine("Nombre de la IPA", ipaName.isEmpty ? "El del perfil del juego, si se reconoce" : ipaName)
            Text(CacheStatus.detect(draft: project).message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if !validation.isComplete {
                Text("Corrige el proyecto antes de compilar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryLine(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(value)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var progressLine: some View {
        if let progress = model.snapshot.progress {
            Text("\(Int((progress * 100).rounded())) %")
                .font(.callout.monospacedDigit())
        } else {
            Text("Sin porcentaje fiable")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func phaseRow(_ phase: BuildPhase) -> some View {
        HStack(alignment: .top, spacing: 10) {
            phaseIcon(phase.state)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.title)
                    .font(.body.weight(.medium))
                Text(phase.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Text(phase.state.title)
                .font(.caption)
                .foregroundStyle(phaseTint(phase.state))
        }
    }

    @ViewBuilder
    private func phaseIcon(_ state: BuildPhase.State) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func phaseTint(_ state: BuildPhase.State) -> Color {
        switch state {
        case .pending: .secondary
        case .running: Color("StudioAccent")
        case .completed: .green
        case .failed: .red
        }
    }

    private var overwritePresented: Binding<Bool> {
        Binding(
            get: { model.overwritePath != nil },
            set: { isPresented in
                if !isPresented { model.dismissOverwrite() }
            }
        )
    }
}

enum ElapsedTime {
    static func text(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
