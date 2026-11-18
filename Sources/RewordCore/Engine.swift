import Foundation
import FoundationModels

public enum ExitCode: Int32, Sendable {
    case ok = 0, usage = 2, emptyInput = 3
    case modelUnavailable = 10, unsupportedLanguage = 11, guardrail = 12
    case tooLong = 13, timeout = 14, generationError = 15, badOutput = 16
}

public struct RewordError: Error {
    public let code: ExitCode
    public let message: String
    public init(_ code: ExitCode, _ message: String) { self.code = code; self.message = message }
}

public protocol TextEngine: Sendable {
    func generate(instructions: String, prompt: String, temperature: Double?) async throws -> String
}

public struct FMEngine: TextEngine {
    public let strict: Bool
    public init(strict: Bool = false) { self.strict = strict }

    private var model: SystemLanguageModel {
        strict ? SystemLanguageModel.default
               : SystemLanguageModel(guardrails: .permissiveContentTransformations)
    }

    public func generate(instructions: String, prompt: String, temperature: Double?) async throws -> String {
        let session = LanguageModelSession(model: model, instructions: instructions)
        let options: GenerationOptions = temperature.map {
            GenerationOptions(temperature: $0)
        } ?? GenerationOptions(samplingMode: .greedy)
        do {
            let response = try await session.respond(to: prompt, options: options)
            return response.content
        } catch let e as LanguageModelSession.GenerationError {
            throw FMEngine.map(e)
        }
    }

    static func map(_ e: LanguageModelSession.GenerationError) -> RewordError {
        switch e {
        case .exceededContextWindowSize:
            return RewordError(.tooLong, "Texte trop long pour le contexte du modèle.")
        case .guardrailViolation:
            return RewordError(.guardrail, "Refusé par les garde-fous d'Apple.")
        case .unsupportedLanguageOrLocale:
            return RewordError(.unsupportedLanguage, "Langue non prise en charge par le modèle.")
        case .assetsUnavailable:
            return RewordError(.modelUnavailable, "Modèle indisponible (assets non téléchargés).")
        default:
            return RewordError(.generationError, "Erreur de génération : \(e.localizedDescription)")
        }
    }

    /// Human readable availability, nil when available.
    public static func unavailabilityReason() -> String? {
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "Cet appareil n'est pas éligible à Apple Intelligence."
            case .appleIntelligenceNotEnabled: return "Apple Intelligence est désactivée (Réglages Système)."
            case .modelNotReady: return "Le modèle n'est pas prêt (téléchargement en cours)."
            @unknown default: return "Modèle indisponible."
            }
        @unknown default: return "Modèle indisponible."
        }
    }
}
