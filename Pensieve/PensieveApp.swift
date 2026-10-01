import SwiftUI

@main
struct PensieveApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    store.start()
                }
        }
    }
}
