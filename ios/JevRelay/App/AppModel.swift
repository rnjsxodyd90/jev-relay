import Foundation
import Combine
import UIKit

enum AppTab: Hashable {
    case workbench, phrases, settings
}

struct PlaybackReview: Identifiable {
    let id: UUID
    let resultGeneration: UUID
    let sourceText: String
    let translatedText: String
}

@MainActor
final class AppModel: ObservableObject {
    @Published var sourceText = "" { didSet { if sourceText != oldValue { invalidateTurn() } } }
    @Published var context = "" { didSet { if context != oldValue { invalidateTurn() } } }
    @Published var tone: ToneMode = .automatic { didSet { if tone != oldValue { invalidateTurn() } } }
    @Published private(set) var result: InterpretResponse?
    @Published private(set) var isInterpreting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var credentialMessage: String?
    @Published private(set) var playbackReview: PlaybackReview?
    @Published private(set) var isJevConfigured = false
    @Published private(set) var isNebiusConfigured = false
    @Published var showingConsent = false
    @Published var showingResetConfirmation = false
    @Published var phraseSearch = ""
    @Published var selectedTab: AppTab = .workbench
    @Published var showingClearAllPhrases = false

    let configuration: ServiceConfiguration
    let phrasebook: PhrasebookStore
    let speechCapture = SpeechCapture()
    let speaker = DutchSpeaker()
    private let api: any RelayServing
    private let credentials: any ProviderKeyStoring
    private let defaults: UserDefaults
    private var interpretTask: Task<Void, Never>?
    private var revision = UUID()
    private var resultGeneration: UUID?
    private var consumedReviewToken: UUID?
    private let consentKey = "transmissionConsent.byok.v2"

