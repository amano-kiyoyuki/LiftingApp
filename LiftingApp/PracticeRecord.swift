import Foundation
import SwiftData

@Model
class PracticeRecord {
    var date: Date
    var count: Int
    var durationSeconds: Int
    var memo: String
    var videoFileName: String?

    init(date: Date = .now, count: Int, durationSeconds: Int, memo: String, videoFileName: String? = nil) {
        self.date = date
        self.count = count
        self.durationSeconds = durationSeconds
        self.memo = memo
        self.videoFileName = videoFileName
    }

    var durationText: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var videoURL: URL? {
        guard let videoFileName else { return nil }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Videos", isDirectory: true)
        let url = dir.appendingPathComponent(videoFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
