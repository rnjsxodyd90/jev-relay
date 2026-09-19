import SwiftUI

struct PhrasebookView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        List {
            Section {
                Text("These phrases ship with the app and work offline. Choosing one only places its English text in the editor; nothing is transmitted automatically.").font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted)
            }
            Section("Built-in phrases") {
                ForEach(filteredBuiltIn) { phrase in
                    Button { model.usePhrase(phrase) } label: { PhraseRow(english: phrase.english, dutch: phrase.dutch) }.buttonStyle(.plain).frame(minHeight: 52).accessibilityIdentifier("builtInPhrase_\(phrase.id)")
                }
            }
            Section("Saved on this device") {
                if let error = model.phrasebook.storageError { Text(error).font(.relay(.subheadline)).foregroundStyle(RelayStyle.error) }
                if filteredSaved.isEmpty { Text(model.phrasebook.saved.isEmpty ? "No saved phrases yet. Save a reviewed result explicitly after interpretation." : "No saved phrase matches this search.").font(.relay(.subheadline)).foregroundStyle(RelayStyle.muted).accessibilityIdentifier("savedPhraseStatus") }
                ForEach(filteredSaved) { phrase in
                    Button { model.useSavedPhrase(phrase) } label: { PhraseRow(english: phrase.english, dutch: phrase.dutch) }.buttonStyle(.plain).frame(minHeight: 52)
                        .swipeActions { Button("Delete", role: .destructive) { model.phrasebook.delete(phrase) } }
                }
            }
        }
        .scrollContentBackground(.hidden).background(RelayStyle.workspace).navigationTitle("Offline phrases").searchable(text: $model.phraseSearch, prompt: "English or Dutch")
        .accessibilityIdentifier("phrasebookList")
    }
    private var filteredBuiltIn: [Phrase] { filter(model.phrasebook.builtIn) { $0.english + " " + $0.dutch } }
    private var filteredSaved: [SavedPhrase] { filter(model.phrasebook.saved) { $0.english + " " + $0.dutch } }
    private func filter<T>(_ values: [T], text: (T) -> String) -> [T] { model.phraseSearch.isEmpty ? values : values.filter { text($0).localizedCaseInsensitiveContains(model.phraseSearch) } }
}

private struct PhraseRow: View {
    let english: String; let dutch: String
    var body: some View { VStack(alignment: .leading, spacing: 4) { Text(english).font(.relay(.body, weight: .medium)).foregroundStyle(RelayStyle.slate); Text(dutch).font(.relay(.subheadline)).foregroundStyle(RelayStyle.indigo) }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }
}
