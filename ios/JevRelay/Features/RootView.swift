import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        TabView {
            NavigationStack { WorkbenchView() }.tabItem { Label("Interpret", systemImage: "text.book.closed") }.accessibilityIdentifier("workbenchTab")
            NavigationStack { PhrasebookView() }.tabItem { Label("Phrases", systemImage: "character.book.closed") }.accessibilityIdentifier("phrasesTab")
            NavigationStack { SettingsView() }.tabItem { Label("Preferences", systemImage: "slider.horizontal.3") }.accessibilityIdentifier("preferencesTab")
        }
        .background(RelayStyle.workspace)
        .sheet(isPresented: $model.showingConsent) { ConsentView().interactiveDismissDisabled() }
        .confirmationDialog("Reset this turn?", isPresented: $model.showingResetConfirmation, titleVisibility: .visible) {
            Button("Reset session", role: .destructive) { model.resetSession() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The editable turn and result will be cleared. No transcript is kept in history.") }
    }
}
