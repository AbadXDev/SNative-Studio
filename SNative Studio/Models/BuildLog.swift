import Foundation

enum BuildLogEvent: Equatable, Sendable {
    case started(index: Int, total: Int, name: String, step: String?)
    case progress(index: Int, total: Int, name: String, step: String?, percent: Int?, detail: String)
    case ended(index: Int, total: Int, name: String, ok: Bool, summary: String)
    case announced(String)
    case message(String)
}

enum BuildLogParser {
    static func parse(_ raw: String) -> BuildLogEvent {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rest = stageRemainder(of: line) else {
            return announcement(in: line) ?? .message(line)
        }
        if rest.first == "✓" || rest.first == "✗" {
            return parseEnd(String(rest)) ?? .message(line)
        }
        if rest.hasPrefix("[") {
            return parseStage(String(rest)) ?? announcement(in: line) ?? .message(line)
        }
        return announcement(in: line) ?? .message(line)
    }

    private static func stageRemainder(of line: String) -> Substring? {
        guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { return nil }
        let time = line[line.index(after: line.startIndex)..<close]
        guard time.count == 8, time.dropFirst(2).first == ":", time.dropFirst(5).first == ":" else { return nil }
        return line[line.index(after: close)...].drop(while: \.isWhitespace)
    }

    private static func parseStage(_ rest: String) -> BuildLogEvent? {
        guard let header = fraction(in: rest) else { return nil }
        let body = header.body
        if body.hasSuffix("…") {
            let nameSource = body.dropLast().trimmingCharacters(in: .whitespaces)
            let parts = splitStep(nameSource)
            return .started(index: header.index, total: header.total, name: parts.name, step: parts.step)
        }
        guard let separator = body.range(of: ": ", options: .backwards) else { return nil }
        let parts = splitStep(String(body[..<separator.lowerBound]))
        let payload = String(body[separator.upperBound...])
        let estimated = payload.contains("~")
        let token = payload.split(separator: ",", maxSplits: 1).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let percent = token.hasSuffix("%") ? Int(token.dropLast()) : nil
        return .progress(
            index: header.index,
            total: header.total,
            name: parts.name,
            step: parts.step,
            percent: estimated ? nil : percent,
            detail: payload
        )
    }

    private static func parseEnd(_ rest: String) -> BuildLogEvent? {
        let ok = rest.first == "✓"
        let afterMark = rest.dropFirst().drop(while: \.isWhitespace)
        guard let header = fraction(in: String(afterMark)) else { return nil }
        guard let timeStart = header.body.range(of: " (", options: .backwards),
              let timeEnd = header.body[timeStart.upperBound...].firstIndex(of: ")") else { return nil }
        let name = String(header.body[..<timeStart.lowerBound]).trimmingCharacters(in: .whitespaces)
        var summary = ""
        let afterTime = header.body[header.body.index(after: timeEnd)...]
        if afterTime.hasPrefix(": ") {
            summary = String(afterTime.dropFirst(2))
        }
        guard !name.isEmpty else { return nil }
        return .ended(index: header.index, total: header.total, name: name, ok: ok, summary: summary)
    }

    private static func announcement(in line: String) -> BuildLogEvent? {
        if let range = line.range(of: "output IPA: ") {
            let path = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if path.hasPrefix("/") { return .announced(String(path)) }
        }
        if let range = line.range(of: "done: ") {
            var path = String(line[range.upperBound...])
            if let end = path.firstIndex(of: "（") {
                path = String(path[..<end])
            }
            path = path.trimmingCharacters(in: .whitespaces)
            if path.hasPrefix("/") { return .announced(path) }
        }
        return nil
    }

    private static func fraction(in rest: String) -> (index: Int, total: Int, body: Substring)? {
        guard rest.hasPrefix("["), let close = rest.firstIndex(of: "]") else { return nil }
        let raw = rest[rest.index(after: rest.startIndex)..<close]
        let parts = raw.split(separator: "/", maxSplits: 1)
        guard parts.count == 2, let index = Int(parts[0]), let total = Int(parts[1]) else { return nil }
        let body = rest[rest.index(after: close)...].drop(while: \.isWhitespace)
        return (index, total, body)
    }

    private static func splitStep(_ head: String) -> (name: String, step: String?) {
        guard let marker = head.range(of: " · ") else { return (head, nil) }
        let name = String(head[..<marker.lowerBound])
        let step = String(head[marker.upperBound...])
        return (name, step.isEmpty ? nil : step)
    }
}

