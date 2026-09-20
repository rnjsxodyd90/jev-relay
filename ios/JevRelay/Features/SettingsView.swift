import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Bring your own API keys") {
                Text("Jev Relay includes no API credits and has no developer-funded fallback. Requests use your own TypeSafe / Jev and Nebius provider accounts, and provider charges and quotas apply to you.")
                    .font(.relay(.subheadline))
                    .foregroundStyle(RelayStyle.muted)
                    .accessibilityIdentifier("byokNoCreditsNotice")
                Text("Keys are stored in iOS Keychain on this device. Existing keys are never displayed or prefilled.")
                    .font(.relay(.subheadline))
                    .foregroundStyle(RelayStyle.muted)
            }

            ProviderKeySection(provider: .jev)
            ProviderKeySection(provider: .nebius)

            Section("Transmission consent") {
                if model.hasConsent {
                    Button("Revoke transmission consent", role: .destructive) { model.revokeConsent() }
                        .frame(minHeight: 44)
                    Text("Revoking consent cancels active work and invalidates any Dutch result awaiting review or playback.")
                        .font(.relay(.subheadline))
                        .foregroundStyle(RelayStyle.muted)
                } else {
                    Text("Transmission consent is not active. You will be asked after both provider keys are configured and you explicitly choose Translate.")
                        .font(.relay(.subheadline))
                        .foregroundStyle(RelayStyle.muted)
                }
            }

            Section("Local phrases") {
                LabeledContent("Saved", value: "\(model.phrasebook.saved.count)")
                Button("Clear all saved phrases", role: .destructive) { model.showingClearAllPhrases = true }
                    .disabled(model.phrasebook.saved.isEmpty)
                    .frame(minHeight: 44)
                Text("Saved phrases use protected local app storage and are excluded from device backups. Transcripts and turns are not automatically kept.")
                    .font(.relay(.subheadline))
                    .foregroundStyle(RelayStyle.muted)
                if let error = model.phrasebook.storageError {
                    Text(error).font(.relay(.subheadline)).foregroundStyle(RelayStyle.error)
                }
            }

            Section("Recorded evidence") {
                Text("Limited experiment: 12 synthetic cases × 3 rounds in one collection window. Jev: median 303 ms, p95 378 ms, exact 36/36. Qwen: median 375 ms, p95 652 ms, exact 28/36.")
                    .font(.relay(.subheadline))
                Text("These measurements do not establish universal speed, accuracy, cost, quota, or production performance. Confidence values are not calibrated correctness probabilities.")
                    .font(.relay(.subheadline))
                    .foregroundStyle(RelayStyle.muted)
            }

            Section("Help and policy") {
                if let url = model.configuration.privacyPolicyURL {
                    Link("Privacy policy", destination: url).frame(minHeight: 44).accessibilityIdentifier("privacyPolicyLink")
                } else {
                    LabeledContent("Privacy policy", value: "Not configured").accessibilityIdentifier("privacyPolicyLink")
                }
                if let url = model.configuration.supportURL {
                    Link("Support", destination: url).frame(minHeight: 44)
                } else {
                    LabeledContent("Support", value: "Not configured")
                }
            }

            Section {
                Text("Not for legal, medical, or emergency use. Output is not certified. No analytics, tracking, advertising, or in-app purchases are included. No Jev Relay account is required; your own provider credentials are required for live translation.")
                    .font(.relay(.caption))
                    .foregroundStyle(RelayStyle.muted)
                    .accessibilityIdentifier("privacySafetyNotice")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(RelayStyle.workspace)
        .navigationTitle("Settings")
        .confirmationDialog("Clear every saved local phrase?", isPresented: $model.showingClearAllPhrases, titleVisibility: .visible) {
            Button("Clear all", role: .destructive) { model.phrasebook.deleteAll() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct ProviderKeySection: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var key = ""
    @State private var showingRemoveConfirmation = false
    let provider: ProviderKind

    var body: some View {
        Section(provider.displayName) {
            LabeledContent("Status", value: model.isProviderConfigured(provider) ? "Configured" : "Not configured")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(provider.displayName) API key status")
                .accessibilityValue(model.isProviderConfigured(provider) ? "Configured" : "Not configured")
                .accessibilityIdentifier("\(provider.id)-key-status")
            SecureField("Paste API key", text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("\(provider.displayName) API key")
                .accessibilityIdentifier("\(provider.id)-key-field")
            HStack(spacing: 12) {
                Button(model.isProviderConfigured(provider) ? "Replace key" : "Save key") {
                    _ = model.saveProviderKey(key, for: provider)
                    key = ""
                }
                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(minHeight: 44)
                .accessibilityIdentifier("\(provider.id)-key-save")

                if model.isProviderConfigured(provider) {
                    Button("Remove", role: .destructive) { showingRemoveConfirmation = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("\(provider.id)-key-remove")
                }
            }
            .buttonStyle(.borderless)
            Text("Stored in iOS Keychain on this device. Saving does not contact or validate with the provider.")
                .font(.relay(.caption))
                .foregroundStyle(RelayStyle.muted)
            if let message = model.credentialMessage {
                Text(message).font(.relay(.caption)).foregroundStyle(RelayStyle.muted)
            }
        }
        .confirmationDialog("Remove the \(provider.displayName) key?", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
            Button("Remove key", role: .destructive) {
                _ = model.clearProviderKey(provider)
                key = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Translation will be blocked until a replacement key is stored. Any active request or playback approval will be cancelled.")
        }
        .onDisappear { key = "" }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { key = "" }
        }
    }
}
