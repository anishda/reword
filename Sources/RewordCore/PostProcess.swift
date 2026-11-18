import Foundation

public enum PostProcess {
    /// Cleans the model output and re-applies the leading/trailing whitespace of the original.
    public static func clean(_ output: String, original: String) -> String {
        var s = output.trimmingCharacters(in: .whitespacesAndNewlines)

        // <text>…</text> wrapper
        if s.hasPrefix("<text>") { s.removeFirst("<text>".count) }
        if s.hasSuffix("</text>") { s.removeLast("</text>".count) }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // ``` fences around everything
        if s.hasPrefix("```"), s.hasSuffix("```"), s.count >= 6 {
            var inner = String(s.dropFirst(3).dropLast(3))
            if let nl = inner.firstIndex(of: "\n"), !inner[..<nl].contains(" ") { inner = String(inner[inner.index(after: nl)...]) }
            s = inner.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // "Voici le texte corrigé :" style preambles on their own first line
        let preambles = ["voici", "here is", "here's", "texte corrigé", "corrected text", "sure", "bien sûr", "certainly"]
        let lines = s.components(separatedBy: "\n")
        if lines.count > 1, let first = lines.first?.lowercased(),
           first.hasSuffix(":"), preambles.contains(where: { first.hasPrefix($0) }) {
            s = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // surrounding quotes added by the model (only if the original had none)
        let quotePairs: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("«", "»")]
        let origTrim = original.trimmingCharacters(in: .whitespacesAndNewlines)
        for (o, c) in quotePairs where s.count >= 2 && s.first == o && s.last == c {
            if !(origTrim.first == o && origTrim.last == c) {
                s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return leadingWhitespace(of: original) + s + trailingWhitespace(of: original)
    }

    public static func leadingWhitespace(of s: String) -> String {
        String(s.prefix(while: { $0.isWhitespace }))
    }

    public static func trailingWhitespace(of s: String) -> String {
        if s.allSatisfy({ $0.isWhitespace }) { return "" }
        return String(String(s.reversed()).prefix(while: { $0.isWhitespace }).reversed())
    }

    /// True when the result length is plausible for the mode.
    public static func ratioOK(output: String, input: String, mode: Mode) -> Bool {
        let o = output.trimmingCharacters(in: .whitespacesAndNewlines).count
        let i = input.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard o > 0, i > 0 else { return false }
        let r = Double(o) / Double(i)
        // very short inputs: ratios are meaningless, only require non-empty
        if i < 12 { return true }
        return r >= mode.minRatio && r <= mode.maxRatio
    }
}
