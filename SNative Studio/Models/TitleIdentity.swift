import Foundation

enum TitleIdentity {
    /// Título de aplicación a partir del `[title ID]` del nombre, con la misma
    /// distinción base / actualización / DLC que `scan_nsps` del script oficial.
    static func applicationID(in fileName: String) -> String? {
        guard let title = bracketTitle(in: fileName) else { return nil }
        let low = title & 0xFFF
        let application: UInt64
        if low == 0 {
            application = title
        } else if low == 0x800 {
            application = title & ~0xFFF
        } else {
            application = (title & ~0xFFF) &- 0x1000
        }
        let hex = String(application, radix: 16).uppercased()
        return String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }

    static func families(in fileNames: [String]) -> Set<String> {
        Set(fileNames.compactMap { name in
            guard name.lowercased().hasSuffix(".nsp") else { return nil }
            return applicationID(in: name)
        })
    }

    private static func bracketTitle(in name: String) -> UInt64? {
        var rest = Substring(name)
        while let open = rest.range(of: "[") {
            let after = rest[open.upperBound...]
            guard let close = after.range(of: "]") else { return nil }
            let raw = after[..<close.lowerBound]
            if raw.count == 16, raw.allSatisfy(\.isHexDigit), let value = UInt64(raw, radix: 16) {
                return value
            }
            rest = after[close.upperBound...]
        }
        return nil
    }
}

enum ProfileIPA {
    /// Lee solo la clave `ipa` de un `game.tsv`. No interpreta NSP ni claves.
    static func fileName(in text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("#") { continue }
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0] == "ipa" else { continue }
            let name = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.hasSuffix(".ipa"), name != ".ipa", !name.contains("/"), !name.contains("\\"), !name.contains("..") else {
                return nil
            }
            return name
        }
        return nil
    }
}
