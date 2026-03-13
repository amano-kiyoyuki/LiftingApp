import Foundation
import Observation
import SwiftData

@Observable
class PracticeViewModel {
    var isActive = false
    var count = 0
    var memo = ""
    var elapsedSeconds: TimeInterval = 0
    var didSave = false
    var recordedVideoFileName: String?
    var isEditingCount = false

    private var timer: Timer?
    private var startDate: Date?

    var elapsedText: String {
        let total = Int(elapsedSeconds)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var canSave: Bool {
        !isActive && count > 0 && !didSave
    }

    func start() {
        isActive = true
        count = 0
        memo = ""
        elapsedSeconds = 0
        didSave = false
        recordedVideoFileName = nil
        isEditingCount = false
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let startDate = self.startDate else { return }
            self.elapsedSeconds = Date().timeIntervalSince(startDate)
        }
    }

    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
        startDate = nil
    }

    func increment() {
        guard isActive else { return }
        count += 1
    }

    func decrement() {
        guard count > 0 else { return }
        count -= 1
    }

    func setCount(_ newCount: Int) {
        count = max(0, newCount)
    }

    func resetCount() {
        count = 0
    }

    func save(modelContext: ModelContext) {
        let record = PracticeRecord(
            count: count,
            durationSeconds: Int(elapsedSeconds),
            memo: memo,
            videoFileName: recordedVideoFileName
        )
        modelContext.insert(record)
        didSave = true
    }
}
