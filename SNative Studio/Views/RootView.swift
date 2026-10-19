import SwiftUI

struct RootView: View {
    @Bindable var studio: StudioViewModel

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $studio.section) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 196, ideal: 220, max: 260)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppIdentity.name)
                        .font(.caption.weight(.semibold))
                    Text("Versión \(AppIdentity.version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor))
                .navigationTitle(studio.section.title)
        }
        .tint(Color("StudioAccent"))
        .sheet(item: $studio.editor) { request in
            ProjectEditorSheet(initial: request.draft, isNew: request.isNew) {
                studio.cancelEditor()
            } onSave: { draft in
                studio.saveEditor(draft)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch studio.section {
        case .home:
            HomeView(studio: studio)
        case .project:
            ProjectsView(studio: studio)
        case .build:
            BuildView(model: studio.build, studio: studio)
        case .tools:
            ToolsView(model: studio.tools)
        case .settings:
            SettingsView(model: studio.settings)
        case .about:
            AboutView()
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title.weight(.semibold))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StudioCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }
}

struct StatusBadge: View {
    let title: String
    let isPositive: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isPositive ? Color.green.opacity(0.16) : Color.secondary.opacity(0.14), in: Capsule())
            .foregroundStyle(isPositive ? Color.green : Color.secondary)
    }
}
