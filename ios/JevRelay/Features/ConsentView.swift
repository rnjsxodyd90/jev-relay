import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Before the first live turn").font(.relay(.title, weight: .semibold)).foregroundStyle(RelayStyle.slate)
                    Text("Jev Relay can send the English text and situational context you choose to TypeSafe / Jev for four routing decisions and, when needed, to Nebius / Qwen for a Dutch translation.").font(.relay(.body))
                    VStack(alignment: .leading, spacing: 14) {
                        ConsentPoint(icon: "text.quote", title: "Text leaves this device", detail: "The source text and context are transmitted. Do not include information you do not want processed by these services.")
                        ConsentPoint(icon: "waveform", title: "Audio stays on device", detail: "Recording uses Apple on-device recognition only. No audio file is saved or uploaded, and there is no remote recognition fallback.")
                        ConsentPoint(icon: "clock", title: "Provider policies may allow retention", detail: "Retention and processing depend on the service providers and the operator’s published policy. Jev Relay does not make a blanket no-retention claim.")
                        ConsentPoint(icon: "person.crop.circle.badge.checkmark", title: "Anonymous cloud identity", detail: "An anonymous Supabase identity is created only after you consent and request a live interpretation. Its tokens stay in this device’s Keychain.")
                    }
                    if let url = model.configuration.privacyPolicyURL { Link("Read the privacy policy", destination: url).font(.relay(.headline)).frame(minHeight: 44) }
                    else { Text("Privacy policy link is not configured in this build.").font(.relay(.subheadline)).foregroundStyle(RelayStyle.error) }
                    Text("You can revoke consent or request deletion of the anonymous cloud identity in Preferences. Deletion cannot recover that identity.").font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted)
                    VStack(spacing: 10) {
                        Button("I understand and consent") { model.acceptConsent() }.buttonStyle(RelayButtonStyle(prominent: true)).frame(maxWidth: .infinity).accessibilityIdentifier("acceptConsent")
                        Button("Not now") { model.declineConsent() }.buttonStyle(RelayButtonStyle(prominent: false)).frame(maxWidth: .infinity)
                    }
                }.padding(24).frame(maxWidth: 680)
            }.background(RelayStyle.workspace).navigationTitle("Transmission notice").navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ConsentPoint: View {
    let icon: String; let title: String; let detail: String
    var body: some View { HStack(alignment: .top, spacing: 14) { Image(systemName: icon).font(.title3).foregroundStyle(RelayStyle.indigo).frame(width: 28); VStack(alignment: .leading, spacing: 3) { Text(title).font(.relay(.headline, weight: .semibold)); Text(detail).font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted) } } }
}
