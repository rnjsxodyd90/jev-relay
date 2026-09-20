import XCTest
import UIKit

private final class TestProviderKeyStore: ProviderKeyStoring {
    private var jevKey: String?
    private var nebiusKey: String?

    init(jev: String? = nil, nebius: String? = nil) {
        jevKey = jev
        nebiusKey = nebius
    }

    func load(_ provider: ProviderKind) -> String? {
        switch provider {
        case .jev: return jevKey
        case .nebius: return nebiusKey
        }
    }

    func save(_ key: String, for provider: ProviderKind) {
        switch provider {
        case .jev: jevKey = key
        case .nebius: nebiusKey = key
        }
    }

    func clear(_ provider: ProviderKind) {
        switch provider {
        case .jev: jevKey = nil
        case .nebius: nebiusKey = nil
        }
    }
}

private enum StubError: LocalizedError {
    case leaked(String)
    var errorDescription: String? {
        switch self {
        case let .leaked(secret): return "Provider rejected credential \(secret)."
        }
    }
}

private actor StubRelay: RelayServing {
    private var calls = 0
    private let delay: Duration
    private let error: Error?

    init(delay: Duration = .zero, error: Error? = nil) {
        self.delay = delay
        self.error = error
    }

    func interpret(_ turn: InterpretRequest) async throws -> InterpretResponse {
        calls += 1
        if delay != .zero { try await Task.sleep(for: delay) }
        if let error { throw error }
        return try JSONDecoder().decode(
            InterpretResponse.self,
            from: responseData(route: "translate", translated: "Hallo", source: turn.text)
        )
    }

    func callCount() -> Int { calls }
}

@MainActor
final class AppModelTests: XCTestCase {
    private let v2ConsentKey = "transmissionConsent.byok.v2"
    private var temporaryURLs: [URL] = []

    override func tearDown() {
        temporaryURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        temporaryURLs = []
        super.tearDown()
    }

    private func configuration() -> ServiceConfiguration {
        ServiceConfiguration(privacyPolicyURL: nil, supportURL: nil)
    }

