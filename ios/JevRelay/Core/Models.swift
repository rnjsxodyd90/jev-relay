import Foundation

enum ToneMode: String, CaseIterable, Identifiable, Codable {
    case automatic, formal, informal, plural
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var contextInstruction: String? {
        switch self {
        case .automatic: return nil
        case .formal: return "Requested Dutch register: formal singular (u/uw)."
        case .informal: return "Requested Dutch register: informal singular (je/jij/jouw)."
        case .plural: return "Requested Dutch register: plural (jullie)."
        }
    }
}

struct InterpretRequest: Encodable, Equatable {
    let text: String
    let context: String
    let source = "en"
    let target = "nl"
    let senseOptions: [String: String] = [:]

    init(text: String, context: String, tone: ToneMode) throws {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { throw InputValidationError.emptyText }
        guard cleanText.utf8.count <= 4_000 else { throw InputValidationError.textTooLong }
        let cleanContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let joined = [cleanContext.isEmpty ? nil : cleanContext, tone.contextInstruction]
            .compactMap { $0 }.joined(separator: "\n")
        guard joined.count <= 2_000, joined.utf8.count <= 8_000 else { throw InputValidationError.contextTooLong }
        self.text = cleanText
        self.context = joined
    }
}

enum InputValidationError: LocalizedError, Equatable {
    case emptyText, textTooLong, contextTooLong
    var errorDescription: String? {
        switch self {
        case .emptyText: return "Enter an English turn to interpret."
        case .textTooLong: return "Keep each turn below 4,000 UTF-8 bytes."
        case .contextTooLong: return "Keep situational context within 2,000 characters and 8,000 UTF-8 bytes."
        }
    }
}

enum RelayRoute: String, Decodable { case memory, translate, clarify, review }

struct Decision: Decodable, Equatable {
    let choice: String
    let confidence: Double
    let probabilities: [String: Double]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        choice = try c.decode(String.self, forKey: .choice)
        confidence = try c.decode(Double.self, forKey: .confidence)
        probabilities = try c.decode([String: Double].self, forKey: .probabilities)
        guard confidence.isFinite, (0...1).contains(confidence),
              !probabilities.isEmpty, probabilities.count <= 32,
              probabilities.values.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              probabilities[choice] != nil,
              abs(probabilities.values.reduce(0, +) - 1) <= 0.02,
              probabilities[choice, default: -1] >= (probabilities.values.max() ?? 0) - 0.001 else {
            throw DecodingError.dataCorruptedError(forKey: .probabilities, in: c, debugDescription: "Invalid decision distribution.")
        }
    }
    private enum CodingKeys: String, CodingKey { case choice, confidence, probabilities }
}

struct DecisionBundle: Decodable, Equatable {
    let action: Decision?
    let memory: Decision?
    let register: Decision?
    let sense: Decision?
    var isComplete: Bool { action != nil && memory != nil && register != nil && sense != nil }
}

struct RelayTiming: Decodable, Equatable {
    let decisionMs: Int
    let translationMs: Int
    let totalMs: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        decisionMs = try c.decode(Int.self, forKey: .decisionMs)
        translationMs = try c.decode(Int.self, forKey: .translationMs)
        totalMs = try c.decode(Int.self, forKey: .totalMs)
        guard decisionMs >= 0, translationMs >= 0, totalMs >= 0,
              totalMs >= decisionMs, totalMs >= translationMs else {
            throw DecodingError.dataCorruptedError(forKey: .totalMs, in: c, debugDescription: "Invalid timing values.")
        }
    }
    private enum CodingKeys: String, CodingKey { case decisionMs, translationMs, totalMs }
}

struct InterpretResponse: Decodable, Equatable, Identifiable {
    let mode: String
    let sourceText: String
    let decisions: DecisionBundle
    let model: String
    let timing: RelayTiming
    let usedTranslator: Bool
    let translatedText: String
    let clarification: String
    let route: RelayRoute
    let reason: String
    let requestId: String?
    var id: String { requestId ?? "\(sourceText)-\(timing.totalMs)" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try c.decode(String.self, forKey: .mode)
        sourceText = try c.decode(String.self, forKey: .sourceText)
        decisions = try c.decode(DecisionBundle.self, forKey: .decisions)
        model = try c.decode(String.self, forKey: .model)
        timing = try c.decode(RelayTiming.self, forKey: .timing)
        usedTranslator = try c.decode(Bool.self, forKey: .usedTranslator)
        translatedText = try c.decodeIfPresent(String.self, forKey: .translatedText) ?? ""
        clarification = try c.decodeIfPresent(String.self, forKey: .clarification) ?? ""
        route = try c.decode(RelayRoute.self, forKey: .route)
        reason = try c.decode(String.self, forKey: .reason)
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId)
        guard mode == "live", sourceText.utf8.count <= 4_000, model.count <= 200,
              translatedText.count <= 8_000, clarification.count <= 2_000, reason.count <= 2_000 else {
            throw DecodingError.dataCorruptedError(forKey: .mode, in: c, debugDescription: "Response fields exceed the contract.")
        }
        guard route == .review || decisions.isComplete else {
            throw DecodingError.dataCorruptedError(forKey: .decisions, in: c, debugDescription: "Non-review routes require all four decisions.")
        }
        if route == .clarify && !translatedText.isEmpty {
            throw DecodingError.dataCorruptedError(forKey: .translatedText, in: c, debugDescription: "Clarification cannot contain an invented translation.")
        }
        if route == .review && !translatedText.isEmpty {
            throw DecodingError.dataCorruptedError(forKey: .translatedText, in: c, debugDescription: "Review cannot approve playback text.")
        }
        if (route == .memory || route == .translate) && translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DecodingError.dataCorruptedError(forKey: .translatedText, in: c, debugDescription: "Playable routes require Dutch text.")
        }
    }
    private enum CodingKeys: String, CodingKey { case mode, sourceText, decisions, model, timing, usedTranslator, translatedText, clarification, route, reason, requestId }
}

struct RelayHTTPErrorBody: Decodable { let code: String; let error: String }

struct Phrase: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let english: String
    let dutch: String
}

struct SavedPhrase: Codable, Identifiable, Equatable {
    let id: UUID
    let english: String
    let dutch: String
    let savedAt: Date
}
