import SwiftUI

@main
struct JevRelayApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(model).tint(RelayStyle.indigo) }
    }
}
