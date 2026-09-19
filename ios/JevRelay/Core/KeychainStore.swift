import Foundation
import Security

struct AuthTokens: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

enum KeychainStoreError: Error { case unexpectedStatus(OSStatus), invalidData }

protocol CredentialStoring: AnyObject {
    func save(_ tokens: AuthTokens) throws
    func load() throws -> AuthTokens?
    func clear() throws
}

final class KeychainStore: CredentialStoring {
    private let service = "com.taekwon.jevrelay.auth"
    private let account = "anonymous-session"

    func save(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
    }

    func load() throws -> AuthTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
        guard let data = item as? Data else { throw KeychainStoreError.invalidData }
        return try JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func clear() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainStoreError.unexpectedStatus(status) }
    }
}
