import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

@Observable
class CameraManager {
    let session = AVCaptureSession()
    var isAuthorized = false
    var isRunning = false
    var isRecording = false
    var isFrontCamera = false
    var lastRecordedURL: URL?

    private var movieOutput = AVCaptureMovieFileOutput()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var recordingDelegate = RecordingDelegate()
    private var frameDelegate: FrameDelegate?
    private var hasConfigured = false
    private var currentVideoInput: AVCaptureDeviceInput?

    var onFrame: ((CMSampleBuffer) -> Void)? {
        didSet {
            frameDelegate?.onFrame = onFrame
        }
    }

    func requestAccess() async {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch videoStatus {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }

        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if audioStatus == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .audio)
        }
    }

    func startSession() {
        guard isAuthorized, !isRunning else { return }

        if !hasConfigured {
            configureSession()
            hasConfigured = true
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
    }

    func stopSession() {
        guard isRunning else { return }
        if isRecording {
            stopRecording()
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
    }

    func switchCamera() {
        guard isRunning, !isRecording else { return }

        let newPosition: AVCaptureDevice.Position = isFrontCamera ? .back : .front
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }

        session.beginConfiguration()

        if let currentVideoInput {
            session.removeInput(currentVideoInput)
        }

        if session.canAddInput(newInput) {
            session.addInput(newInput)
            currentVideoInput = newInput
            isFrontCamera = newPosition == .front
        }

        session.commitConfiguration()
    }

    func startRecording() {
        guard isRunning, !isRecording else { return }

        let fileName = "lifting_\(Int(Date().timeIntervalSince1970)).mov"
        let outputURL = videosDirectory().appendingPathComponent(fileName)

        recordingDelegate.onFinish = { [weak self] url in
            DispatchQueue.main.async {
                self?.isRecording = false
                self?.lastRecordedURL = url
            }
        }

        movieOutput.startRecording(to: outputURL, recordingDelegate: recordingDelegate)
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
           session.canAddInput(videoInput) {
            session.addInput(videoInput)
            currentVideoInput = videoInput
        }

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        let delegate = FrameDelegate()
        delegate.onFrame = onFrame
        frameDelegate = delegate

        videoDataOutput.setSampleBufferDelegate(delegate, queue: DispatchQueue(label: "com.liftingapp.vision", qos: .userInitiated))
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }

        session.commitConfiguration()
    }

    func videosDirectory() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

private class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    var onFinish: ((URL) -> Void)?

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            onFinish?(outputFileURL)
        }
    }
}

private class FrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFrame: ((CMSampleBuffer) -> Void)?

    // Process every 3rd frame to reduce CPU load
    private var frameCount = 0

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCount += 1
        guard frameCount % 3 == 0 else { return }
        onFrame?(sampleBuffer)
    }
}