    init(
        configuration: ServiceConfiguration = .current(),
        defaults: UserDefaults = .standard,
        phrasebook: PhrasebookStore? = nil,
        api: (any RelayServing)? = nil,
        credentials: any ProviderKeyStoring = ProviderKeychainStore()
    ) {
        self.configuration = configuration
        self.defaults = defaults
        self.phrasebook = phrasebook ?? PhrasebookStore()
        self.credentials = credentials
        self.api = api ?? DirectProviderClient(configuration: configuration, credentials: credentials)
        refreshProviderStatus()
        speechCapture.onTranscript = { [weak self] transcript in self?.sourceText = transcript }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleDidEnterBackground() }
        }
    }

    var hasConsent: Bool { defaults.bool(forKey: consentKey) }
    var hasRequiredProviderKeys: Bool { isJevConfigured && isNebiusConfigured }
    var canPlayResult: Bool {
        guard hasConsent, hasRequiredProviderKeys, let result else { return false }
        return (result.route == .memory || result.route == .translate) && !result.translatedText.isEmpty
    }

    func isProviderConfigured(_ provider: ProviderKind) -> Bool {
        switch provider {
        case .jev: return isJevConfigured
        case .nebius: return isNebiusConfigured
        }
    }

    @discardableResult
    func saveProviderKey(_ key: String, for provider: ProviderKind) -> Bool {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            credentialMessage = "Enter a key before saving."
            return false
        }
        // Cancel before a potentially blocking Keychain write, not after it.
        invalidateCurrentResultAndWork()
        do {
            try credentials.save(cleanKey, for: provider)
            credentialsDidChange()
            credentialMessage = "The \(provider.displayName) key is stored in Keychain on this device."
            return true
        } catch {
            credentialMessage = "The \(provider.displayName) key could not be stored in Keychain."
            return false
        }
    }

    @discardableResult
    func clearProviderKey(_ provider: ProviderKind) -> Bool {
        // Removing a key must stop pending use even if Keychain subsequently rejects deletion.
        invalidateCurrentResultAndWork()
        do {
            try credentials.clear(provider)
            credentialsDidChange()
            credentialMessage = "The \(provider.displayName) key was removed from this device."
            return true
        } catch {
            credentialMessage = "The \(provider.displayName) key could not be removed from Keychain."
            return false
        }
    }

    func clearCredentialMessage() { credentialMessage = nil }

    func requestInterpretation() {
        errorMessage = nil
        speechCapture.stop()
        invalidatePlaybackReview()
        refreshProviderStatus()
        guard hasRequiredProviderKeys else {
            errorMessage = missingKeysMessage
            return
        }
        guard hasConsent else {
            showingConsent = true
            return
        }
        beginInterpretation()
    }

    func acceptConsent() {
        refreshProviderStatus()
        guard hasRequiredProviderKeys else {
            showingConsent = false
            errorMessage = missingKeysMessage
            return
        }
        defaults.set(true, forKey: consentKey)
        showingConsent = false
        beginInterpretation()
    }

    func declineConsent() { showingConsent = false }

    func revokeConsent() {
        defaults.set(false, forKey: consentKey)
        showingConsent = false
        invalidateCurrentResultAndWork()
    }

    private func beginInterpretation() {
        refreshProviderStatus()
        guard hasRequiredProviderKeys else {
            errorMessage = missingKeysMessage
            return
        }
        guard hasConsent else {
            showingConsent = true
            return
        }
        interpretTask?.cancel()
        speaker.stop()
        speechCapture.stop()
        invalidatePlaybackReview()
        resultGeneration = nil
        result = nil
        let turn: InterpretRequest
        do {
            turn = try InterpretRequest(text: sourceText, context: context, tone: tone)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let requestRevision = revision
        isInterpreting = true
        interpretTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await api.interpret(turn)
                guard !Task.isCancelled,
                      self.revision == requestRevision,
                      self.hasConsent,
                      self.hasRequiredProviderKeys,
                      self.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == turn.text else { return }
                self.result = response
                self.resultGeneration = UUID()
                self.isInterpreting = false
                UIAccessibility.post(notification: .announcement, argument: self.statusAnnouncement(for: response))
            } catch is CancellationError {
                if self.revision == requestRevision { self.isInterpreting = false }
            } catch {
                guard !Task.isCancelled, self.revision == requestRevision else { return }
                self.errorMessage = self.safeErrorMessage(error)
                self.result = nil
                self.resultGeneration = nil
                self.isInterpreting = false
                self.speaker.stop()
                UIAccessibility.post(notification: .announcement, argument: self.errorMessage)
            }
        }
    }

    func cancelInterpretation() {
        interpretTask?.cancel()
        interpretTask = nil
        revision = UUID()
        isInterpreting = false
        invalidatePlaybackReview()
    }

    func requestPlaybackReview() {
        guard canPlayResult, let result, let resultGeneration else { return }
        playbackReview = PlaybackReview(
            id: UUID(),
            resultGeneration: resultGeneration,
            sourceText: result.sourceText,
            translatedText: result.translatedText
        )
    }

    func dismissPlaybackReview() { playbackReview = nil }

    func approveReviewAndPlay(_ token: UUID) {
        guard let playbackReview else { return }
        guard playbackReview.id == token else { return }
        guard consumedReviewToken != playbackReview.id,
              let result,
              resultGeneration == playbackReview.resultGeneration,
              result.sourceText == playbackReview.sourceText,
              result.translatedText == playbackReview.translatedText,
              canPlayResult else {
            self.playbackReview = nil
            return
        }
        consumedReviewToken = playbackReview.id
        self.playbackReview = nil
        speaker.speak(result.translatedText)
    }

    func saveResult() {
        guard canPlayResult, let result else { return }
        phrasebook.save(english: result.sourceText, dutch: result.translatedText)
    }

    func usePhrase(_ phrase: Phrase) { resetSession(); sourceText = phrase.english; result = nil }
    func useSavedPhrase(_ phrase: SavedPhrase) { resetSession(); sourceText = phrase.english }

    func resetSession() {
        interpretTask?.cancel()
        interpretTask = nil
        speechCapture.stop()
        speaker.stop()
        revision = UUID()
        sourceText = ""
        context = ""
        tone = .automatic
        result = nil
        errorMessage = nil
        isInterpreting = false
        resultGeneration = nil
        invalidatePlaybackReview()
        UIAccessibility.post(notification: .announcement, argument: "Session reset. No transcript was saved.")
    }

    private var missingKeysMessage: String {
        let missing = ProviderKind.allCases.filter { !isProviderConfigured($0) }.map(\.displayName)
        return "Add your \(missing.joined(separator: " and ")) API key\(missing.count == 1 ? "" : "s") in Settings before translating. Nothing was sent."
    }

    private func refreshProviderStatus() {
        isJevConfigured = storedKeyExists(for: .jev)
        isNebiusConfigured = storedKeyExists(for: .nebius)
    }

    private func storedKeyExists(for provider: ProviderKind) -> Bool {
        do {
            return try credentials.load(provider)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        } catch {
            return false
        }
    }

    private func credentialsDidChange() {
        invalidateCurrentResultAndWork()
        refreshProviderStatus()
    }

    private func invalidateCurrentResultAndWork() {
        interpretTask?.cancel()
        interpretTask = nil
        revision = UUID()
        isInterpreting = false
        speechCapture.stop()
        speaker.stop()
        result = nil
        resultGeneration = nil
        errorMessage = nil
        invalidatePlaybackReview()
    }

    private func handleDidEnterBackground() {
        let hadInFlightRequest = isInterpreting
        interpretTask?.cancel()
        interpretTask = nil
        revision = UUID()
        isInterpreting = false
        speechCapture.stop()
        speaker.stop()
        if hadInFlightRequest {
            result = nil
            resultGeneration = nil
        }
        invalidatePlaybackReview()
    }

    private func invalidateTurn() {
        revision = UUID()
        interpretTask?.cancel()
        interpretTask = nil
        isInterpreting = false
        speaker.stop()
        result = nil
        resultGeneration = nil
        errorMessage = nil
        invalidatePlaybackReview()
    }

    private func invalidatePlaybackReview() {
        playbackReview = nil
        consumedReviewToken = nil
    }

    private func safeErrorMessage(_ error: Error) -> String {
        var message = error.localizedDescription
        for provider in ProviderKind.allCases {
            if let key = try? credentials.load(provider), !key.isEmpty {
                message = message.replacingOccurrences(of: key, with: "[redacted]")
            }
        }
        return message
    }

    private func statusAnnouncement(for response: InterpretResponse) -> String {
        switch response.route {
        case .memory, .translate: return "Dutch result ready for review. Playback is manual."
        case .clarify: return "More context is needed before translation."
        case .review: return "The turn needs review. Nothing is approved for playback."
        }
    }
}
