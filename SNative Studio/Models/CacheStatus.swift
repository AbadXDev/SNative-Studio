import Foundation

enum CacheStatus: Equatable, Sendable {
    case present(String)
    case absent(String)
    case unknown(String)

    var message: String {
        switch self {
        case .present(let path):
            "Caché presente en \(path)."
        case .absent(let path):
            "No hay caché de una ejecución anterior en \(path)."
        case .unknown(let reason):
            reason
        }
    }

    /// La carpeta `<NSP>/<título>_build` es la que crea el script. Solo se informa si el título está en el nombre del archivo.
    static func detect(draft: ProjectDraft, directoryExists: (String) -> Bool = CacheStatus.directoryExists) -> CacheStatus {
        let base = draft.baseNSP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else {
            return .unknown("No se puede detectar la caché sin el NSP base.")
        }
        let fileName = URL(fileURLWithPath: base).lastPathComponent
        guard let identifier = TitleIdentity.applicationID(in: fileName) else {
            return .unknown("No se puede detectar la caché: el nombre del NSP base no incluye el título.")
        }
        let folder = URL(fileURLWithPath: base)
            .deletingLastPathComponent()
            .appendingPathComponent("\(identifier)_build")
            .path
        if directoryExists(folder) {
            return .present(folder)
        }
        return .absent(folder)
    }

    private static func directoryExists(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
