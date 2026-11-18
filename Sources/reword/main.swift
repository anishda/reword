import Foundation
import RewordCore

func err(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }

func usage() -> Never {
    err("""
    Usage: reword <mode> [--strict] [--timeout N] [--debug]
           reword --check | --list-modes | --dump-modes
    Lit le texte sur stdin, écrit le résultat sur stdout.
    """)
    exit(ExitCode.usage.rawValue)
}

var args = Array(CommandLine.arguments.dropFirst())
let loaded = Modes.load()
if let w = loaded.warning { err("reword: \(w)") }
let modes = loaded.modes

if args.isEmpty { usage() }

switch args[0] {
case "--check":
    if let reason = FMEngine.unavailabilityReason() {
        print("{\"available\": false, \"reason\": \"\(reason)\"}")
        exit(ExitCode.modelUnavailable.rawValue)
    }
    print("{\"available\": true}")
    exit(0)
case "--list-modes":
    modes.forEach { print($0.name) }
    exit(0)
case "--dump-modes":
    let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try enc.encode(modes), as: UTF8.self))
    exit(0)
default: break
}

let modeName = args.removeFirst()
guard let mode = modes.first(where: { $0.name == modeName }) else {
    err("reword: mode inconnu « \(modeName) ». Modes : \(modes.map(\.name).joined(separator: ", "))")
    exit(ExitCode.usage.rawValue)
}
var strict = false, debug = false, timeout: TimeInterval = 20
var i = 0
while i < args.count {
    switch args[i] {
    case "--strict": strict = true
    case "--debug": debug = true
    case "--timeout":
        i += 1
        guard i < args.count, let t = TimeInterval(args[i]), t > 0 else { usage() }
        timeout = t
    default: usage()
    }
    i += 1
}

let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)

if let reason = FMEngine.unavailabilityReason() {
    err("reword: \(reason)")
    exit(ExitCode.modelUnavailable.rawValue)
}

let start = Date()
do {
    let out = try await Rewriter(engine: FMEngine(strict: strict)).run(mode: mode, input: input, timeout: timeout)
    FileHandle.standardOutput.write(Data(out.utf8))
    if debug { err("reword: mode=\(mode.name) in=\(input.count) out=\(out.count) \(String(format: "%.2f", Date().timeIntervalSince(start))) s") }
    exit(0)
} catch let e as RewordError {
    err("reword: \(e.message)")
    exit(e.code.rawValue)
} catch {
    err("reword: \(error.localizedDescription)")
    exit(ExitCode.generationError.rawValue)
}
