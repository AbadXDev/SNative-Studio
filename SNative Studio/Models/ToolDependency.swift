import Foundation

struct ToolDependency: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let purpose: String
    let executable: String
    let requirement: Requirement
    let state: State
    var version: String?
    var note: String?
    var locationNote: String?
    var actions: [DependencyAction]

    enum Requirement: Equatable, Sendable {
        case required
        case optional

        var title: String {
            switch self {
            case .required: "Obligatoria"
            case .optional: "Opcional"
            }
        }
    }

    enum State: Equatable, Sendable {
        case available(path: String)
        case included(path: String)
        case missing
        case incompatible(path: String, version: String, expected: String)
        case incomplete(path: String, missing: [String])
    }

    var isAvailable: Bool {
        switch state {
        case .available, .included: true
        case .missing, .incompatible, .incomplete: false
        }
    }

    var installationPending: Bool {
        requirement == .required && !isAvailable
    }

    var blocksCompilation: Bool { installationPending }

    var statusTitle: String {
        switch state {
        case .available: "Disponible"
        case .included: "Incluida en SNative Studio"
        case .incompatible: "Versión incompatible"
        case .incomplete: "Incompleto"
        case .missing:
            actions.contains(where: isCopy) ? "No detectada" : (requirement == .required ? "Requiere instalación manual" : "No detectada")
        }
    }

    var requirementTitle: String { requirement.title }

    var location: String {
        if let locationNote { return locationNote }
        switch state {
        case .available(let path), .included(let path), .incompatible(let path, _, _), .incomplete(let path, _):
            return path
        case .missing:
            return "No está en las rutas habituales"
        }
    }

    private func isCopy(_ action: DependencyAction) -> Bool {
        if case .copyCommand = action.kind { return true }
        return false
    }
}

struct DependencySpec: Equatable, Sendable {
    var id: String
    var name: String
    var purpose: String
    var executable: String
    var requirement: ToolDependency.Requirement
}

enum DependencyCatalog {
    static let specs: [DependencySpec] = [
        DependencySpec(id: "engine", name: "nxnative", purpose: "Motor que contiene el script, el extractor y el traductor.", executable: "", requirement: .required),
        DependencySpec(id: "python", name: "Python 3", purpose: "Ejecuta el script que genera la IPA.", executable: "python3", requirement: .required),
        DependencySpec(id: "python-modules", name: "Módulos de Python", purpose: "El script importa lz4.block, capstone y fontTools.", executable: "", requirement: .required),
        DependencySpec(id: "xcode", name: "Xcode", purpose: "Compila la aplicación de iOS mediante xcodebuild.", executable: "xcodebuild", requirement: .required),
        DependencySpec(id: "ios-sdk", name: "SDK de iOS", purpose: "SDK que xcodebuild usa al generar la IPA.", executable: "", requirement: .required),
        DependencySpec(id: "metal", name: "Metal", purpose: "Compila los sombreadores. El script llama a xcrun metal y metallib.", executable: "", requirement: .required),
        DependencySpec(id: "make", name: "make", purpose: "Compila el host durante la generación.", executable: "make", requirement: .required),
        DependencySpec(id: "xcodegen", name: "XcodeGen", purpose: "Genera el proyecto de iOS.", executable: "xcodegen", requirement: .required),
        DependencySpec(id: "dotnet", name: ".NET", purpose: "Compila el extractor con dotnet build. El script exige .NET SDK 10.", executable: "dotnet", requirement: .required),
        DependencySpec(id: "libhac", name: "LibHac", purpose: "Paquete NuGet 0.19.0 que nx_extract referencia para leer los NSP.", executable: "", requirement: .required),
        DependencySpec(id: "zstd", name: "zstd", purpose: "Descomprime recursos del juego.", executable: "zstd", requirement: .required),
        DependencySpec(id: "spirv", name: "spirv-cross", purpose: "Traduce sombreadores SPIR-V a MSL.", executable: "spirv-cross", requirement: .required),
        DependencySpec(id: "zip", name: "zip", purpose: "Empaqueta la IPA.", executable: "zip", requirement: .required),
        DependencySpec(id: "swift", name: "Swift", purpose: "Compilador del entorno. No participa en la generación de la IPA.", executable: "swift", requirement: .optional),
        DependencySpec(id: "brew", name: "Homebrew", purpose: "Gestor citado por el README de nxnative para instalar otras herramientas.", executable: "brew", requirement: .optional)
    ]
}
