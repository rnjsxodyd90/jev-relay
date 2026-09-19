import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var model: AppModel
    let result: InterpretResponse
    var body: some View {
        PaperSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) { Text(routeTitle).font(.relay(.title3, weight: .semibold)); Text(routeSubtitle).font(.relay(.caption)).foregroundStyle(RelayStyle.muted) }
                    Spacer(); routeBadge
                }
                Divider().overlay(RelayStyle.rule)
                VStack(alignment: .leading, spacing: 5) { Text("Source matched to request").font(.relay(.caption, weight: .semibold)).foregroundStyle(RelayStyle.muted); Text(result.sourceText).font(.relay(.body)).foregroundStyle(RelayStyle.slate) }
                if result.route == .clarify {
                    VStack(alignment: .leading, spacing: 6) { Text("Context needed").font(.relay(.headline, weight: .semibold)); Text(result.clarification.isEmpty ? "Please clarify the missing reference, meaning, or final wording before translating." : result.clarification).font(.relay(.body)); Text("No translation was invented.").font(.relay(.caption)).foregroundStyle(RelayStyle.muted) }
                } else if result.route == .review {
                    VStack(alignment: .leading, spacing: 6) { Text("Nothing approved for playback").font(.relay(.headline, weight: .semibold)); Text(result.reason).font(.relay(.body)) }.foregroundStyle(RelayStyle.error)
                } else {
                    VStack(alignment: .leading, spacing: 6) { Text("Dutch result").font(.relay(.caption, weight: .semibold)).foregroundStyle(RelayStyle.muted); Text(result.translatedText).font(.relay(.title2, weight: .medium)).textSelection(.enabled).accessibilityIdentifier("dutchResult") }
                    HStack(spacing: 12) {
                        Button { model.requestPlaybackReview() } label: { Label("Review, then play Dutch", systemImage: "speaker.wave.2") }.buttonStyle(RelayButtonStyle(prominent: true)).disabled(model.speaker.voice == nil)
                        Button { model.saveResult() } label: { Label(model.phrasebook.contains(english: result.sourceText, dutch: result.translatedText) ? "Saved" : "Save locally", systemImage: "bookmark") }.buttonStyle(RelayButtonStyle(prominent: false)).disabled(model.phrasebook.contains(english: result.sourceText, dutch: result.translatedText))
                    }
                    if let voiceMessage = model.speaker.availabilityMessage { Text(voiceMessage).font(.relay(.caption)).foregroundStyle(RelayStyle.error) }
                    if let storageError = model.phrasebook.storageError { Text(storageError).font(.relay(.caption)).foregroundStyle(RelayStyle.error) }
                }
                Text(result.reason).font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted)
                HStack { Text(result.model).font(.system(.caption, design: .monospaced)); Spacer(); Text("\(result.timing.totalMs) ms service time").font(.relay(.caption)) }.foregroundStyle(RelayStyle.muted)
                Text("Review before use. This output is not certified.").font(.relay(.caption, weight: .semibold)).foregroundStyle(RelayStyle.muted)
            }
        }
        .accessibilityIdentifier("resultPanel")
        .sheet(item: Binding(
            get: { model.playbackReview },
            set: { if $0 == nil { model.dismissPlaybackReview() } }
        )) { review in
            playbackReviewSheet(review)
        }
    }

    private func playbackReviewSheet(_ review: PlaybackReview) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review before playing Dutch")
                    .font(.relay(.title3, weight: .semibold))
                Text("Confirm the exact wording you want spoken. Playback starts only after you choose Reviewed, play Dutch.")
                    .font(.relay(.body))
                    .foregroundStyle(RelayStyle.muted)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Source wording")
                                .font(.relay(.caption, weight: .semibold))
                                .foregroundStyle(RelayStyle.muted)
                            Text(review.sourceText)
                                .font(.relay(.body))
                                .textSelection(.enabled)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dutch wording")
                                .font(.relay(.caption, weight: .semibold))
                                .foregroundStyle(RelayStyle.muted)
                            Text(review.translatedText)
                                .font(.relay(.title3, weight: .medium))
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 12) {
                    Button("Cancel") { model.dismissPlaybackReview() }
                        .buttonStyle(RelayButtonStyle(prominent: false))
                    Button { model.approveReviewAndPlay(review.id) } label: {
                        Label("Reviewed, play Dutch", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(RelayButtonStyle(prominent: true))
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var routeTitle: String { switch result.route { case .memory: return "Stored phrase selected"; case .translate: return "New translation"; case .clarify: return "Clarify this turn"; case .review: return "Review required" } }
    private var routeSubtitle: String { result.route == .translate && result.usedTranslator ? "Jev routed this turn to Qwen" : "Jev routing outcome" }
    private var routeBadge: some View { Text(result.route.rawValue.capitalized).font(.relay(.caption, weight: .bold)).padding(.horizontal, 10).frame(minHeight: 30).background((result.route == .review || result.route == .clarify ? RelayStyle.error : RelayStyle.success).opacity(0.12)).foregroundStyle(result.route == .review || result.route == .clarify ? RelayStyle.error : RelayStyle.success).clipShape(Capsule()) }
}
