import Foundation

public enum Chunker {
    /// Splits `text` into chunks of at most `maxChars`, on paragraph, then line, then sentence,
    /// then hard boundaries. Joining the chunks with `""` gives back exactly the original text.
    public static func split(_ text: String, maxChars: Int) -> [String] {
        guard text.count > maxChars else { return [text] }
        // Pieces keep their trailing separator so that concatenation is lossless.
        let pieces = pieces(of: text, maxChars: maxChars)
        var chunks: [String] = []
        var current = ""
        for p in pieces {
            if current.count + p.count > maxChars, !current.isEmpty {
                chunks.append(current); current = ""
            }
            current += p
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private static func pieces(of text: String, maxChars: Int) -> [String] {
        var out: [String] = []
        for para in splitKeepingSeparator(text, separators: ["\n\n"]) {
            if para.count <= maxChars { out.append(para); continue }
            for line in splitKeepingSeparator(para, separators: ["\n"]) {
                if line.count <= maxChars { out.append(line); continue }
                for sent in splitKeepingSeparator(line, separators: [". ", "! ", "? ", "; "]) {
                    if sent.count <= maxChars { out.append(sent); continue }
                    out.append(contentsOf: hardSplit(sent, maxChars: maxChars))
                }
            }
        }
        return out
    }

    private static func splitKeepingSeparator(_ s: String, separators: [String]) -> [String] {
        var result: [String] = []
        var current = ""
        var i = s.startIndex
        while i < s.endIndex {
            var matched: String?
            for sep in separators where s[i...].hasPrefix(sep) { matched = sep; break }
            if let sep = matched {
                current += sep
                i = s.index(i, offsetBy: sep.count)
                result.append(current); current = ""
            } else {
                current.append(s[i]); i = s.index(after: i)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private static func hardSplit(_ s: String, maxChars: Int) -> [String] {
        var out: [String] = []
        var start = s.startIndex
        while start < s.endIndex {
            let end = s.index(start, offsetBy: maxChars, limitedBy: s.endIndex) ?? s.endIndex
            out.append(String(s[start..<end])); start = end
        }
        return out
    }
}
