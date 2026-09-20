import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Before the first live turn")
                        .font(.relay(.title, weight: .semibold))
                        .foregroundStyle(RelayStyle.slate)
                    Text("Nothing leaves this device until you explicitly choose Translate. Jev Relay can then send the English text and situational context you choose directly to TypeSafe / Jev for routing decisions and, when needed, to Nebius for a Dutch translation.")
                        .font(.relay(.body))
                    VStack(alignment: .leading, spacing: 14) {
                        ConsentPoint(icon: "key", title: "Your provider keys and credits", detail: "Requests use the TypeSafe / Jev and Nebius API keys you stored in this device’s Keychain. Provider charges and account quotas apply to you. The app includes no API credits and no developer-funded fallback.")
                        ConsentPoint(icon: "text.quote", title: "Text leaves this device", detail: "The source text and context are transmitted to those providers. Do not include information you do not want them to process.")
                        ConsentPoint(icon: "waveform", title: "Audio stays on device", detail: "Recording uses Apple on-device recognition only. No audio file is saved or uploaded, and there is no remote recognition fallback.")
                        ConsentPoint(icon: "clock", title: "Provider policies apply", detail: "Retention, processing, billing, and quotas depend on your provider accounts and their published policies. Jev Relay does not automatically retry or switch to another funded service.")
                    }
                    if let url = model.configuration.privacyPolicyURL {
                        Link("Read the privacy policy", destination: url).font(.relay(.headline)).frame(minHeight: 44)
                    } else {
                        Text("Privacy policy link is not configured in this build.").font(.relay(.subheadline)).foregroundStyle(RelayStyle.error)
                    }
                    Text("You can revoke consent or remove either provider key in Settings. Either action cancels active work and invalidates playback approval.")
                        .font(.relay(.subheadline))
                        .foregroundStyle(RelayStyle.muted)
                    VStack(spacing: 10) {
                        Button("I understand and consent") { model.acceptConsent() }
                            .buttonStyle(RelayButtonStyle(prominent: true))
                            .frame(maxWidth: .infinity)
                            .disabled(!model.hasRequiredProviderKeys)
                            .accessibilityIdentifier("acceptConsent")
                        Button("Not now") { model.declineConsent() }
                            .buttonStyle(RelayButtonStyle(prominent: false))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(24)
                .frame(maxWidth: 680)
            }
            .background(RelayStyle.workspace)
            .navigationTitle("Transmission notice")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ConsentPoint: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(RelayStyle.indigo).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.relay(.headline, weight: .semibold))
                Text(detail).font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted)
            }
        }
    }
}
