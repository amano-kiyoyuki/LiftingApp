import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PracticeView()
                .tabItem {
                    Label("練習", systemImage: "figure.soccer")
                }

            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock")
                }

            StatsView()
                .tabItem {
                    Label("統計", systemImage: "chart.bar")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PracticeRecord.self, inMemory: true)
}
