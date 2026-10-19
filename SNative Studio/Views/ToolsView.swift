import SwiftUI

struct ToolsView: View {
    @Bindable var model: ToolsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "Herramientas",
                    subtitle: "Estado de los ejecutables habituales. La compilación vuelve a comprobarlos, junto con los módulos de Python, y no instala nada."
                )

                HStack {
                    Text(model.summary)
                        .font(.headline)
                    Spacer()
                    Button("Volver a comprobar") {
                        model.refresh()
                    }
                }

                VStack(spacing: 10) {
                    ForEach(model.tools) { tool in
                        StudioCard(title: tool.name) {
                            Text(tool.purpose)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            HStack {
                                StatusBadge(title: tool.statusTitle, isPositive: tool.isAvailable)
                                Text(tool.location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}
