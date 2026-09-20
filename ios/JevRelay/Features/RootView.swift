import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            NavigationStack { WorkbenchView(openSettings: { model.selectedTab = .settings }) }
                .tabItem { Label("Translate", systemImage: "text.book.closed") }
                .tag(AppTab.workbench)
                .accessibilityIdentifier("workbenchTab")
            NavigationStack { PhrasebookView() }
                .tabItem { Label("Phrases", systemImage: "character.book.closed") }
                .tag(AppTab.phrases)
                .accessibilityIdentifier("phrasesTab")
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(AppTab.settings)
                .accessibilityIdentifier("preferencesTab")
        }
        .background(RelayStyle.workspace)
        .sheet(isPresented: $model.showingConsent) { ConsentView().interactiveDismissDisabled() }
        .confirmationDialog("Start over?", isPresented: $model.showingResetConfirmation, titleVisibility: .visible) {
            Button("Clear current text", role: .destructive) { model.resetSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears your current text, context, tone and Dutch result. Your saved phrases stay on this device.")
        }
    }
}
