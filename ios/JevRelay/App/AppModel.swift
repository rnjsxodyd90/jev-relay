import Foundation
import Combine
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var sourceText = "" { didSet { if sourceText != oldValue { invalidateTurn() } } }
    @Published var context = "" { didSet { if context != oldValue { invalidateTurn() } } }
    @Published var tone: ToneMode = .automatic { didSet { if tone != oldValue { invalidateTurn() } } }
    @Published private(set) var result: InterpretResponse?
    @Published private(set) var isInterpreting = false
    @Published private(set) var errorMessage: String?
    @Published var showingConsent = false
    @Published var showingResetConfirmation = false
    @Published var deletionMessage: String?
    @Published var phraseSearch = ""
    @Published var showingIdentityDeletion = false
    @Published var showingClearAllPhrases = false
    @Published var isDeletingIdentity = false

    let configuration: ServiceConfiguration
    let phrasebook: PhrasebookStore
    let speechCapture = SpeechCapture()
    let speaker = DutchSpeaker()
    private let api: any RelayServing
    private let defaults: UserDefaults
    private var interpretTask: Task<Void, Never>?
    private var revision = UUID()
    private let consentKey = "transmissionConsent.v1"

    init(configuration: ServiceConfiguration = .current(), defaults: UserDefaults = .standard, phrasebook: PhrasebookStore? = nil, api: (any RelayServing)? = nil) {
        self.configuration = configuration; self.defaults = defaults
        self.phrasebook = phrasebook ?? PhrasebookStore()
        self.api = api ?? RelayAPIClient(configuration: configuration)
        speechCapture.onTranscript = { [weak self] transcript in self?.sourceText = transcript }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.speechCapture.stop(); self?.speaker.stop() }
        }
    }

    var hasConsent: Bool { defaults.bool(forKey: consentKey) }
    var canPlayResult: Bool { guard let result else { return false }; return (result.route == .memory || result.route == .translate) && !result.translatedText.isEmpty }

    func requestInterpretation() {
        errorMessage = nil
        guard configuration.isServiceAvailable else { errorMessage = configuration.missingServiceMessage; return }
        guard hasConsent else { showingConsent = true; return }
        beginInterpretation()
    }

    func acceptConsent() { defaults.set(true, forKey: consentKey); showingConsent = false; beginInterpretation() }
    func declineConsent() { showingConsent = false }
    func revokeConsent() { defaults.set(false, forKey: consentKey); interpretTask?.cancel(); isInterpreting = false; speaker.stop() }

    private func beginInterpretation() {
        interpretTask?.cancel(); speaker.stop(); speechCapture.stop()
        let turn: InterpretRequest
        do { turn = try InterpretRequest(text: sourceText, context: context, tone: tone) }
        catch { errorMessage = error.localizedDescription; return }
        let requestRevision = revision
        isInterpreting = true; result = nil
        interpretTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await api.interpret(turn)
                guard !Task.isCancelled, self.revision == requestRevision, self.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == turn.text else { return }
                self.result = response; self.isInterpreting = false
                UIAccessibility.post(notification: .announcement, argument: self.statusAnnouncement(for: response))
            } catch is CancellationError { if self.revision == requestRevision { self.isInterpreting = false } }
            catch {
                guard !Task.isCancelled, self.revision == requestRevision else { return }
                self.errorMessage = error.localizedDescription; self.result = nil; self.isInterpreting = false; self.speaker.stop()
                UIAccessibility.post(notification: .announcement, argument: self.errorMessage)
            }
        }
    }

    func cancelInterpretation() { interpretTask?.cancel(); revision = UUID(); isInterpreting = false }
    func playResult() { guard canPlayResult, let result else { return }; speaker.speak(result.translatedText) }
    func saveResult() { guard canPlayResult, let result else { return }; phrasebook.save(english: result.sourceText, dutch: result.translatedText) }

    func usePhrase(_ phrase: Phrase) { resetSession(); sourceText = phrase.english; result = nil }
    func useSavedPhrase(_ phrase: SavedPhrase) { resetSession(); sourceText = phrase.english }

    func resetSession() {
        interpretTask?.cancel(); speechCapture.stop(); speaker.stop(); revision = UUID()
        sourceText = ""; context = ""; tone = .automatic; result = nil; errorMessage = nil; isInterpreting = false
        UIAccessibility.post(notification: .announcement, argument: "Session reset. No transcript was saved.")
    }

    func deleteIdentity(clearSavedPhrases: Bool) async {
        deletionMessage = nil
        do {
            try await api.deleteIdentity()
            defaults.set(false, forKey: consentKey)
            if clearSavedPhrases { phrasebook.deleteAll() }
            resetSession()
            deletionMessage = clearSavedPhrases ? "Cloud identity and saved local phrases were deleted." : "Cloud identity was deleted. Saved local phrases remain on this device."
        } catch { deletionMessage = error.localizedDescription }
    }

    private func invalidateTurn() {
        revision = UUID()
        interpretTask?.cancel()
        isInterpreting = false
        speaker.stop()
        result = nil
        errorMessage = nil
    }
    private func statusAnnouncement(for response: InterpretResponse) -> String {
        switch response.route {
        case .memory, .translate: return "Dutch result ready for review. Playback is manual."
        case .clarify: return "More context is needed before translation."
        case .review: return "The turn needs review. Nothing is approved for playback."
        }
    }
}
