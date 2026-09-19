import Foundation

enum RelayClientError: LocalizedError, Equatable {
    case unavailable, consentRequired, invalidResponse, unauthorized, quota, server(code: String, message: String), transport(String), sourceMismatch
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Live interpretation is not configured on this build. The offline phrasebook remains available."
        case .consentRequired: return "Review and accept the transmission notice before interpreting."
        case .invalidResponse: return "The service returned invalid data. Nothing was approved for playback."
        case .unauthorized: return "The anonymous session was not authorized. Credentials were refreshed or cleared for your next explicit attempt; this interpretation was not repeated."
        case .quota: return "The interpretation quota is currently exhausted. Nothing was sent again automatically."
        case let .server(_, message): return message
        case let .transport(message): return "The service could not be reached: \(message). Nothing was retried automatically."
        case .sourceMismatch: return "The response did not match the current source text and was discarded."
        }
    }
}

private struct SupabaseAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Double
    private enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in" }
}

actor AuthService {
    private let configuration: ServiceConfiguration
    private let session: URLSession
    private let credentials: any CredentialStoring

    init(configuration: ServiceConfiguration, session: URLSession, credentials: any CredentialStoring) {
        self.configuration = configuration
        self.session = session
        self.credentials = credentials
    }

    func validAccessToken() async throws -> String {
        guard configuration.isServiceAvailable, let supabase = configuration.supabaseURL else { throw RelayClientError.unavailable }
        if let stored = try credentials.load() {
            if stored.expiresAt.timeIntervalSinceNow > 60 { return stored.accessToken }
            return try await refreshStored(stored.refreshToken, base: supabase)
        }
        return try await signUp(base: supabase)
    }

    func existingAccessToken() async throws -> String {
        guard configuration.isServiceAvailable, let supabase = configuration.supabaseURL else { throw RelayClientError.unavailable }
        guard let stored = try credentials.load() else {
            throw RelayClientError.server(code: "no_identity", message: "No anonymous cloud identity is stored on this device.")
        }
        if stored.expiresAt.timeIntervalSinceNow > 60 { return stored.accessToken }
        return try await refreshStored(stored.refreshToken, base: supabase)
    }

    func recoverAfterUnauthorized(rejectedAccessToken: String) async {
        guard let supabase = configuration.supabaseURL,
              let stored = try? credentials.load() else {
            try? credentials.clear()
            return
        }
        do {
            let refreshed = try await refresh(stored.refreshToken, base: supabase)
            if refreshed == rejectedAccessToken { try? credentials.clear() }
        } catch { try? credentials.clear() }
    }

    private func signUp(base: URL) async throws -> String {
        var request = URLRequest(url: base.appending(path: "auth/v1/signup"))
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        addAuthHeaders(to: &request)
        return try await performAuth(request)
    }

    private func refreshStored(_ refreshToken: String, base: URL) async throws -> String {
        do { return try await refresh(refreshToken, base: base) }
        catch {
            if !(error is CancellationError) { try? credentials.clear() }
            throw error
        }
    }

    private func refresh(_ refreshToken: String, base: URL) async throws -> String {
        var components = URLComponents(url: base.appending(path: "auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components?.url else { throw RelayClientError.unavailable }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])
        addAuthHeaders(to: &request)
        return try await performAuth(request)
    }

    private func addAuthHeaders(to request: inout URLRequest) {
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    private func performAuth(_ request: URLRequest) async throws -> String {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw RelayClientError.invalidResponse }
            guard (200...299).contains(http.statusCode) else { throw parseError(data, status: http.statusCode) }
            let auth = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
            guard !auth.accessToken.isEmpty, !auth.refreshToken.isEmpty, auth.expiresIn > 0 else { throw RelayClientError.invalidResponse }
            try credentials.save(AuthTokens(accessToken: auth.accessToken, refreshToken: auth.refreshToken, expiresAt: Date().addingTimeInterval(auth.expiresIn)))
            return auth.accessToken
        } catch is CancellationError { throw CancellationError() }
        catch let error as RelayClientError { throw error }
        catch { throw RelayClientError.transport(error.localizedDescription) }
    }

    func clearTokens() throws { try credentials.clear() }

    private func parseError(_ data: Data, status: Int) -> RelayClientError {
        if status == 429 { return .quota }
        if status == 401 || status == 403 { return .unauthorized }
        if let body = try? JSONDecoder().decode(RelayHTTPErrorBody.self, from: data) { return .server(code: body.code, message: body.error) }
        return .server(code: "http_\(status)", message: "The service returned HTTP \(status).")
    }
}

protocol RelayServing {
    func interpret(_ turn: InterpretRequest) async throws -> InterpretResponse
    func deleteIdentity() async throws
}

actor RelayAPIClient: RelayServing {
    private let configuration: ServiceConfiguration
    private let session: URLSession
    private let auth: AuthService

    init(configuration: ServiceConfiguration, session: URLSession? = nil, credentials: any CredentialStoring = KeychainStore()) {
        let resolvedSession = session ?? Self.makeEphemeralSession()
        self.configuration = configuration
        self.session = resolvedSession
        self.auth = AuthService(configuration: configuration, session: resolvedSession, credentials: credentials)
    }

    nonisolated static func makeEphemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }

    func interpret(_ turn: InterpretRequest) async throws -> InterpretResponse {
        guard let base = configuration.backendURL, configuration.isServiceAvailable else { throw RelayClientError.unavailable }
        let token = try await auth.validAccessToken()
        var request = URLRequest(url: base.appending(path: "interpret"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try JSONEncoder().encode(turn)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw RelayClientError.invalidResponse }
            if http.statusCode == 401 {
                await auth.recoverAfterUnauthorized(rejectedAccessToken: token)
                throw RelayClientError.unauthorized
            }
            guard (200...299).contains(http.statusCode) else { throw parseError(data, status: http.statusCode) }
            let result = try JSONDecoder().decode(InterpretResponse.self, from: data)
            guard result.sourceText == turn.text else { throw RelayClientError.sourceMismatch }
            return result
        } catch is CancellationError { throw CancellationError() }
        catch let error as RelayClientError { throw error }
        catch is DecodingError { throw RelayClientError.invalidResponse }
        catch { throw RelayClientError.transport(error.localizedDescription) }
    }

    func deleteIdentity() async throws {
        guard let base = configuration.backendURL, configuration.isServiceAvailable else { throw RelayClientError.unavailable }
        let token = try await auth.existingAccessToken()
        var request = URLRequest(url: base.appending(path: "delete-session"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw RelayClientError.invalidResponse }
            if http.statusCode == 401 {
                await auth.recoverAfterUnauthorized(rejectedAccessToken: token)
                throw RelayClientError.server(code: "delete_not_confirmed", message: "Identity deletion was not confirmed. Credentials were refreshed or cleared for your next explicit attempt.")
            }
            guard (200...299).contains(http.statusCode) else {
                throw RelayClientError.server(code: "http_\(http.statusCode)", message: "Identity deletion was not confirmed by the service.")
            }
            try await auth.clearTokens()
        } catch is CancellationError { throw CancellationError() }
        catch let error as RelayClientError { throw error }
        catch { throw RelayClientError.transport(error.localizedDescription) }
    }

    private func parseError(_ data: Data, status: Int) -> RelayClientError {
        if status == 429 { return .quota }
        if status == 401 || status == 403 { return .unauthorized }
        if let body = try? JSONDecoder().decode(RelayHTTPErrorBody.self, from: data) { return .server(code: body.code, message: body.error) }
        return .server(code: "http_\(status)", message: "The service returned HTTP \(status).")
    }
}