    private func phrasebook() -> PhrasebookStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "AppModelTests-\(UUID())", directoryHint: .isDirectory)
        temporaryURLs.append(root)
        return PhrasebookStore(storageURL: root.appending(path: "saved.json"), builtIn: [])
    }

    private func defaults() -> (UserDefaults, String) {
        let suite = "AppModelTests.\(UUID())"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    private func configuredStore() -> TestProviderKeyStore {
        TestProviderKeyStore(jev: "test-jev-key", nebius: "test-nebius-key")
    }

    private func waitForResult(_ model: AppModel) async {
        for _ in 0..<50 {
            if model.result != nil || model.errorMessage != nil { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func eligibleModel() async -> (AppModel, UserDefaults, String, TestProviderKeyStore) {
        let (defaults, suite) = defaults()
        defaults.set(true, forKey: v2ConsentKey)
        let store = configuredStore()
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: StubRelay(), credentials: store)
        model.sourceText = "Hello"
        model.requestInterpretation()
        await waitForResult(model)
        XCTAssertTrue(model.canPlayResult)
        return (model, defaults, suite, store)
    }

    func testMissingKeysPreventConsentAndNetworkCall() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        let relay = StubRelay()
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay, credentials: TestProviderKeyStore())
        model.sourceText = "Hello"

        model.requestInterpretation()

        XCTAssertFalse(model.showingConsent)
        XCTAssertTrue(model.errorMessage?.contains("Settings") == true)
        let callCount = await relay.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testConsentPreventsNetworkUntilAcceptedWithBothKeys() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        let relay = StubRelay()
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay, credentials: configuredStore())
        model.sourceText = "Hello"

        model.requestInterpretation()
        XCTAssertTrue(model.showingConsent)
        let callsBeforeConsent = await relay.callCount()
        XCTAssertEqual(callsBeforeConsent, 0)

        model.acceptConsent()
        await waitForResult(model)
        let callsAfterConsent = await relay.callCount()
        XCTAssertEqual(callsAfterConsent, 1)
        XCTAssertEqual(model.result?.translatedText, "Hallo")
    }

    func testOldV1ConsentDoesNotCount() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "transmissionConsent.v1")
        let relay = StubRelay()
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay, credentials: configuredStore())
        model.sourceText = "Hello"

        model.requestInterpretation()

        XCTAssertFalse(model.hasConsent)
        XCTAssertTrue(model.showingConsent)
        let callCount = await relay.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testAcceptConsentRechecksKeysAndCannotBypassRemoval() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        let relay = StubRelay()
        let store = configuredStore()
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay, credentials: store)
        model.sourceText = "Hello"
        model.requestInterpretation()
        XCTAssertTrue(model.showingConsent)

        store.clear(.nebius)
        XCTAssertTrue(model.hasRequiredProviderKeys, "The published status is intentionally stale until consent acceptance rechecks secure storage.")
        model.acceptConsent()

        XCTAssertFalse(model.hasConsent)
        XCTAssertFalse(model.showingConsent)
        let callCount = await relay.callCount()
        XCTAssertEqual(callCount, 0)
        XCTAssertTrue(model.errorMessage?.contains("Nebius") == true)
    }

    func testSavingAndReplacingKeysNeverStartsNetworkWork() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        let relay = StubRelay()
        let store = TestProviderKeyStore()
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay, credentials: store)

        XCTAssertTrue(model.saveProviderKey("fake-jev", for: .jev))
        XCTAssertTrue(model.saveProviderKey("fake-nebius", for: .nebius))
        XCTAssertTrue(model.saveProviderKey("replacement-jev", for: .jev))

        XCTAssertTrue(model.hasRequiredProviderKeys)
        let callCount = await relay.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testLateResponseCannotOverwriteChangedInput() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: v2ConsentKey)
        let relay = StubRelay(delay: .milliseconds(80))
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay, credentials: configuredStore())
        model.sourceText = "Hello"
        model.requestInterpretation()
        model.sourceText = "A new turn"

        try? await Task.sleep(for: .milliseconds(150))

        XCTAssertNil(model.result)
        XCTAssertFalse(model.isInterpreting)
    }

    func testContextAndToneEditsAlwaysInvalidatePlayableResult() async {
        let (model, defaults, suite, _) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }

        let stopsBeforeContextEdit = model.speaker.stopInvocationCount
        model.context = "A hotel guest speaks to a clerk."
        XCTAssertNil(model.result)
        XCTAssertFalse(model.canPlayResult)
        XCTAssertGreaterThan(model.speaker.stopInvocationCount, stopsBeforeContextEdit)

        model.context = ""
        model.requestInterpretation()
        await waitForResult(model)
        XCTAssertTrue(model.canPlayResult)
        let stopsBeforeToneEdit = model.speaker.stopInvocationCount
        model.tone = .formal
        XCTAssertNil(model.result)
        XCTAssertFalse(model.canPlayResult)
        XCTAssertGreaterThan(model.speaker.stopInvocationCount, stopsBeforeToneEdit)
    }

    func testRequestingPlaybackReviewDoesNotSpeak() async {
        let (model, defaults, suite, _) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        let speaksBeforeReview = model.speaker.speakInvocationCount

        model.requestPlaybackReview()

        XCTAssertEqual(model.playbackReview?.sourceText, "Hello")
        XCTAssertEqual(model.playbackReview?.translatedText, "Hallo")
        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeReview)
    }

    func testOnlyCurrentReviewedResultCanSpeak() async {
        let (model, defaults, suite, _) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        let speaksBeforeApproval = model.speaker.speakInvocationCount

        model.approveReviewAndPlay(UUID())
        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeApproval)

        model.requestPlaybackReview()
        guard let staleToken = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        model.requestPlaybackReview()
        guard let currentReview = model.playbackReview else { return XCTFail("Expected a current playback review") }
        model.approveReviewAndPlay(staleToken)
        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeApproval)
        XCTAssertEqual(model.playbackReview?.id, currentReview.id)

        model.approveReviewAndPlay(currentReview.id)
        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeApproval + 1)
        XCTAssertNil(model.playbackReview)
    }

    func testPlaybackReviewApprovalIsSingleUse() async {
        let (model, defaults, suite, _) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        model.requestPlaybackReview()
        guard let token = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let speaksBeforeApproval = model.speaker.speakInvocationCount

        model.approveReviewAndPlay(token)
        model.approveReviewAndPlay(token)

        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeApproval + 1)
    }

    func testEditAndResetInvalidatePlaybackReviewApproval() async {
        let (model, defaults, suite, _) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        model.requestPlaybackReview()
        guard let editToken = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let speaksBeforeEdit = model.speaker.speakInvocationCount

        model.context = "At a hotel"
        model.approveReviewAndPlay(editToken)
        XCTAssertNil(model.playbackReview)
        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeEdit)

        model.sourceText = "Hello"
        model.requestInterpretation()
        await waitForResult(model)
        model.requestPlaybackReview()
        guard let resetToken = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let speaksBeforeReset = model.speaker.speakInvocationCount
        model.resetSession()
        model.approveReviewAndPlay(resetToken)
        XCTAssertNil(model.playbackReview)
        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeReset)
    }

    func testRemovingKeyRevokesPlaybackAndInvalidatesResult() async {
        let (model, defaults, suite, _) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        model.requestPlaybackReview()
        guard let token = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let speaksBeforeRemoval = model.speaker.speakInvocationCount
        let stopsBeforeRemoval = model.speaker.stopInvocationCount

        XCTAssertTrue(model.clearProviderKey(.jev))
        model.approveReviewAndPlay(token)

        XCTAssertFalse(model.hasRequiredProviderKeys)
        XCTAssertNil(model.result)
        XCTAssertNil(model.playbackReview)
        XCTAssertFalse(model.canPlayResult)
        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeRemoval)
        XCTAssertGreaterThan(model.speaker.stopInvocationCount, stopsBeforeRemoval)
    }

    func testReplacingKeyCancelsInFlightInterpretation() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: v2ConsentKey)
        let relay = StubRelay(delay: .milliseconds(150))
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay, credentials: configuredStore())
        model.sourceText = "Hello"
        model.requestInterpretation()
        XCTAssertTrue(model.isInterpreting)

        XCTAssertTrue(model.saveProviderKey("replacement-fake-jev", for: .jev))
        try? await Task.sleep(for: .milliseconds(220))

        XCTAssertFalse(model.isInterpreting)
        XCTAssertNil(model.result)
        let callCount = await relay.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testBackgroundRetainsCompletedResultButRequiresFreshPlaybackReview() async {
        let (model, defaults, suite, _) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        model.requestPlaybackReview()
        guard let staleToken = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let speaksBeforeBackground = model.speaker.speakInvocationCount

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        await Task.yield()

        XCTAssertEqual(model.result?.translatedText, "Hallo", "A completed paid result should remain available after backgrounding.")
        XCTAssertTrue(model.canPlayResult)
        XCTAssertNil(model.playbackReview)
        model.approveReviewAndPlay(staleToken)
        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeBackground, "A review token created before backgrounding must not play.")

        model.requestPlaybackReview()
        guard let freshToken = model.playbackReview?.id else { return XCTFail("Expected a fresh playback review") }
        XCTAssertNotEqual(freshToken, staleToken)
        model.approveReviewAndPlay(freshToken)
        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeBackground + 1)
    }

    func testEnteringBackgroundCancelsInFlightWorkAndPlayback() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: v2ConsentKey)
        let relay = StubRelay(delay: .milliseconds(150))
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay, credentials: configuredStore())
        model.sourceText = "Hello"
        let speechStopsBefore = model.speechCapture.stopInvocationCount
        let playbackStopsBefore = model.speaker.stopInvocationCount
        model.requestInterpretation()
        XCTAssertTrue(model.isInterpreting)

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(220))

        XCTAssertFalse(model.isInterpreting)
        XCTAssertNil(model.result)
        XCTAssertNil(model.playbackReview)
        XCTAssertGreaterThan(model.speechCapture.stopInvocationCount, speechStopsBefore)
        XCTAssertGreaterThan(model.speaker.stopInvocationCount, playbackStopsBefore)
    }

    func testRevokingConsentInvalidatesResultAndReviewToken() async {
        let (model, defaults, suite, _) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        model.requestPlaybackReview()
        guard let token = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let speaksBeforeRevoke = model.speaker.speakInvocationCount

        model.revokeConsent()
        model.approveReviewAndPlay(token)

        XCTAssertFalse(model.hasConsent)
        XCTAssertNil(model.result)
        XCTAssertNil(model.playbackReview)
        XCTAssertFalse(model.canPlayResult)
        XCTAssertEqual(model.speaker.speakInvocationCount, speaksBeforeRevoke)
    }

    func testErrorsNeverEchoStoredKeys() async {
        let secret = "super-secret-fake-key"
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: v2ConsentKey)
        let relay = StubRelay(error: StubError.leaked(secret))
        let store = TestProviderKeyStore(jev: secret, nebius: "other-fake-key")
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay, credentials: store)
        model.sourceText = "Hello"

        model.requestInterpretation()
        await waitForResult(model)

        XCTAssertFalse(model.errorMessage?.contains(secret) == true)
        XCTAssertTrue(model.errorMessage?.contains("[redacted]") == true)
    }
}
