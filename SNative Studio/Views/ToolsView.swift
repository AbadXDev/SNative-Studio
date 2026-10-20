import AppKit
import SwiftUI

struct ToolsView: View {
    @Bindable var model: ToolsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "Herramientas",
                    subtitle: "Estado del motor y de las herramientas. Generar una IPA necesita los requisitos obligatorios, entre ellos Xcode, el SDK de iOS y Metal. Esta pantalla no instala nada."
                )

                HStack {
                    Text(model.summary)
                        .font(.headline)
                    Spacer()
                    if model.isChecking {
                        Text("Comprobando…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Button("Volver a comprobar") {
                        model.refresh()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.blockingSummary)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.optionalSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    ForEach(model.tools) { tool in
                        StudioCard(title: tool.name) {
                            Text(tool.purpose)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                StatusBadge(title: tool.statusTitle, isPositive: tool.isAvailable)
                                Text(tool.requirementTitle)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                if tool.installationPending {
                                    Text("Instalación pendiente")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let version = tool.version {
                                Text("Versión: \(version)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Text(tool.location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            if let note = tool.note {
                                Text(note)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ForEach(tool.actions) { action in
                                actionView(action)
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
    }

    @ViewBuilder
    private func actionView(_ action: DependencyAction) -> some View {
        switch action.kind {
        case .manual(let text):
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .copyCommand(let command):
            VStack(alignment: .leading, spacing: 8) {
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Button("Copiar comando") {
                    copy(command)
                }
            }
        case .openDocumentation(let url):
            Button("Abrir documentación oficial") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func copy(_ command: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
    }
}
