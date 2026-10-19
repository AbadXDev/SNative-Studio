import Foundation

protocol ExecutableLocating: Sendable {
    func path(for executable: String) -> String?
}

struct FileSystemLocator: ExecutableLocating {
    var directories: [String]

    init(directories: [String]? = nil) {
        self.directories = directories ?? [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            NSHomeDirectory() + "/.dotnet",
            "/usr/local/share/dotnet"
        ]
    }

    func path(for executable: String) -> String? {
        let fileManager = FileManager.default
        for directory in directories {
            let candidate = (directory as NSString).appendingPathComponent(executable)
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}

struct EnvironmentProbe: Sendable {
    var locator: any ExecutableLocating

    static let live = EnvironmentProbe(locator: FileSystemLocator())

    func inspect() -> [ToolDependency] {
        catalog.map { item in
            if let path = locator.path(for: item.executable) {
                ToolDependency(id: item.id, name: item.name, purpose: item.purpose, executable: item.executable, state: .available(path: path))
            } else {
                ToolDependency(id: item.id, name: item.name, purpose: item.purpose, executable: item.executable, state: .missing)
            }
        }
    }

    private var catalog: [(id: String, name: String, purpose: String, executable: String)] {
        [
            ("xcode", "Xcode", "Compila la aplicación de iOS.", "xcodebuild"),
            ("swift", "Swift", "Lenguaje de SNative Studio.", "swift"),
            ("brew", "Homebrew", "Gestor que usa el entorno de nxnative.", "brew"),
            ("xcodegen", "XcodeGen", "Genera el proyecto de iOS.", "xcodegen"),
            ("zstd", "zstd", "Descomprime recursos del juego.", "zstd"),
            ("spirv", "spirv-cross", "Traduce sombreadores.", "spirv-cross"),
            ("dotnet", ".NET", "Compila la herramienta de extracción.", "dotnet"),
            ("python", "Python 3", "Ejecuta los scripts de empaquetado.", "python3")
        ]
    }
}
