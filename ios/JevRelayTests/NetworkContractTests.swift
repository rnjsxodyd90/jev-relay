import Foundation
import XCTest

final class Locked<Value> {
    private let lock = NSLock()
    private var value: Value
    init(_ value: Value) { self.value = value }
    func update<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock(); defer { lock.unlock() }
        return try body(&value)
    }
    func read<Result>(_ body: (Value) throws -> Result) rethrows -> Result {
        lock.lock(); defer { lock.unlock() }
        return try body(value)
    }
}

final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var storedHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func setHandler(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) {
        lock.lock(); storedHandler = handler; lock.unlock()
    }

    static func clearHandler() {
        lock.lock(); storedHandler = nil; lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock(); let handler = Self.storedHandler; Self.lock.unlock()
        do {
            let (response, data) = try XCTUnwrap(handler)(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty { client?.urlProtocol(self, didLoad: data) }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class MemoryCredentialStore: CredentialStoring {
    private let lock = NSLock()
    private var value: AuthTokens?
    init(_ value: AuthTokens? = nil) { self.value = value }
    func save(_ tokens: AuthTokens) { lock.lock(); value = tokens; lock.unlock() }
    func load() -> AuthTokens? { lock.lock(); defer { lock.unlock() }; return value }
    func clear() { lock.lock(); value = nil; lock.unlock() }
}

final class NetworkContractTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.clearHandler()
        super.tearDown()
    }

    private func configuration() -> ServiceConfiguration {
        ServiceConfiguration(
            supabaseURL: URL(string: "https://iliuldjetbxxsjykoqxm.supabase.co")!,
            publishableKey: "publishable",
            backendURL: URL(string: "https://iliuldjetbxxsjykoqxm.supabase.co/functions/v1/native-backend")!,
            privacyPolicyURL: nil,
            supportURL: nil
        )
    }

    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }

    private func response(for request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
    }

    func testUnauthorizedInterpretRefreshesForNextActionWithoutRepeatingAndUsesIdempotencyKeys() async throws {
        let credentials = MemoryCredentialStore(AuthTokens(accessToken: "stale-access", refreshToken: "refresh-token", expiresAt: Date().addingTimeInterval(3_600)))
        struct State { var interpretRequests: [URLRequest] = []; var refreshCount = 0; var signupCount = 0 }
        let state = Locked(State())
        MockURLProtocol.setHandler { [self] request in
            try state.update { state in
                switch request.url!.path {
                case "/functions/v1/native-backend/interpret":
                    state.interpretRequests.append(request)
                    if request.value(forHTTPHeaderField: "Authorization") == "Bearer stale-access" {
                        return (response(for: request, status: 401), Data("{\"code\":\"invalid_jwt\",\"error\":\"Invalid JWT\"}".utf8))
                    }
                    return (response(for: request, status: 200), responseData(route: "translate", translated: "Hallo", source: "Hello"))
                case "/auth/v1/token":
                    state.refreshCount += 1
                    return (response(for: request, status: 200), Data("{\"access_token\":\"fresh-access\",\"refresh_token\":\"fresh-refresh\",\"expires_in\":3600}".utf8))
                case "/auth/v1/signup":
                    state.signupCount += 1
                    return (response(for: request, status: 500), Data())
                default:
                    throw URLError(.badURL)
                }
            }
        }

        let client = RelayAPIClient(configuration: configuration(), session: session(), credentials: credentials)
        let turn = try InterpretRequest(text: "Hello", context: "", tone: .automatic)
        do {
            _ = try await client.interpret(turn)
            XCTFail("The first explicit interpretation should surface the 401.")
        } catch let error as RelayClientError {
            XCTAssertEqual(error, .unauthorized)
        }

        let firstSnapshot = state.read { $0 }
        XCTAssertEqual(firstSnapshot.interpretRequests.count, 1, "A 401 must never automatically repeat interpretation.")
        XCTAssertEqual(firstSnapshot.refreshCount, 1)
        XCTAssertEqual(firstSnapshot.signupCount, 0)
        XCTAssertEqual(credentials.load()?.accessToken, "fresh-access")

        let result = try await client.interpret(turn)
        XCTAssertEqual(result.translatedText, "Hallo")
        let finalRequests = state.read { $0.interpretRequests }
        let keys = finalRequests.compactMap { $0.value(forHTTPHeaderField: "Idempotency-Key") }
        XCTAssertEqual(finalRequests.count, 2)
        XCTAssertEqual(Set(keys).count, 2)
        XCTAssertTrue(keys.allSatisfy { UUID(uuidString: $0) != nil })
    }

    func testDeleteSessionHasEmptyBodyAndNoContentTypeThenClearsOnlyAfterConfirmation() async throws {
        let credentials = MemoryCredentialStore(AuthTokens(accessToken: "valid-access", refreshToken: "refresh-token", expiresAt: Date().addingTimeInterval(3_600)))
        let capturedRequest = Locked<URLRequest?>(nil)
        MockURLProtocol.setHandler { [self] request in
            capturedRequest.update { $0 = request }
            return (response(for: request, status: 204), Data())
        }

        let client = RelayAPIClient(configuration: configuration(), session: session(), credentials: credentials)
        try await client.deleteIdentity()

        let request = try XCTUnwrap(capturedRequest.read { $0 })
        XCTAssertEqual(request.url?.path, "/functions/v1/native-backend/delete-session")
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.httpBodyStream)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertNil(credentials.load())
    }

    func testDeleteUnauthorizedNeverCreatesIdentityOrClaimsDeletion() async throws {
        let credentials = MemoryCredentialStore(AuthTokens(accessToken: "stale-access", refreshToken: "bad-refresh", expiresAt: Date().addingTimeInterval(3_600)))
        struct State { var deleteCount = 0; var refreshCount = 0; var signupCount = 0 }
        let state = Locked(State())
        MockURLProtocol.setHandler { [self] request in
            try state.update { state in
                switch request.url!.path {
                case "/functions/v1/native-backend/delete-session":
                    state.deleteCount += 1
                    return (response(for: request, status: 401), Data())
                case "/auth/v1/token":
                    state.refreshCount += 1
                    return (response(for: request, status: 401), Data())
                case "/auth/v1/signup":
                    state.signupCount += 1
                    return (response(for: request, status: 500), Data())
                default:
                    throw URLError(.badURL)
                }
            }
        }

        let client = RelayAPIClient(configuration: configuration(), session: session(), credentials: credentials)
        do {
            try await client.deleteIdentity()
            XCTFail("Deletion must require confirmed success.")
        } catch let error as RelayClientError {
            guard case let .server(code, message) = error else { return XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(code, "delete_not_confirmed")
            XCTAssertTrue(message.contains("not confirmed"))
        }
        let snapshot = state.read { $0 }
        XCTAssertEqual(snapshot.deleteCount, 1)
        XCTAssertEqual(snapshot.refreshCount, 1)
        XCTAssertEqual(snapshot.signupCount, 0)
        XCTAssertNil(credentials.load())
    }

    func testDeleteWithoutStoredIdentityDoesNotSignUpOrCallBackend() async {
        let credentials = MemoryCredentialStore()
        let requestCount = Locked(0)
        MockURLProtocol.setHandler { request in
            requestCount.update { $0 += 1 }
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = RelayAPIClient(configuration: configuration(), session: session(), credentials: credentials)
        do {
            try await client.deleteIdentity()
            XCTFail("There is no stored identity to delete.")
        } catch let error as RelayClientError {
            guard case let .server(code, _) = error else { return XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(code, "no_identity")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(requestCount.read { $0 }, 0)
    }

    func testDefaultSessionIsEphemeralWithoutCacheOrPersistentCookies() {
        let configuration = RelayAPIClient.makeEphemeralSession().configuration
        XCTAssertNil(configuration.urlCache)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
    }
}
