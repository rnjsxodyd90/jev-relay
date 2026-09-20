import Foundation
import Security

enum ProviderKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case jev, nebius
    var id: String { rawValue }
    var displayName: String { self == .jev ? "TypeSafe / Jev" : "Nebius / Qwen" }
}

enum KeychainStoreError: LocalizedError, Equatable {
    case unexpectedStatus(OSStatus), invalidData, invalidKey
    var errorDescription: String? {
        switch self {
        case .unexpectedStatus: return "Your provider key could not be accessed securely. Unlock this device and try again."
        case .invalidData: return "The stored provider key could not be read. Remove it and add your key again."
        case .invalidKey: return "Enter only the API key, without spaces, line breaks, or a Bearer prefix."
        }
    }
}

enum ProviderCredentialValidation {
    static func normalized(_ key: String) throws -> String {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= 4_096,
              value.unicodeScalars.allSatisfy({ (33...126).contains(Int($0.value)) }) else {
            throw KeychainStoreError.invalidKey
        }
        return value
    }
}

protocol ProviderKeyStoring: AnyObject {
    func load(_ provider: ProviderKind) throws -> String?
    func save(_ key: String, for provider: ProviderKind) throws
    func clear(_ provider: ProviderKind) throws
}

/// User-owned keys only. Never synchronized to iCloud or included in app configuration.
/// Keys are read at request time and sent only to their matching provider for authentication.
final class ProviderKeychainStore: ProviderKeyStoring {
    private let service = "com.taekwon.jevrelay.provider-keys.v1"

    private func query(for provider: ProviderKind) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: provider.rawValue,
         kSecAttrSynchronizable as String: false]
    }

    func save(_ key: String, for provider: ProviderKind) throws {
        let value = try ProviderCredentialValidation.normalized(key)
        let data = Data(value.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let query = query(for: provider)
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            status = SecItemAdd(item as CFDictionary, nil)
            if status == errSecDuplicateItem {
                status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            }
        }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
    }

    func load(_ provider: ProviderKind) throws -> String? {
        var query = query(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8),
              (try? ProviderCredentialValidation.normalized(value)) == value else {
            throw KeychainStoreError.invalidData
        }
        return value
    }

    func clear(_ provider: ProviderKind) throws {
        let status = SecItemDelete(query(for: provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }
}
