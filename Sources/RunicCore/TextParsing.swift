import Foundation

public enum TextParsing {
    /// Removes ANSI escape sequences so regex parsing works on colored terminal output.
    ///
    /// Cursor moves that stand in for spacing are rendered as spaces rather
    /// than dropped: Claude Code 2.1 lays out `/usage` with `ESC[nG` (column)
    /// and `ESC[nC` (forward) between words, so a plain strip glues
    /// "Current session" into "Currentsession" and nothing matches.
    public static func stripANSICodes(_ text: String) -> String {
        // CSI sequences: ESC [ ... ending in 0x40–0x7E
        let pattern = #"\u001B\[[0-?]*[ -/]*[@-~]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let ns = text as NSString
        var out = ""
        out.reserveCapacity(text.count)
        var column = 0
        var cursor = 0

        func emit(_ chunk: String) {
            for ch in chunk {
                out.append(ch)
                if ch.isNewline { column = 0 } else { column += 1 }
            }
        }

        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            emit(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            cursor = match.range.location + match.range.length
            let sequence = ns.substring(with: match.range)
            let parameter = Int(sequence.dropFirst(2).dropLast()) ?? 1
            switch sequence.last {
            case "G": // cursor horizontal absolute, 1-based
                let target = max(parameter, 1) - 1
                if target > column { emit(String(repeating: " ", count: target - column)) }
            case "C": // cursor forward
                emit(String(repeating: " ", count: max(parameter, 1)))
            default:
                break
            }
        }
        emit(ns.substring(from: cursor))
        return out
    }

    public static func firstNumber(pattern: String, text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let raw = text[r].replacingOccurrences(of: ",", with: "")
        return Double(raw)
    }

    public static func firstInt(pattern: String, text: String) -> Int? {
        guard let v = firstNumber(pattern: pattern, text: text) else { return nil }
        return Int(v)
    }

    public static func firstLine(matching pattern: String, text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let r = Range(match.range(at: 0), in: text) else { return nil }
        return String(text[r])
    }

    public static func percentLeft(fromLine line: String) -> Int? {
        guard let pct = firstInt(pattern: #"([0-9]{1,3})%\s+left"#, text: line) else { return nil }
        return pct
    }

    public static func resetString(fromLine line: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"resets?\s+(.+)"#, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: line)
        else {
            return nil
        }
        // Return the tail text only (drop the "resets" prefix).
        return String(line[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
