import SwiftUI
import SwiftData
import Photos

struct HistoryView: View {
    @Query(sort: \PracticeRecord.date, order: .reverse) private var records: [PracticeRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var playingVideoURL: URL?
    @State private var saveMessage: String?

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
            .alert("動画保存", isPresented: Binding(
                get: { saveMessage != nil },
                set: { if !$0 { saveMessage = nil } }
            )) {
                Button("OK") { saveMessage = nil }
            } message: {
                Text(saveMessage ?? "")
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
                HStack(spacing: 16) {
                    Button {
                        playingVideoURL = videoURL
                    } label: {
                        Label("録画を再生", systemImage: "play.circle.fill")
                            .font(.subheadline)
                    }

                    Button {
                        saveVideoToCameraRoll(url: videoURL)
                    } label: {
                        Label("カメラロールに保存", systemImage: "square.and.arrow.down")
                            .font(.subheadline)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func saveVideoToCameraRoll(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    saveMessage = "フォトライブラリへのアクセスが許可されていません"
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        saveMessage = "カメラロールに保存しました"
                    } else {
                        saveMessage = "保存に失敗しました"
                    }
                }
            }
        }
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