enum BuildLogReducer {
    static func apply(_ line: String, to snapshot: inout BuildSnapshot) {
        snapshot.log += line + "\n"
        switch BuildLogParser.parse(line) {
        case .started(let index, let total, let name, let step):
            begin(index: index, total: total, name: name, step: step, in: &snapshot)
        case .progress(let index, let total, let name, let step, let percent, let detail):
            guard place(index: index, total: total, in: &snapshot) else { return }
            snapshot.phases[index - 1].title = name
            snapshot.phases[index - 1].state = .running
            snapshot.phases[index - 1].summary = step.map { "\($0) · \(detail)" } ?? detail
            if let percent {
                snapshot.progress = Double(percent) / 100
            } else {
                snapshot.progress = nil
            }
        case .ended(let index, let total, let name, let ok, let summary):
            guard place(index: index, total: total, in: &snapshot) else { return }
            snapshot.phases[index - 1].title = name
            snapshot.phases[index - 1].state = ok ? .completed : .failed
            snapshot.phases[index - 1].summary = summary.isEmpty ? (ok ? "Terminada" : "El motor marcó la fase como fallida.") : summary
            snapshot.progress = nil
        case .announced(let path):
            snapshot.announcedIPA = path
        case .message:
            break
        }
    }

    static func finish(_ snapshot: inout BuildSnapshot, exitCode: Int32, plannedIPA: String, ipaExists: (String) -> Bool, now: Date = Date()) {
        guard snapshot.status == .running else { return }
        snapshot.finishedAt = now
        snapshot.progress = nil
        let announced = snapshot.announcedIPA
        let target = announced ?? plannedIPA
        let announcementMatches = announced == nil || announced == plannedIPA
        if exitCode == 0, announcementMatches, ipaExists(target), target == plannedIPA {
            snapshot.status = .succeeded
            snapshot.ipaPath = target
            snapshot.message = "La IPA se generó en \(target)."
        } else if exitCode == 0 {
            snapshot.status = .failed
            snapshot.ipaPath = nil
            if !announcementMatches, let announced {
                snapshot.message = "El proceso terminó con código 0, pero anunció \(announced) en lugar de \(plannedIPA)."
            } else if !ipaExists(target) {
                snapshot.message = "El proceso terminó con código 0, pero no hay una IPA en \(target)."
            } else {
                snapshot.message = "El proceso terminó con código 0, pero la IPA no quedó verificada."
            }
        } else {
            snapshot.status = .failed
            snapshot.ipaPath = nil
            snapshot.message = "El proceso terminó con el código \(exitCode)."
            if ipaExists(plannedIPA) {
                snapshot.message += " Hay un archivo en \(plannedIPA); no se da por válida la compilación."
            }
        }
        snapshot.log += "SNative Studio: \(snapshot.message)\n"
    }

    static func cancel(_ snapshot: inout BuildSnapshot, now: Date = Date()) {
        guard snapshot.status == .running else { return }
        snapshot.status = .cancelled
        snapshot.finishedAt = now
        snapshot.progress = nil
        snapshot.message = "Compilación cancelada. No se ha dado por terminada."
        if let index = snapshot.phases.firstIndex(where: { $0.state == .running }) {
            snapshot.phases[index].state = .failed
            snapshot.phases[index].summary = "Cancelada"
        }
        snapshot.log += "SNative Studio: \(snapshot.message)\n"
    }

    private static func begin(index: Int, total: Int, name: String, step: String?, in snapshot: inout BuildSnapshot) {
        if index == 1, snapshot.phases.contains(where: { $0.state == .completed || $0.state == .failed }) {
            snapshot.phases = []
        }
        guard place(index: index, total: total, in: &snapshot) else { return }
        snapshot.phases[index - 1].title = name
        snapshot.phases[index - 1].summary = step.map { "Paso: \($0)" } ?? "En curso"
        snapshot.phases[index - 1].state = .running
        snapshot.progress = nil
    }

    private static func place(index: Int, total: Int, in snapshot: inout BuildSnapshot) -> Bool {
        guard (1...64).contains(total), (1...total).contains(index) else { return false }
        if snapshot.phases.count < total {
            for number in (snapshot.phases.count + 1)...total {
                snapshot.phases.append(BuildPhase(
                    id: "stage-\(number)",
                    title: "Fase \(number)",
                    summary: "El motor reservó esta fase y todavía no la ha nombrado.",
                    state: .pending
                ))
            }
        }
        return index <= snapshot.phases.count
    }
}
