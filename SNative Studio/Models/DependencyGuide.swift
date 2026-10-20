import Foundation

struct DependencyAction: Equatable, Sendable, Identifiable {
    enum Kind: Equatable, Sendable {
        case copyCommand(String)
        case openDocumentation(URL)
        case manual(String)
    }

    var id: String
    var kind: Kind
}

enum DependencyGuide {
    static let dotNetRequirement = ".NET SDK 10"
    static let xcodeDocumentation = URL(string: "https://apps.apple.com/app/xcode/id497799835")!
    static let homebrewDocumentation = URL(string: "https://brew.sh")!

    static let xcodeGenCommand = "brew install xcodegen"
    static let zstdCommand = "brew install zstd"
    static let spirvCrossCommand = "brew install spirv-cross"
    static let dotNetCommand = "brew install --cask dotnet-sdk"
    static let pythonModulesCommand = "python3 -m pip install lz4 capstone fonttools"
    /// Project page recorded in the local LibHac 0.19.0 nuspec. The nupkg does not contain the MIT text.
    static let libHacDocumentation = URL(string: "https://github.com/Thealexbarney/LibHac")!

    static func isDotNetSDK10(_ version: String) -> Bool {
        let token = version.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? version
        return token.split(separator: ".").first == "10"
    }

    static func actions(id: String, brewDetected: Bool, pythonDetected: Bool) -> [DependencyAction] {
        switch id {
        case "xcode", "ios-sdk", "metal", "make":
            return manualAndDocumentation(id: id, text: appleManual(id), url: xcodeDocumentation)
        case "zip":
            return [manual(zipManual)]
        case "xcodegen":
            return brewTool(command: xcodeGenCommand, name: "XcodeGen", brewDetected: brewDetected)
        case "zstd":
            return brewTool(command: zstdCommand, name: "zstd", brewDetected: brewDetected)
        case "spirv":
            return brewTool(command: spirvCrossCommand, name: "spirv-cross", brewDetected: brewDetected)
        case "dotnet":
            return dotNetActions(brewDetected: brewDetected)
        case "python":
            return [manual(pythonManual)]
        case "python-modules":
            return pythonModuleActions(pythonDetected: pythonDetected)
        case "libhac":
            return manualAndDocumentation(id: id, text: libHacManual, url: libHacDocumentation)
        case "swift":
            return manualAndDocumentation(id: id, text: swiftManual, url: xcodeDocumentation)
        case "brew":
            return manualAndDocumentation(id: id, text: homebrewManual, url: homebrewDocumentation)
        default:
            return []
        }
    }

    static func engineNote(_ location: EngineLocation) -> String? {
        if case .external = location {
            return "Checkout externo, útil en desarrollo. La distribución final usa Contents/Resources/Engine."
        }
        return nil
    }

    static func engineActions(_ location: EngineLocation) -> [DependencyAction] {
        switch location {
        case .packaged, .external:
            return []
        case .absent:
            return [manual(EngineLocator.absentMessage)]
        case .incomplete(let directory, let missing):
            return [manual(EngineLocator.incompleteMessage(directory: directory, missing: missing))]
        }
    }

    private static let zipManual = "zip es la herramienta de macOS con la que el script empaqueta la IPA. SNative Studio no la instala."
    private static let pythonManual = "El script se ejecuta con python3. Esta fase no elige una distribución redistribuible. SNative Studio no instala el intérprete ni copia el de macOS."
    private static let swiftManual = "Swift no participa en la generación de la IPA. Xcode lo incluye."
    private static let homebrewManual = "Homebrew no participa en la generación de la IPA cuando las otras herramientas ya están. El README de nxnative lo usa para instalar xcodegen, zstd, spirv-cross y el cask de .NET. SNative Studio no ejecuta su instalador."
    private static let libHacManual = "nx_extract.csproj referencia LibHac 0.19.0 y el checkout no tiene nuget.config. SNative Studio no restaura ni descarga el paquete. La compilación no empieza si el nupkg no está en la caché del usuario ni en Engine/local-nuget."

    private static func appleManual(_ id: String) -> String {
        switch id {
        case "ios-sdk":
            return "El SDK de iOS forma parte de Xcode. El script lo necesita para compilar la IPA. SNative Studio no lo descarga."
        case "metal":
            return "El compilador Metal forma parte de Xcode. El script lo usa con xcrun metal y metallib. SNative Studio no lo instala."
        case "make":
            return "El script busca make y lo asocia a Xcode. SNative Studio no lo instala."
        default:
            return "Instala Xcode desde su ficha del App Store. Aporta xcodebuild, y con él el SDK de iOS y el compilador Metal. Sin Xcode no se puede generar una IPA. SNative Studio no lo instala."
        }
    }

    private static func brewTool(command: String, name: String, brewDetected: Bool) -> [DependencyAction] {
        let documented = "El README de nxnative y el script documentan `\(command)`."
        if brewDetected {
            return [
                manual("\(documented) SNative Studio no ejecuta el comando."),
                copy(command),
                documentation(homebrewDocumentation, id: "docs")
            ]
        }
        return [manual("\(documented) Homebrew no está detectado, así que ese comando no se ofrece para copiarlo.")]
    }

    private static func dotNetActions(brewDetected: Bool) -> [DependencyAction] {
        let versionNote = "El script exige \(dotNetRequirement). El comando del README no fija ese número, y esta fase no ha comprobado qué versión instala el cask."
        if brewDetected {
            return [
                manual("El README de nxnative documenta `\(dotNetCommand)`. \(versionNote) SNative Studio no ejecuta el comando."),
                copy(dotNetCommand),
                documentation(homebrewDocumentation, id: "docs")
            ]
        }
        return [manual("El README de nxnative documenta `\(dotNetCommand)`. \(versionNote) Homebrew no está detectado, así que ese comando no se ofrece para copiarlo.")]
    }

    private static func pythonModuleActions(pythonDetected: Bool) -> [DependencyAction] {
        let documented = "El README de nxnative documenta `\(pythonModulesCommand)`."
        if pythonDetected {
            return [
                manual("\(documented) El script importa lz4.block, capstone y fontTools. SNative Studio no ejecuta el comando."),
                copy(pythonModulesCommand)
            ]
        }
        return [manual("\(documented) python3 no está detectado, así que ese comando no se ofrece para copiarlo.")]
    }

    private static func manualAndDocumentation(id: String, text: String, url: URL) -> [DependencyAction] {
        [manual(text), documentation(url, id: "\(id)-docs")]
    }

    private static func manual(_ text: String) -> DependencyAction {
        DependencyAction(id: "manual", kind: .manual(text))
    }

    private static func copy(_ command: String) -> DependencyAction {
        DependencyAction(id: "copy", kind: .copyCommand(command))
    }

    private static func documentation(_ url: URL, id: String) -> DependencyAction {
        DependencyAction(id: id, kind: .openDocumentation(url))
    }
}
