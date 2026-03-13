import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \PracticeRecord.date, order: .reverse) private var records: [PracticeRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var playingVideoURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView("履歴がありません", systemImage: "clock", description: Text("練習を終了して保存すると\nここに表示されます"))
                } else {
                    List {
                        ForEach(records) { record in
                            recordRow(record)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                }
            }
            .navigationTitle("練習履歴")
            .sheet(item: $playingVideoURL) { url in
                VideoPlayerView(url: url)
            }
        }
    }

    private func recordRow(_ record: PracticeRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.date, format: .dateTime.month().day().weekday(.abbreviated))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(record.date, format: .dateTime.hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("\(record.count) 回", systemImage: "figure.soccer")
                    .font(.headline)
                Spacer()
                Label(record.durationText, systemImage: "timer")
                    .font(.headline)
            }

            if !record.memo.isEmpty {
                Text(record.memo)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let videoURL = record.videoURL {
                Button {
                    playingVideoURL = videoURL
                } label: {
                    Label("録画を再生", systemImage: "play.circle.fill")
                        .font(.subheadline)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            let record = records[index]
            if let videoURL = record.videoURL {
                try? FileManager.default.removeItem(at: videoURL)
            }
            modelContext.delete(record)
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    HistoryView()
        .modelContainer(for: PracticeRecord.self, inMemory: true)
}
