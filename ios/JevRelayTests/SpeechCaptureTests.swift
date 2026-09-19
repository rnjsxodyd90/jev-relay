import Speech
import XCTest

actor SpeechPermissionGate {
    private var continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>?
    private var pending: SFSpeechRecognizerAuthorizationStatus?
    private(set) var requests = 0

    func wait() async -> SFSpeechRecognizerAuthorizationStatus {
        requests += 1
        if let pending { self.pending = nil; return pending }
        return await withCheckedContinuation { continuation = $0 }
    }

    func resume(_ status: SFSpeechRecognizerAuthorizationStatus) {
        if let continuation { self.continuation = nil; continuation.resume(returning: status) }
        else { pending = status }
    }
}

actor BooleanPermissionGate {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var pending: Bool?
    func wait() async -> Bool {
        if let pending { self.pending = nil; return pending }
        return await withCheckedContinuation { continuation = $0 }
    }
    func resume(_ value: Bool) {
        if let continuation { self.continuation = nil; continuation.resume(returning: value) }
        else { pending = value }
    }
}

@MainActor
final class SpeechCaptureTests: XCTestCase {
    func testSecondTapInvalidatesPendingPermissionStart() async {
        let gate = SpeechPermissionGate()
        let capture = SpeechCapture(
            recognizer: nil,
            speechAuthorizationProvider: { await gate.wait() },
            microphoneAuthorizationProvider: { true },
            isApplicationActive: { true }
        )

        let pendingStart = Task { await capture.toggle() }
        for _ in 0..<20 where !capture.isStarting { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertTrue(capture.isStarting)
        await capture.toggle()
        await gate.resume(.authorized)
        await pendingStart.value

        XCTAssertFalse(capture.isStarting)
        XCTAssertFalse(capture.isRecording)
        let requestCount = await gate.requests
        XCTAssertEqual(requestCount, 1)
    }

    func testCancellationDuringMicrophonePermissionCannotActivateRecording() async {
        let microphoneGate = BooleanPermissionGate()
        let capture = SpeechCapture(
            recognizer: nil,
            speechAuthorizationProvider: { .authorized },
            microphoneAuthorizationProvider: { await microphoneGate.wait() },
            isApplicationActive: { true }
        )

        let pendingStart = Task { await capture.toggle() }
        for _ in 0..<20 where !capture.isStarting { try? await Task.sleep(for: .milliseconds(5)) }
        await capture.toggle()
        await microphoneGate.resume(true)
        await pendingStart.value

        XCTAssertFalse(capture.isStarting)
        XCTAssertFalse(capture.isRecording)
    }

    func testInactiveLifecycleAfterPermissionCannotActivateRecording() async {
        let gate = SpeechPermissionGate()
        var isActive = true
        let capture = SpeechCapture(
            recognizer: nil,
            speechAuthorizationProvider: { await gate.wait() },
            microphoneAuthorizationProvider: { true },
            isApplicationActive: { isActive }
        )

        let pendingStart = Task { await capture.toggle() }
        for _ in 0..<20 where !capture.isStarting { try? await Task.sleep(for: .milliseconds(5)) }
        isActive = false
        await gate.resume(.authorized)
        await pendingStart.value

        XCTAssertFalse(capture.isStarting)
        XCTAssertFalse(capture.isRecording)
    }
}
