import Foundation

enum PathKind: Equatable, Sendable {
    case nsp
    case prodKeys
    case directory
}

enum PathVerdict: Equatable, Sendable {
    case empty
    case valid
    case missing
    case notFile
    case notDirectory
    case wrongExtension
    case wrongFileName

    var isValid: Bool { self == .valid }

    var message: String {
        switch self {
        case .empty: "Sin seleccionar"
        case .valid: "Ruta válida"
        case .missing: "No existe en esta ruta"
        case .notFile: "Se esperaba un archivo"
        case .notDirectory: "Se esperaba una carpeta"
        case .wrongExtension: "El archivo debe terminar en .nsp"
        case .wrongFileName: "El archivo debe llamarse prod.keys"
        }
    }
}

struct PathFacts: Equatable, Sendable {
    var exists: Bool
    var isDirectory: Bool
}

enum PathValidation {
    static func verdict(path: String, kind: PathKind, facts: PathFacts?) -> PathVerdict {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard let facts, facts.exists else { return .missing }
        switch kind {
        case .nsp:
            guard !facts.isDirectory else { return .notFile }
            let name = URL(fileURLWithPath: trimmed).lastPathComponent
            guard name.lowercased().hasSuffix(".nsp") else { return .wrongExtension }
            return .valid
        case .prodKeys:
            guard !facts.isDirectory else { return .notFile }
            let name = URL(fileURLWithPath: trimmed).lastPathComponent
            guard name == "prod.keys" else { return .wrongFileName }
            return .valid
        case .directory:
            guard facts.isDirectory else { return .notDirectory }
            return .valid
        }
    }

    static func facts(for path: String, fileManager: FileManager = .default) -> PathFacts? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: trimmed, isDirectory: &isDirectory) else { return nil }
        return PathFacts(exists: true, isDirectory: isDirectory.boolValue)
    }
}

struct ProjectFieldCheck: Equatable, Identifiable, Sendable {
    var id: String { title }
    let title: String
    let path: String
    let verdict: PathVerdict
    var isOptional: Bool = false

    var isSatisfied: Bool {
        if isOptional && verdict == .empty { return true }
        return verdict.isValid
    }

    var statusText: String {
        if isOptional && verdict == .empty { return "Opcional" }
        return verdict.message
    }
}

struct ProjectValidation: Equatable, Sendable {
    var fields: [ProjectFieldCheck]

    var isComplete: Bool { fields.allSatisfy(\.isSatisfied) }

    var summary: String {
        if isComplete {
            return "Las rutas obligatorias son válidas. La comprobación no procesa el contenido de los archivos."
        }
        let pending = fields.filter { !$0.isSatisfied }.count
        return pending == 1 ? "Falta 1 ruta por completar." : "Faltan \(pending) rutas por completar."
    }

    static func evaluate(_ draft: ProjectDraft, facts: (String) -> PathFacts? = { PathValidation.facts(for: $0) }) -> ProjectValidation {
        let specs: [(String, String, PathKind, Bool)] = [
            ("NSP del juego base", draft.baseNSP, .nsp, false),
            ("NSP de actualización", draft.updateNSP, .nsp, true),
            ("prod.keys", draft.prodKeys, .prodKeys, false),
            ("Carpeta de salida", draft.outputDirectory, .directory, false)
        ]
        return ProjectValidation(fields: specs.map { title, path, kind, optional in
            ProjectFieldCheck(
                title: title,
                path: path,
                verdict: PathValidation.verdict(path: path, kind: kind, facts: facts(path)),
                isOptional: optional
            )
        })
    }
}
