import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var layoutWidth: CGFloat = 0

    private var version: String {
        let bundled = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        if let bundled, !bundled.isEmpty {
            return bundled
        }
        return AppIdentity.version
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                columns
                author
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: AboutWidthKey.self, value: proxy.size.width)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onPreferenceChange(AboutWidthKey.self) { layoutWidth = $0 }
    }

    /// Dos columnas equilibradas cuando caben. El primer pase, antes de medir, usa dos columnas.
    private var usesTwoColumns: Bool {
        layoutWidth == 0 || layoutWidth >= 720
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            applicationIcon
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppIdentity.name)
                    .font(.title.weight(.bold))
                Text("Versión \(version)")
                    .font(.body.weight(.medium))
                Text(AppIdentity.signature)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Herramienta de escritorio para generar IPA de forma local mediante nxnative.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(colors: headerColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                AboutWaves()
                    .fill(waveColor)
                    .frame(maxWidth: 420, maxHeight: 120)
                    .padding(.trailing, 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accent.opacity(colorScheme == .dark ? 0.28 : 0.16))
        }
    }

    private var columns: some View {
        Group {
            if usesTwoColumns {
                HStack(alignment: .top, spacing: 16) {
                    leftColumn.frame(maxWidth: .infinity, alignment: .topLeading)
                    rightColumn.frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    leftColumn
                    rightColumn
                }
            }
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            AboutCard(symbol: "doc.text", title: "Descripción", accent: accent) {
                Text("SNative Studio es una interfaz gráfica para facilitar el uso del script oficial de nxnative. Permite generar una IPA de forma local en macOS sin necesidad de firmar, instalar ni mostrar el contenido de prod.keys.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            AboutCard(symbol: "chevron.left.forwardslash.chevron.right", title: "Proyecto", accent: accent) {
                VStack(spacing: 0) {
                    ForEach(Array(projectRows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            Divider().padding(.leading, 44)
                        }
                        ProjectRow(row: row, accent: accent)
                    }
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            AboutCard(symbol: "sparkles", title: "Esta versión", accent: accent) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(features, id: \.self) { feature in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.green)
                            Text(feature)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            AboutCard(symbol: "info.circle", title: "Tecnologías", accent: accent) {
                VStack(spacing: 12) {
                    ForEach(technologies) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(item.tint)
                                .frame(width: 28, height: 28)
                                .background(item.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text(item.name)
                                .font(.callout.weight(.semibold))
                            Spacer(minLength: 12)
                            Text(item.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var author: some View {
        AboutCard(symbol: "person.2", title: "Autor", accent: accent) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 18) {
                    authorIdentity
                    Divider().frame(height: 42)
                    authorNote
                }
                VStack(alignment: .leading, spacing: 12) {
                    authorIdentity
                    authorNote
                }
            }
        }
    }

    private var authorIdentity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AbadX")
                .font(.body.weight(.semibold))
            Text("Desarrollador independiente.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 160, alignment: .leading)
    }

    private var authorNote: some View {
        Text("Este proyecto se comparte como software libre con fines educativos y de desarrollo. No está afiliado con Nintendo ni con los desarrolladores de nxnative.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var applicationIcon: Image {
        Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
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

    private var waveColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.62)
    }

    private var features: [String] {
        [
            "Genera una IPA con el script oficial de nxnative.",
            "No muestra el contenido de prod.keys.",
            "No firma, no instala y no descarga juegos ni herramientas.",
            "Funciona de forma local en tu equipo."
        ]
    }

    /// macOS 14 y Swift 6 salen de los ajustes del proyecto. No hay una versión mínima de Xcode declarada.
    private var technologies: [Technology] {
        [
            Technology(name: "macOS", symbol: "apple.logo", tint: .primary, detail: "Compilado para macOS 14 o posterior"),
            Technology(name: "Swift", symbol: "swift", tint: .orange, detail: "Desarrollado con Swift 6"),
            Technology(name: "Xcode", symbol: "hammer.fill", tint: accent, detail: "Proyecto nativo de Xcode"),
            Technology(name: "nxnative", symbol: "terminal.fill", tint: .secondary, detail: "Utiliza el script oficial de nxnative")
        ]
    }

    /// No hay repositorio, documentación ni licencia propios de SNative Studio en el proyecto.
    private var projectRows: [ProjectDestination] {
        [
            ProjectDestination(id: "repository", symbol: "person.crop.circle", title: "Repositorio en GitHub", subtitle: "Ver el código fuente de SNative Studio.", destination: nil),
            ProjectDestination(id: "docs", symbol: "book", title: "Documentación", subtitle: "Guías y más información.", destination: nil),
            ProjectDestination(id: "license", symbol: "doc.text", title: "Licencia", subtitle: "Información sobre la licencia de uso.", destination: nil)
        ]
    }
}

private struct ProjectDestination: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let subtitle: String
    let destination: URL?
}

private struct Technology: Identifiable {
    var id: String { name }
    let name: String
    let symbol: String
    let tint: Color
    let detail: String
}

private struct AboutCard<Content: View>: View {
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

private struct ProjectRow: View {
    let row: ProjectDestination
    let accent: Color

    var body: some View {
        Group {
            if let destination = row.destination {
                Link(destination: destination) {
                    label(showsChevron: true, status: nil)
                }
                .buttonStyle(.plain)
            } else {
                label(showsChevron: false, status: "Pendiente")
            }
        }
        .padding(.vertical, 8)
    }

    private func label(showsChevron: Bool, status: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.symbol)
                .font(.body)
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(row.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct AboutWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AboutWaves: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.15),
            control2: CGPoint(x: rect.width * 0.32, y: rect.height * 0.95)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.22),
            control1: CGPoint(x: rect.width * 0.68, y: rect.height * 0.05),
            control2: CGPoint(x: rect.width * 0.82, y: rect.height * 0.55)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
