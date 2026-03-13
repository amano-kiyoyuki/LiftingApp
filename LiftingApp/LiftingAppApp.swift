import SwiftUI
import SwiftData

@main
struct LiftingAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: PracticeRecord.self)
    }
}
