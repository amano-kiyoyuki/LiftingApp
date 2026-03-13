import SwiftUI
import PhotosUI
import AVKit

struct VideoAnalysisView: View {
    @State private var analyzer = VideoAnalyzer()
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var showSaveConfirmation = false
    @State private var memo = ""
    @State private var editedCount: Int?
    @State private var isEditingCount = false
    @State private var countEditText = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    videoPickerSection
                    if videoURL != nil {
                        videoPreviewSection
                    }
                    if analyzer.isAnalyzing {
                        analysisProgressSection
                    }
                    if analyzer.isCompleted {
                        resultSection
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .navigationTitle("動画分析")
        }
        .onChange(of: selectedItem) {
            Task {
                await loadVideo()
            }
        }
    }

    // MARK: - Sections

    private var videoPickerSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .videos
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "film")
                        .font(.title2)
                    Text("動画を選択")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .disabled(analyzer.isAnalyzing)

            Text("撮影済みの動画からリフティング回数を自動判定します")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var videoPreviewSection: some View {
        VStack(spacing: 12) {
            if let videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if !analyzer.isAnalyzing && !analyzer.isCompleted {
                Button {
                    guard let url = videoURL else { return }
                    Task {
                        await analyzer.analyze(url: url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                        Text("分析開始")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
    }

    private var analysisProgressSection: some View {
        VStack(spacing: 12) {
            ProgressView(value: analyzer.progress) {
                Text("分析中...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(Int(analyzer.progress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .tint(.purple)

            Text("検出中: \(analyzer.count) 回")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.purple)
        }
        .padding()
        .background(.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var displayCount: Int {
        editedCount ?? analyzer.count
    }

    private var resultSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("分析結果")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if isEditingCount {
                    VStack(spacing: 8) {
                        TextField("回数", text: $countEditText)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)

                        HStack(spacing: 16) {
                            Button("キャンセル") {
                                isEditingCount = false
                            }
                            .buttonStyle(.bordered)

                            Button("確定") {
                                if let value = Int(countEditText), value >= 0 {
                                    editedCount = value
                                }
                                isEditingCount = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    Text("\(displayCount)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.purple)
                        .onTapGesture {
                            countEditText = "\(displayCount)"
                            isEditingCount = true
                        }

                    if editedCount != nil {
                        Text("(手動修正済み)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text("回")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                if !isEditingCount {
                    HStack(spacing: 12) {
                        Button {
                            let current = displayCount
                            if current > 0 { editedCount = current - 1 }
                        } label: {
                            Text("-1")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(width: 60, height: 40)
                        }
                        .buttonStyle(.bordered)
                        .disabled(displayCount == 0)

                        Text("タップして修正")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Button {
                            editedCount = displayCount + 1
                        } label: {
                            Text("+1")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(width: 60, height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            if analyzer.videoDurationSeconds > 0 {
                let minutes = analyzer.videoDurationSeconds / 60
                let seconds = analyzer.videoDurationSeconds % 60
                Text("動画時間: \(String(format: "%02d:%02d", minutes, seconds))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("メモ")
                    .font(.headline)
                TextField("例: 公園での練習動画", text: $memo, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button {
                    analyzer.reset()
                    videoURL = nil
                    selectedItem = nil
                    memo = ""
                    editedCount = nil
                    isEditingCount = false
                } label: {
                    Text("やり直す")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)

                Button {
                    saveRecord()
                } label: {
                    Text("記録を保存")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            if showSaveConfirmation {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("保存しました!")
                }
                .font(.subheadline)
                .foregroundStyle(.green)
                .transition(.opacity)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func loadVideo() async {
        analyzer.reset()
        showSaveConfirmation = false
        memo = ""
        editedCount = nil
        isEditingCount = false

        guard let item = selectedItem else {
            videoURL = nil
            return
        }

        do {
            if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
                videoURL = movie.url
            }
        } catch {
            videoURL = nil
        }
    }

    private func saveRecord() {
        // Copy video to app's Documents/Videos directory
        var savedFileName: String?
        if let sourceURL = videoURL {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Videos", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileName = "lifting_analysis_\(Int(Date().timeIntervalSince1970)).mov"
            let destURL = dir.appendingPathComponent(fileName)
            try? FileManager.default.copyItem(at: sourceURL, to: destURL)
            savedFileName = fileName
        }

        let record = PracticeRecord(
            count: displayCount,
            durationSeconds: analyzer.videoDurationSeconds,
            memo: memo.isEmpty ? "動画分析" : memo,
            videoFileName: savedFileName
        )
        modelContext.insert(record)

        withAnimation {
            showSaveConfirmation = true
        }
    }
}

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "video_\(Int(Date().timeIntervalSince1970)).\(received.file.pathExtension)"
            let destURL = tempDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: received.file, to: destURL)
            return Self(url: destURL)
        }
    }
}

#Preview {
    VideoAnalysisView()
        .modelContainer(for: PracticeRecord.self, inMemory: true)
}
