import Foundation

/// Public constants only. API credentials are supplied by each user, never bundled.
struct ServiceConfiguration: Equatable {
    let privacyPolicyURL: URL?
    let supportURL: URL?

    static let jevEndpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!
    static let nebiusEndpoint = URL(string: "https://api.tokenfactory.nebius.com/v1/chat/completions")!
    static let jevModel = "jev-1.13.0"
    static let qwenModel = "Qwen/Qwen3-30B-A3B-Instruct-2507"

    static func current(bundle: Bundle = .main) -> ServiceConfiguration {
        func secureURL(_ key: String) -> URL? {
            let raw = (bundle.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: raw), url.scheme?.lowercased() == "https", url.host != nil,
                  url.user == nil, url.password == nil else { return nil }
            return url
        }
        return ServiceConfiguration(privacyPolicyURL: secureURL("PRIVACY_POLICY_URL"), supportURL: secureURL("SUPPORT_URL"))
    }

    var isServiceAvailable: Bool { true }
    var missingServiceMessage: String { "Add your own TypeSafe / Jev and Nebius API keys in Settings to translate. Your provider accounts are charged." }
}
