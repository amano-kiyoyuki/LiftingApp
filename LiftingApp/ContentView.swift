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

            VideoAnalysisView()
                .tabItem {
                    Label("動画分析", systemImage: "film")
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
