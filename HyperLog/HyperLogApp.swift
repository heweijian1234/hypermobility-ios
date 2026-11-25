import SwiftUI

@main
struct HyperLogApp: App {
    @StateObject private var pro = ProStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pro)
                .task { await pro.load() }
        }
    }
}
