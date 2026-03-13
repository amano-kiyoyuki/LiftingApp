import Foundation
import AVFoundation
import Vision
import Observation

@Observable
class VideoAnalyzer {
    var isAnalyzing = false
    var progress: Double = 0
    var count = 0
    var debugStatus = ""
    var isCompleted = false
    var videoDurationSeconds: Int = 0

    private var ankleHistory: [CGFloat] = []
    private let historySize = 10
    private var phase: Phase = .idle
    private var lastCountFrameIndex: Int = -100
    private let riseThreshold: CGFloat = 0.03
    private let fallThreshold: CGFloat = 0.02

    private enum Phase {
        case idle
        case rising
    }

    private let request = VNDetectHumanBodyPoseRequest()

    func analyze(url: URL) async {
        await MainActor.run {
            isAnalyzing = true
            isCompleted = false
            progress = 0
            count = 0
            debugStatus = "分析準備中..."
            ankleHistory.removeAll()
            phase = .idle
            lastCountFrameIndex = -100
        }

        let asset = AVURLAsset(url: url)

        guard let duration = try? await asset.load(.duration),
              let track = try? await asset.loadTracks(withMediaType: .video).first else {
            await MainActor.run {
                debugStatus = "動画の読み込みに失敗しました"
                isAnalyzing = false
            }
            return
        }

        let durationSeconds = Int(CMTimeGetSeconds(duration))
        let nominalFrameRate = try? await track.load(.nominalFrameRate)
        let fps = nominalFrameRate ?? 30.0

        await MainActor.run {
            self.videoDurationSeconds = durationSeconds
            debugStatus = "分析中..."
        }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            await MainActor.run {
                debugStatus = "動画リーダーの作成に失敗しました"
                isAnalyzing = false
            }
            return
        }

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        trackOutput.alwaysCopiesSampleData = false

        guard reader.canAdd(trackOutput) else {
            await MainActor.run {
                debugStatus = "動画の読み込みに失敗しました"
                isAnalyzing = false
            }
            return
        }
        reader.add(trackOutput)

        guard reader.startReading() else {
            await MainActor.run {
                debugStatus = "動画の読み込みに失敗しました"
                isAnalyzing = false
            }
            return
        }

        let totalFrames = Int(Double(durationSeconds) * Double(fps))
        // Process every 3rd frame to match real-time behavior
        let skipInterval = 3
        var frameIndex = 0
        let cooldownFrames = Int(0.4 * Double(fps) / Double(skipInterval))

        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            frameIndex += 1
            if frameIndex % skipInterval != 0 { continue }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continue
            }

            if let observation = request.results?.first {
                processObservation(observation, frameIndex: frameIndex / skipInterval, cooldownFrames: cooldownFrames)
            }

            if frameIndex % (skipInterval * 10) == 0 {
                let currentProgress = totalFrames > 0 ? Double(frameIndex) / Double(totalFrames) : 0
                await MainActor.run {
                    self.progress = min(currentProgress, 1.0)
                }
            }
        }

        await MainActor.run {
            progress = 1.0
            isAnalyzing = false
            isCompleted = true
            debugStatus = "分析完了: \(count) 回検出"
        }
    }

    private func processObservation(_ observation: VNHumanBodyPoseObservation, frameIndex: Int, cooldownFrames: Int) {
        guard let leftAnkle = try? observation.recognizedPoint(.leftAnkle),
              let rightAnkle = try? observation.recognizedPoint(.rightAnkle) else {
            return
        }

        let ankleY: CGFloat
        if leftAnkle.confidence > 0.3 && rightAnkle.confidence > 0.3 {
            ankleY = max(leftAnkle.location.y, rightAnkle.location.y)
        } else if leftAnkle.confidence > 0.3 {
            ankleY = leftAnkle.location.y
        } else if rightAnkle.confidence > 0.3 {
            ankleY = rightAnkle.location.y
        } else {
            return
        }

        ankleHistory.append(ankleY)
        if ankleHistory.count > historySize {
            ankleHistory.removeFirst()
        }

        guard ankleHistory.count >= 3 else { return }

        let baseline = ankleHistory.prefix(max(ankleHistory.count - 3, 1)).reduce(0, +)
            / CGFloat(max(ankleHistory.count - 3, 1))
        let current = ankleHistory.last!
        let delta = current - baseline

        switch phase {
        case .idle:
            if delta > riseThreshold {
                phase = .rising
            }

        case .rising:
            if delta < fallThreshold && (frameIndex - lastCountFrameIndex) > cooldownFrames {
                phase = .idle
                lastCountFrameIndex = frameIndex
                DispatchQueue.main.async {
                    self.count += 1
                }
            } else if delta <= riseThreshold && delta >= fallThreshold {
                // still transitioning
            }
        }
    }

    func reset() {
        isAnalyzing = false
        isCompleted = false
        progress = 0
        count = 0
        debugStatus = ""
        videoDurationSeconds = 0
        ankleHistory.removeAll()
        phase = .idle
        lastCountFrameIndex = -100
    }
}
