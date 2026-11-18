import Testing
import Foundation
@testable import RewordCore

struct FakeEngine: TextEngine {
    var reply: @Sendable (String) -> String
    func generate(instructions: String, prompt: String, temperature: Double?) async throws -> String { reply(prompt) }
}

@Suite struct ChunkerTests {
    @Test func shortTextIsOneChunk() { #expect(Chunker.split("abc", maxChars: 10) == ["abc"]) }

    @Test func splitIsLossless() {
        let text = (1...40).map { "Phrase numéro \($0). Autre phrase ici !" }.joined(separator: "\n\n") + "\n"
        let chunks = Chunker.split(text, maxChars: 200)
        #expect(chunks.joined() == text)
        #expect(chunks.allSatisfy { $0.count <= 200 })
        #expect(chunks.count > 1)
    }

    @Test func noPunctuationHardSplit() {
        let text = String(repeating: "a", count: 1000)
        let chunks = Chunker.split(text, maxChars: 300)
        #expect(chunks.joined() == text)
        #expect(chunks.allSatisfy { $0.count <= 300 })
    }

    @Test func emojiAndAccentsLossless() {
        let text = String(repeating: "Éléphant 🐘 café ", count: 100)
        #expect(Chunker.split(text, maxChars: 120).joined() == text)
    }
}

@Suite struct PostProcessTests {
    @Test func stripsPreamble() {
        #expect(PostProcess.clean("Voici le texte corrigé :\nBonjour.", original: "bonjour") == "Bonjour.")
    }
    @Test func stripsQuotesAndTags() {
        #expect(PostProcess.clean("\"Bonjour\"", original: "bonjour") == "Bonjour")
        #expect(PostProcess.clean("<text>Bonjour</text>", original: "bonjour") == "Bonjour")
    }
    @Test func keepsQuotesWhenOriginalHadThem() {
        #expect(PostProcess.clean("\"Bonjour\"", original: "\"bonjour\"") == "\"Bonjour\"")
    }
    @Test func stripsFences() {
        #expect(PostProcess.clean("```\nlet a = 1\n```", original: "let a=1") == "let a = 1")
    }
    @Test func restoresWhitespace() {
        #expect(PostProcess.clean("Salut", original: "  salut\n") == "  Salut\n")
    }
    @Test func ratio() {
        let fix = Modes.builtin.first { $0.name == "fix" }!
        #expect(PostProcess.ratioOK(output: "abcdefghijklmnop", input: "abcdefghijklmnoq", mode: fix))
        #expect(!PostProcess.ratioOK(output: "", input: "abcdefghijklmnoq", mode: fix))
        #expect(!PostProcess.ratioOK(output: String(repeating: "x", count: 100), input: "abcdefghijklmnoq", mode: fix))
    }
}

@Suite struct ModesTests {
    @Test func builtinNames() {
        let names = Modes.builtin.map(\.name)
        for n in ["fix", "rephrase", "shorten", "formal", "translate"] { #expect(names.contains(n)) }
    }
    @Test func missingFileUsesBuiltin() {
        let r = Modes.load(path: "/nonexistent/modes.json")
        #expect(r.modes == Modes.builtin && r.warning == nil)
    }
    @Test func corruptFileWarns() throws {
        let p = NSTemporaryDirectory() + "bad-\(UUID()).json"
        try "{not json".write(toFile: p, atomically: true, encoding: .utf8)
        let r = Modes.load(path: p)
        #expect(r.modes == Modes.builtin && r.warning != nil)
    }
    @Test func customOverridesAndExtends() throws {
        let p = NSTemporaryDirectory() + "ok-\(UUID()).json"
        let json = #"[{"name":"fix","instructions":"X","minRatio":0.1,"maxRatio":3},{"name":"casual","instructions":"Y","minRatio":0.5,"maxRatio":1.5}]"#
        try json.write(toFile: p, atomically: true, encoding: .utf8)
        let r = Modes.load(path: p).modes
        #expect(r.first { $0.name == "fix" }?.instructions == "X")
        #expect(r.contains { $0.name == "casual" })
        #expect(r.count == Modes.builtin.count + 1)
    }
}

@Suite struct RewriterTests {
    let fix = Modes.builtin.first { $0.name == "fix" }!
    let shorten = Modes.builtin.first { $0.name == "shorten" }!

    @Test func emptyInput() async {
        let r = Rewriter(engine: FakeEngine { $0 })
        await #expect(throws: RewordError.self) { try await r.run(mode: fix, input: "  \n") }
    }
    @Test func shortenRefusesLongText() async {
        let r = Rewriter(engine: FakeEngine { $0 })
        do { _ = try await r.run(mode: shorten, input: String(repeating: "a ", count: 3000)); Issue.record("should throw") }
        catch let e as RewordError { #expect(e.code == .tooLong) } catch { Issue.record("wrong error") }
    }
    @Test func chunksAreProcessedAndRejoined() async throws {
        let text = (1...30).map { "Ligne numéro \($0) du texte." }.joined(separator: "\n\n")
        let r = Rewriter(engine: FakeEngine { p in
            // echo input from the <text> wrapper, upper-cased
            String(p.dropFirst(6).dropLast(7)).uppercased()
        }, chunkChars: 150)
        let out = try await r.run(mode: fix, input: text)
        #expect(out.replacingOccurrences(of: "\n\n", with: "") == text.uppercased().replacingOccurrences(of: "\n\n", with: ""))
    }
    @Test func badRatioFails() async {
        let r = Rewriter(engine: FakeEngine { _ in "" })
        do { _ = try await r.run(mode: fix, input: "Un texte tout à fait normal."); Issue.record("should throw") }
        catch let e as RewordError { #expect(e.code == .badOutput) } catch { Issue.record("wrong error") }
    }
    @Test func timeout() async {
        struct Slow: TextEngine {
            func generate(instructions: String, prompt: String, temperature: Double?) async throws -> String {
                try await Task.sleep(for: .seconds(5)); return "x"
            }
        }
        do { _ = try await Rewriter(engine: Slow()).run(mode: fix, input: "Un texte tout à fait normal.", timeout: 0.3); Issue.record("should throw") }
        catch let e as RewordError { #expect(e.code == .timeout) } catch { Issue.record("wrong error") }
    }
}

@Suite struct TranslateTests {
    @Test func directionFromLanguage() {
        let t = Modes.builtin.first { $0.name == "translate" }!
        #expect(Rewriter.resolve(t, for: "La réunion est reportée à jeudi, merci de confirmer.").instructions.contains("into English"))
        #expect(Rewriter.resolve(t, for: "Could you please review the pull request before noon?").instructions.contains("into French"))
    }
}
