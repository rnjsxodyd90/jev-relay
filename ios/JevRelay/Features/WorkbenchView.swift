import SwiftUI

@MainActor
private final class WorkbenchPresentationState: ObservableObject {
    @Published var showingOptionalControls = false
}

struct WorkbenchView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var focusedField: EditorField?
    @StateObject private var presentation = WorkbenchPresentationState()
    private enum EditorField: Hashable { case source, context }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    masthead
                    let wide = proxy.size.width >= 760
                    Group {
                        if wide { HStack(alignment: .top, spacing: 18) { editor.frame(maxWidth: .infinity); DecisionRail(result: model.result).frame(width: 300) } }
                        else { VStack(spacing: 18) { editor; DecisionRail(result: model.result) } }
                    }
                    if let result = model.result { ResultView(result: result) }
                    safetyNote
                }.padding(wideInsets(proxy.size.width)).frame(maxWidth: 1100).frame(maxWidth: .infinity)
            }
            .background(RelayStyle.workspace.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("workbenchScroll")
        }
        .navigationTitle("Jev Relay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Start over") { focusedField = nil; model.showingResetConfirmation = true }.frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("resetSessionButton") }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil }.accessibilityIdentifier("dismissKeyboardButton") }
        }
        .onDisappear { model.speechCapture.stop(); model.speaker.stop() }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("English → Dutch").font(.relay(.subheadline, weight: .semibold)).foregroundStyle(RelayStyle.indigo)
            Text("Your English-to-Dutch conversation helper").font(.relay(.title2, weight: .semibold)).foregroundStyle(RelayStyle.slate)
            Text("Type or speak English, review the Dutch, then choose to play it.").font(.relay(.body)).foregroundStyle(RelayStyle.muted)
        }
    }

    private var editor: some View {
        PaperSurface {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack { Text("English to translate").font(.relay(.headline, weight: .semibold)); Spacer(); if model.sourceText.utf8.count >= 3_200 { Text(limitText).font(.relay(.caption)).foregroundStyle(model.sourceText.utf8.count > 4_000 ? RelayStyle.error : RelayStyle.muted) } }
                    TextEditor(text: $model.sourceText).focused($focusedField, equals: .source).frame(minHeight: 175)
                        .font(.relay(.body)).scrollContentBackground(.hidden).padding(10).background(RelayStyle.workspace)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(RelayStyle.rule))
                        .accessibilityLabel("English source text").accessibilityIdentifier("sourceEditor")
                    Button("Try an example") { model.sourceText = "Which train goes to Amsterdam?" }
                        .buttonStyle(RelayButtonStyle(prominent: false)).accessibilityIdentifier("tryExampleButton")
                    Text("This only fills the editable English text. It does not translate, record, or send anything.").font(.relay(.caption)).foregroundStyle(RelayStyle.muted)
                }
                Button { presentation.showingOptionalControls.toggle() } label: {
                    HStack(spacing: 8) {
                        Text("Optional context and tone").font(.relay(.headline, weight: .semibold))
                        Spacer()
                        Image(systemName: presentation.showingOptionalControls ? "chevron.up" : "chevron.down")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("optionalControls")
                .accessibilityValue(presentation.showingOptionalControls ? "Expanded" : "Collapsed")
                if presentation.showingOptionalControls {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Add these only when they help the meaning or formality. They are optional.").font(.relay(.caption)).foregroundStyle(RelayStyle.muted)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Context").font(.relay(.headline, weight: .semibold))
                            TextField("Who is speaking, to whom, and what does “it” refer to?", text: $model.context, axis: .vertical)
                                .focused($focusedField, equals: .context).lineLimit(2...5).textFieldStyle(.plain).padding(12).background(RelayStyle.workspace)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(RelayStyle.rule)).accessibilityIdentifier("contextEditor")
                        }
                        VStack(alignment: .leading, spacing: 7) { Text("Tone").font(.relay(.headline, weight: .semibold)); Picker("Tone", selection: $model.tone) { ForEach(ToneMode.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented).accessibilityIdentifier("tonePicker") }
                    }
                    .padding(.top, 8)
                }
                Text("Translation needs an internet connection. Nothing is sent until you choose Translate.").font(.relay(.caption)).foregroundStyle(RelayStyle.muted).accessibilityIdentifier("transmissionNotice")
                Text("Live service includes 10 turns per user per UTC day. Shared service limits may also apply.").font(.relay(.caption)).foregroundStyle(RelayStyle.muted)
                Divider().overlay(RelayStyle.rule)
                HStack(spacing: 12) {
                    Button { focusedField = nil; Task { await model.speechCapture.toggle() } } label: { Label(speakButtonTitle, systemImage: model.speechCapture.isRecording ? "stop.fill" : model.speechCapture.isStarting ? "xmark" : "mic") }
                        .buttonStyle(RelayButtonStyle(prominent: false)).accessibilityIdentifier("speakEnglishButton")
                    Spacer()
                    if model.isInterpreting { Button("Cancel") { model.cancelInterpretation() }.buttonStyle(RelayButtonStyle(prominent: false)) }
                    Button("Translate") { focusedField = nil; model.requestInterpretation() }.buttonStyle(RelayButtonStyle(prominent: true))
                        .disabled(model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isInterpreting).accessibilityIdentifier("translateButton")
                }
                if model.isInterpreting { ProgressView("Translating…").font(.relay(.subheadline)).accessibilityIdentifier("interpretProgress") }
                if !model.speechCapture.status.isEmpty { Text(model.speechCapture.status).font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted) }
                if !model.configuration.isServiceAvailable { Label(model.configuration.missingServiceMessage, systemImage: "network.slash").font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted) }
                if let error = model.errorMessage { Label(error, systemImage: "exclamationmark.triangle").font(.relay(.subheadline, weight: .medium)).foregroundStyle(RelayStyle.error).accessibilityIdentifier("errorMessage") }
            }
        }
    }

    private var safetyNote: some View { Text("Jev Relay is not for legal, medical, or emergency use. Output is not a certified translation. Review wording before playback or use.").font(.relay(.caption)).foregroundStyle(RelayStyle.muted).frame(maxWidth: 680, alignment: .leading).accessibilityIdentifier("workbenchSafetyNotice") }
    private var speakButtonTitle: String { model.speechCapture.isRecording ? "Stop speaking" : model.speechCapture.isStarting ? "Cancel" : "Speak English" }
    private var limitText: String { let remaining = 4_000 - model.sourceText.utf8.count; return remaining >= 0 ? "\(remaining) bytes remaining" : "\(-remaining) bytes over limit" }
    private func wideInsets(_ width: CGFloat) -> EdgeInsets { EdgeInsets(top: 20, leading: width > 760 ? 28 : 16, bottom: 36, trailing: width > 760 ? 28 : 16) }
}
