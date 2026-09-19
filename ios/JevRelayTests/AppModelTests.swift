import XCTest

actor StubRelay: RelayServing {
    var calls = 0
    let delay: Duration
    init(delay: Duration = .zero) { self.delay = delay }
    func interpret(_ turn: InterpretRequest) async throws -> InterpretResponse {
        calls += 1
        if delay != .zero { try? await Task.sleep(for: delay) }
        return try JSONDecoder().decode(InterpretResponse.self, from: responseData(route: "translate", translated: "Hallo", source: turn.text))
    }
    func deleteIdentity() async throws {}
    func callCount() -> Int { calls }
}

private enum DeletionStubError: LocalizedError {
    case failed
    var errorDescription: String? { "Identity deletion failed." }
}

actor DeletionStubRelay: RelayServing {
    let delay: Duration
    let deletionError: Error?
    private var deletionStarted = false

    init(delay: Duration = .zero, deletionError: Error? = nil) {
        self.delay = delay
        self.deletionError = deletionError
    }

    func interpret(_ turn: InterpretRequest) async throws -> InterpretResponse {
        try JSONDecoder().decode(InterpretResponse.self, from: responseData(route: "translate", translated: "Hallo", source: turn.text))
    }

    func deleteIdentity() async throws {
        deletionStarted = true
        if delay != .zero { try await Task.sleep(for: delay) }
        if let deletionError { throw deletionError }
    }

    func hasStartedDeletion() -> Bool { deletionStarted }
}

@MainActor
final class AppModelTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func tearDown() {
        temporaryURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        temporaryURLs = []
        super.tearDown()
    }

    private func configuration() -> ServiceConfiguration {
        ServiceConfiguration(
            supabaseURL: URL(string: "https://iliuldjetbxxsjykoqxm.supabase.co")!,
            publishableKey: "public",
            backendURL: URL(string: "https://iliuldjetbxxsjykoqxm.supabase.co/functions/v1/native-backend")!,
            privacyPolicyURL: nil,
            supportURL: nil
        )
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

    private func waitForResult(_ model: AppModel) async {
        for _ in 0..<30 {
            if model.result != nil { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testConsentPreventsNetworkUntilAccepted() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        let relay = StubRelay()
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay)
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

    func testLateResponseCannotOverwriteChangedInput() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "transmissionConsent.v1")
        let relay = StubRelay(delay: .milliseconds(80))
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay)
        model.sourceText = "Hello"; model.requestInterpretation()
        model.sourceText = "A new turn"
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertNil(model.result)
        XCTAssertFalse(model.isInterpreting)
    }

    func testContextAndToneEditsAlwaysInvalidatePlayableResult() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "transmissionConsent.v1")
        let relay = StubRelay()
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay)
        model.sourceText = "Hello"

        model.requestInterpretation()
        await waitForResult(model)
        XCTAssertTrue(model.canPlayResult)
        let stopsBeforeContextEdit = model.speaker.stopInvocationCount
        model.context = "A hotel guest speaks to a clerk."
        XCTAssertNil(model.result)
        XCTAssertFalse(model.canPlayResult)
        XCTAssertGreaterThan(model.speaker.stopInvocationCount, stopsBeforeContextEdit)

        model.requestInterpretation()
        await waitForResult(model)
        XCTAssertTrue(model.canPlayResult)
        let stopsBeforeToneEdit = model.speaker.stopInvocationCount
        model.tone = .formal
        XCTAssertNil(model.result)
        XCTAssertFalse(model.canPlayResult)
        XCTAssertGreaterThan(model.speaker.stopInvocationCount, stopsBeforeToneEdit)
    }
}

