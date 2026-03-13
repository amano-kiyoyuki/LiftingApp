import Foundation
import Vision
import AVFoundation
import Observation

@Observable
class LiftingCounter {
    var isEnabled = false
    var autoCount = 0
    var detectionConfidence: Float = 0
    var debugStatus = ""

    private var ankleHistory: [CGFloat] = []
    private let historySize = 10
    private var phase: Phase = .idle
    private var lastCountTime: Date = .distantPast
    private let cooldown: TimeInterval = 0.4
    private let riseThreshold: CGFloat = 0.03
    private let fallThreshold: CGFloat = 0.02

    private enum Phase {
        case idle
        case rising
    }

    private var request = VNDetectHumanBodyPoseRequest()

    var onCount: (() -> Void)?

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isEnabled else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first else {
            DispatchQueue.main.async {
                self.debugStatus = "人物未検出"
                self.detectionConfidence = 0
            }
            return
        }

        guard let leftAnkle = try? observation.recognizedPoint(.leftAnkle),
              let rightAnkle = try? observation.recognizedPoint(.rightAnkle) else {
            return
        }

        let confidence = max(leftAnkle.confidence, rightAnkle.confidence)

        // Use the higher ankle (the one being kicked up)
        // Vision coordinates: y=0 is bottom, y=1 is top
        let ankleY: CGFloat
        if leftAnkle.confidence > 0.3 && rightAnkle.confidence > 0.3 {
            ankleY = max(leftAnkle.location.y, rightAnkle.location.y)
        } else if leftAnkle.confidence > 0.3 {
            ankleY = leftAnkle.location.y
        } else if rightAnkle.confidence > 0.3 {
            ankleY = rightAnkle.location.y
        } else {
            DispatchQueue.main.async {
                self.debugStatus = "足首未検出"
                self.detectionConfidence = confidence
            }
            return
        }

        ankleHistory.append(ankleY)
        if ankleHistory.count > historySize {
            ankleHistory.removeFirst()
        }

        guard ankleHistory.count >= 3 else { return }

        let recent = ankleHistory.suffix(3)
        let baseline = ankleHistory.prefix(max(ankleHistory.count - 3, 1)).reduce(0, +)
            / CGFloat(max(ankleHistory.count - 3, 1))
        let current = recent.last!
        let delta = current - baseline

        let now = Date()

        switch phase {
        case .idle:
            if delta > riseThreshold {
                phase = .rising
                DispatchQueue.main.async {
                    self.debugStatus = "上昇検出"
                    self.detectionConfidence = confidence
                }
            } else {
                DispatchQueue.main.async {
                    self.debugStatus = "待機中"
                    self.detectionConfidence = confidence
                }
            }

        case .rising:
            if delta < fallThreshold && now.timeIntervalSince(lastCountTime) > cooldown {
                phase = .idle
                lastCountTime = now
                DispatchQueue.main.async {
                    self.autoCount += 1
                    self.debugStatus = "カウント!"
                    self.detectionConfidence = confidence
                    self.onCount?()
                }
            } else if delta > riseThreshold {
                DispatchQueue.main.async {
                    self.debugStatus = "上昇中..."
                    self.detectionConfidence = confidence
                }
            }
        }
    }

    func reset() {
        autoCount = 0
        ankleHistory.removeAll()
        phase = .idle
        debugStatus = ""
        detectionConfidence = 0
    }
}
