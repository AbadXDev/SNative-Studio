import AppKit
import UniformTypeIdentifiers

enum FileDialog {
    @MainActor
    static func chooseFile(title: String, extension ext: String?) -> String? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Seleccionar"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let ext, let type = UTType(filenameExtension: ext) {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }

    @MainActor
    static func chooseDirectory(title: String) -> String? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Seleccionar"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }
}
