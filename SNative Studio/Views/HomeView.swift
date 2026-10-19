import AppKit
import SwiftUI

struct HomeView: View {
    @Bindable var studio: StudioViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var layoutWidth: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                columns
                recentProjects
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: HomeWidthKey.self, value: proxy.size.width)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onPreferenceChange(HomeWidthKey.self) { layoutWidth = $0 }
    }

    private var usesTwoColumns: Bool {
        layoutWidth == 0 || layoutWidth >= 720
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(AppIdentity.name)
                    .font(.title2.weight(.bold))
                Text(AppIdentity.signature)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Compila tus proyectos para iPhone desde macOS.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(colors: headerColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.opacity(colorScheme == .dark ? 0.28 : 0.16))
        }
    }

    private var columns: some View {
        Group {
            if usesTwoColumns {
                HStack(alignment: .top, spacing: 16) {
                    startCard.frame(maxWidth: .infinity, alignment: .topLeading)
                    environmentCard.frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    startCard
                    environmentCard
                }
            }
        }
    }

    private var startCard: some View {
        HomeCard(symbol: "plus.square", title: "Empezar", accent: accent) {
            Text("Crea un proyecto para guardar las rutas del juego base, la actualización, las claves y la carpeta de salida. El contenido no se abre al guardarlas.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Crear proyecto") {
                studio.presentCreate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(studio.build.isRunning)
        }
    }

    private var environmentCard: some View {
        HomeCard(symbol: "wrench.and.screwdriver", title: "Entorno de compilación", accent: accent) {
            Text(studio.tools.summary)
                .font(.title3.weight(.semibold))
            Text("La comprobación solo busca ejecutables. No instala nada.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ver herramientas") {
                studio.section = .tools
            }
        }
    }

    private var recentProjects: some View {
        HomeCard(symbol: "clock", title: "Proyectos recientes", accent: accent) {
            if studio.projects.isEmpty {
                Text("Todavía no hay proyectos. El primero aparecerá aquí después de crearlo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(studio.projects) { draft in
                        Button {
                            studio.selectedProjectID = draft.id
                            studio.section = .project
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.pencil")
                                    .font(.body)
                                    .foregroundStyle(accent)
                                    .frame(width: 28, height: 28)
                                    .background(accent.opacity(0.10), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(draft.name)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Actualizado \(draft.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(studio.build.isRunning)
                        if draft.id != studio.projects.last?.id {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
            }
        }
    }

    private var accent: Color {
        colorScheme == .dark
            ? Color(red: 0.55, green: 0.75, blue: 1.0)
            : Color(red: 0.16, green: 0.43, blue: 0.95)
    }

    private var headerColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.10, green: 0.16, blue: 0.28),
                Color(red: 0.07, green: 0.11, blue: 0.20)
            ]
        }
        return [
            Color(red: 0.93, green: 0.96, blue: 1.0),
            Color(red: 0.84, green: 0.91, blue: 0.99)
        ]
    }
}

private struct HomeCard<Content: View>: View {
    let symbol: String
    let title: String
    let accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.12), in: Circle())
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }
}

private struct HomeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
