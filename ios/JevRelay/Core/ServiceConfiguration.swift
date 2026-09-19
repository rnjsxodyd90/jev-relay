import Foundation

struct ServiceConfiguration: Equatable {
    let supabaseURL: URL?
    let publishableKey: String
    let backendURL: URL?
    let privacyPolicyURL: URL?
    let supportURL: URL?

    static func current(bundle: Bundle = .main) -> ServiceConfiguration {
        func value(_ key: String) -> String { (bundle.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        func secureURL(_ key: String) -> URL? {
            guard let url = URL(string: value(key)), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
            return url
        }
        return ServiceConfiguration(
            supabaseURL: secureURL("SUPABASE_URL"),
            publishableKey: value("SUPABASE_PUBLISHABLE_KEY"),
            backendURL: secureURL("RELAY_BACKEND_URL"),
            privacyPolicyURL: secureURL("PRIVACY_POLICY_URL"),
            supportURL: secureURL("SUPPORT_URL")
        )
    }

    var isServiceAvailable: Bool { supabaseURL != nil && backendURL != nil && !publishableKey.isEmpty }
    var missingServiceMessage: String { "Live interpretation is unavailable until the service URL and public Supabase key are configured." }
}