extension AppModelTests {
    private func eligibleModel() async -> (AppModel, UserDefaults, String) {
        let (defaults, suite) = defaults()
        defaults.set(true, forKey: "transmissionConsent.v1")
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: StubRelay())
        model.sourceText = "Hello"
        model.requestInterpretation()
        await waitForResult(model)
        XCTAssertTrue(model.canPlayResult)
        return (model, defaults, suite)
    }

    func testRequestingPlaybackReviewDoesNotSpeak() async {
        let (model, defaults, suite) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        let stopsBeforeReview = model.speaker.stopInvocationCount

        model.requestPlaybackReview()

        XCTAssertEqual(model.playbackReview?.sourceText, "Hello")
        XCTAssertEqual(model.playbackReview?.translatedText, "Hallo")
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeReview)
    }

    func testOnlyCurrentReviewedResultCanSpeak() async {
        let (model, defaults, suite) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        let stopsBeforeApproval = model.speaker.stopInvocationCount

        model.approveReviewAndPlay(UUID())
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeApproval)

        model.requestPlaybackReview()
        guard let staleToken = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        model.requestPlaybackReview()
        guard let currentToken = model.playbackReview?.id else { return XCTFail("Expected a current playback review") }
        model.approveReviewAndPlay(staleToken)
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeApproval)

        model.approveReviewAndPlay(currentToken)
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeApproval + 1)
        XCTAssertNil(model.playbackReview)
    }

    func testPlaybackReviewApprovalIsSingleUse() async {
        let (model, defaults, suite) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        model.requestPlaybackReview()
        guard let token = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let stopsBeforeApproval = model.speaker.stopInvocationCount

        model.approveReviewAndPlay(token)
        model.approveReviewAndPlay(token)

        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeApproval + 1)
    }

    func testEditAndResetInvalidatePlaybackReviewApproval() async {
        let (model, defaults, suite) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        model.requestPlaybackReview()
        guard let editToken = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let stopsBeforeEdit = model.speaker.stopInvocationCount

        model.context = "At a hotel"
        model.approveReviewAndPlay(editToken)

        XCTAssertNil(model.playbackReview)
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeEdit + 1)

        model.sourceText = "Hello"
        model.requestInterpretation()
        await waitForResult(model)
        model.requestPlaybackReview()
        guard let resetToken = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let stopsBeforeReset = model.speaker.stopInvocationCount
        model.resetSession()
        model.approveReviewAndPlay(resetToken)

        XCTAssertNil(model.playbackReview)
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeReset + 1)
    }
}


extension AppModelTests {
    private func waitForDeletionStart(_ relay: DeletionStubRelay) async {
        for _ in 0..<30 {
            if await relay.hasStartedDeletion() { return }
            await Task.yield()
        }
        XCTFail("Deletion did not begin")
    }

    func testPendingDeletionImmediatelyStopsPlaybackAndInvalidatesReview() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "transmissionConsent.v1")
        let relay = DeletionStubRelay(delay: .milliseconds(200))
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay)
        model.sourceText = "Hello"
        model.requestInterpretation()
        await waitForResult(model)
        model.requestPlaybackReview()
        guard let token = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let stopsBeforeDeletion = model.speaker.stopInvocationCount

        let deletion = Task { await model.deleteIdentity(clearSavedPhrases: false) }
        await waitForDeletionStart(relay)

        XCTAssertNil(model.playbackReview)
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeDeletion + 1)
        model.approveReviewAndPlay(token)
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeDeletion + 1)
        XCTAssertTrue(model.hasConsent)
        await deletion.value
    }

    func testFailedDeletionKeepsConsentButInvalidatesReview() async {
        let (defaults, suite) = defaults(); defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "transmissionConsent.v1")
        let relay = DeletionStubRelay(deletionError: DeletionStubError.failed)
        let model = AppModel(configuration: configuration(), defaults: defaults, phrasebook: phrasebook(), api: relay)
        model.sourceText = "Hello"
        model.requestInterpretation()
        await waitForResult(model)
        model.requestPlaybackReview()
        guard let token = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let stopsBeforeDeletion = model.speaker.stopInvocationCount

        await model.deleteIdentity(clearSavedPhrases: false)

        XCTAssertNil(model.playbackReview)
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeDeletion + 1)
        XCTAssertTrue(model.hasConsent)
        XCTAssertEqual(model.result?.translatedText, "Hallo")
        model.approveReviewAndPlay(token)
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeDeletion + 1)
        XCTAssertEqual(model.deletionMessage, "Identity deletion failed.")
    }

    func testBlockedInterpretationRequestInvalidatesPlaybackReview() async {
        let (model, defaults, suite) = await eligibleModel()
        defer { defaults.removePersistentDomain(forName: suite) }
        model.requestPlaybackReview()
        guard let token = model.playbackReview?.id else { return XCTFail("Expected a playback review") }
        let stopsBeforeRequest = model.speaker.stopInvocationCount
        defaults.set(false, forKey: "transmissionConsent.v1")

        model.requestInterpretation()

        XCTAssertTrue(model.showingConsent)
        XCTAssertNil(model.playbackReview)
        model.approveReviewAndPlay(token)
        XCTAssertEqual(model.speaker.stopInvocationCount, stopsBeforeRequest)
    }
}
