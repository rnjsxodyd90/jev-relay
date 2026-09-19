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
