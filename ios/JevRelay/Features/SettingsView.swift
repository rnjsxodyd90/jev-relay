import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Form {
            Section("Live service") {
                LabeledContent("Status", value: model.configuration.isServiceAvailable ? "Configured" : "Unavailable")
                Text(model.configuration.isServiceAvailable ? "Translation needs an internet connection. Text can be sent only after consent and an explicit Translate action." : model.configuration.missingServiceMessage).font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted)
                if model.hasConsent { Button("Revoke transmission consent") { model.revokeConsent() }.frame(minHeight: 44) }
                else { Text("Transmission consent is not active.").font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted) }
            }
            Section("Anonymous cloud identity") {
                Text("Deleting asks the relay service to remove the current anonymous identity. After confirmed success, its tokens are cleared. The identity cannot be recovered.").font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted)
                Button("Delete cloud identity", role: .destructive) { model.showingIdentityDeletion = true }.disabled(model.isDeletingIdentity || !model.configuration.isServiceAvailable).frame(minHeight: 44)
                if model.isDeletingIdentity { ProgressView("Waiting for confirmed deletion…") }
                if let message = model.deletionMessage { Text(message).font(.relay(.subheadline)).foregroundStyle(message.contains("was deleted") ? RelayStyle.success : RelayStyle.error) }
            }
            Section("Local phrases") {
                LabeledContent("Saved", value: "\(model.phrasebook.saved.count)")
                Button("Clear all saved phrases", role: .destructive) { model.showingClearAllPhrases = true }.disabled(model.phrasebook.saved.isEmpty).frame(minHeight: 44)
                Text("Saved phrases use protected local app storage and are excluded from device backups. Transcripts and turns are not automatically kept.").font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted)
                if let error = model.phrasebook.storageError { Text(error).font(.relay(.subheadline)).foregroundStyle(RelayStyle.error) }
            }
            Section("Recorded evidence") {
                Text("Limited experiment: 12 synthetic cases × 3 rounds in one collection window. Jev: median 303 ms, p95 378 ms, exact 36/36. Qwen: median 375 ms, p95 652 ms, exact 28/36.").font(.relay(.subheadline))
                Text("Qwen had lower median latency on the single memory-match and word-sense tasks. These measurements do not establish universal speed, accuracy, or production approval performance. Confidence values are not calibrated correctness probabilities.").font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted)
            }
            Section("Help and policy") {
                if let url = model.configuration.privacyPolicyURL { Link("Privacy policy", destination: url).frame(minHeight: 44).accessibilityIdentifier("privacyPolicyLink") } else { LabeledContent("Privacy policy", value: "Not configured").accessibilityIdentifier("privacyPolicyLink") }
                if let url = model.configuration.supportURL { Link("Support", destination: url).frame(minHeight: 44) } else { LabeledContent("Support", value: "Not configured") }
            }
            Section { Text("Not for legal, medical, or emergency use. Output is not certified. No analytics, tracking, advertising, in-app purchases, or account wall are included.").font(.relay(.caption)).foregroundStyle(RelayStyle.muted).accessibilityIdentifier("privacySafetyNotice") }
        }
        .scrollContentBackground(.hidden).background(RelayStyle.workspace).navigationTitle("Settings")
        .confirmationDialog("Delete anonymous identity?", isPresented: $model.showingIdentityDeletion, titleVisibility: .visible) {
            Button("Delete identity, keep local phrases", role: .destructive) { deleteIdentity(clearSaved: false) }
            Button("Delete identity and local phrases", role: .destructive) { deleteIdentity(clearSaved: true) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone. Choose explicitly whether locally saved phrases should also be cleared.") }
        .confirmationDialog("Clear every saved local phrase?", isPresented: $model.showingClearAllPhrases, titleVisibility: .visible) {
            Button("Clear all", role: .destructive) { model.phrasebook.deleteAll() }; Button("Cancel", role: .cancel) {}
        }
    }

    private func deleteIdentity(clearSaved: Bool) {
        model.isDeletingIdentity = true
        Task { await model.deleteIdentity(clearSavedPhrases: clearSaved); model.isDeletingIdentity = false }
    }
}
