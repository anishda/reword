import Foundation
import NaturalLanguage

public struct Rewriter: Sendable {
    public let engine: TextEngine
    public let chunkChars: Int
    public init(engine: TextEngine, chunkChars: Int = 2500) {
        self.engine = engine; self.chunkChars = chunkChars
    }

    public func run(mode: Mode, input: String, timeout: TimeInterval = 20) async throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RewordError(.emptyInput, "Aucun texte.")
        }
        if let limit = mode.maxInputChars, input.count > limit {
            throw RewordError(.tooLong, "Texte trop long pour ce mode (maximum \(limit) caractères).")
        }
        let mode = Rewriter.resolve(mode, for: input)
        return try await withTimeout(timeout) {
            let chunks = Chunker.split(input, maxChars: chunkChars)
            var result = ""
            for chunk in chunks {
                if chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result += chunk; continue }
                result += try await rewriteChunk(mode: mode, chunk: chunk)
            }
            return result
        }
    }

    /// "translate" picks its direction from the detected language: French -> English, anything else -> French.
    public static func resolve(_ mode: Mode, for input: String) -> Mode {
        guard mode.name == "translate" else { return mode }
        let lang = NLLanguageRecognizer.dominantLanguage(for: input)
        let target = (lang == .french) ? "translate-en" : "translate-fr"
        if let m = Modes.builtin.first(where: { $0.name == target }) {
            var r = m; r.name = mode.name; r.minRatio = mode.minRatio; r.maxRatio = mode.maxRatio; r.temperature = mode.temperature
            return r
        }
        return mode
    }

    private func rewriteChunk(mode: Mode, chunk: String) async throws -> String {
        let prompt = "<text>\(chunk.trimmingCharacters(in: .whitespacesAndNewlines))</text>"
        let raw = try await engine.generate(instructions: Modes.fullInstructions(for: mode),
                                            prompt: prompt, temperature: mode.temperature)
        let cleaned = PostProcess.clean(raw, original: chunk)
        guard PostProcess.ratioOK(output: cleaned, input: chunk, mode: mode) else {
            throw RewordError(.badOutput, "Résultat inexploitable (longueur incohérente).")
        }
        return cleaned
    }
}

func withTimeout<T: Sendable>(_ seconds: TimeInterval, _ op: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await op() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw RewordError(.timeout, "Délai dépassé (\(Int(seconds)) s).")
        }
        defer { group.cancelAll() }
        let first = try await group.next()!
        return first
    }
}
