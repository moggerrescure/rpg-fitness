import SwiftUI
import AVFoundation
import Vision
import Combine

// MARK: - CameraManager

@MainActor
final class CameraManager: ObservableObject {
    @Published var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var bodyPose: VNHumanBodyPoseObservation? = nil
    var isAuthorized = false
    var authorizationStatus: AVAuthorizationStatus = .notDetermined
    var isSimulator = false

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var cameraDelegate: CameraDelegate?

    init() { }

    deinit {
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        if session.isRunning {
            session.stopRunning()
        }
    }

    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status

        switch status {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.authorizationStatus = granted ? .authorized : .denied
                    self?.isAuthorized = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func setupSession() {
        guard !session.isRunning else { return }
        session.beginConfiguration()

        session.sessionPreset = .hd1280x720 // High res for Vision accuracy

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            #if targetEnvironment(simulator)
            Task { @MainActor in self.isSimulator = true }
            #endif
            return
        }

        try? videoDevice.lockForConfiguration()
        if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
            videoDevice.focusMode = .continuousAutoFocus
        }
        if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
            videoDevice.exposureMode = .continuousAutoExposure
        }
        videoDevice.unlockForConfiguration()

        session.addInput(videoInput)

        let delegate = CameraDelegate(
            onUpdate: { [weak self] newJoints in
                Task { @MainActor in self?.joints = newJoints }
            },
            onBodyPoseUpdate: { [weak self] newBodyPose in
                Task { @MainActor in self?.bodyPose = newBodyPose }
            }
        )
        self.cameraDelegate = delegate

        videoOutput.alwaysDiscardsLateVideoFrames = true

        let cameraQueue = DispatchQueue(label: "com.rpgfitness.cameraQueue", qos: .userInitiated)
        videoOutput.setSampleBufferDelegate(delegate, queue: cameraQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
                connection.isVideoMirrored = true
            }
        }

        session.commitConfiguration()
        Task.detached { [weak self] in self?.session.startRunning() }
    }

    func stopSession() {
        if session.isRunning {
            Task.detached { [weak self] in self?.session.stopRunning() }
        }
    }
}

// MARK: - FrameCounter

final class FrameCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func incrementAndCheck(stride: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count % stride == 0
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        count = 0
    }
}

// MARK: - VisionProcessor

final class VisionProcessor: @unchecked Sendable {
    private let bodyRequest: VNDetectHumanBodyPoseRequest = {
        let req = VNDetectHumanBodyPoseRequest()
        return req
    }()

    func process(sampleBuffer: CMSampleBuffer) throws -> (
        joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        bodyPose: VNHumanBodyPoseObservation?
    ) {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        try handler.perform([bodyRequest])

        let bodyObservation = bodyRequest.results?.first
        var normalizedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

        if let body = bodyObservation,
           let recognizedPoints = try? body.recognizedPoints(.all) {
            // Lower threshold to 0.2 to handle movement blur better
            for (key, point) in recognizedPoints where point.confidence > 0.2 {
                normalizedJoints[key] = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
            }
        }

        return (normalizedJoints, bodyObservation)
    }
}

// MARK: - CameraDelegate

final class CameraDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    private let onUpdate: @Sendable ([VNHumanBodyPoseObservation.JointName: CGPoint]) -> Void
    private let onBodyPoseUpdate: @Sendable (VNHumanBodyPoseObservation?) -> Void

    private let bodyFrameCounter = FrameCounter()
    private let visionProcessor = VisionProcessor()

    init(
        onUpdate: @escaping @Sendable ([VNHumanBodyPoseObservation.JointName: CGPoint]) -> Void,
        onBodyPoseUpdate: @escaping @Sendable (VNHumanBodyPoseObservation?) -> Void
    ) {
        self.onUpdate = onUpdate
        self.onBodyPoseUpdate = onBodyPoseUpdate
        super.init()
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Process body pose every 2 frames for performance
        let shouldProcessBody = bodyFrameCounter.incrementAndCheck(stride: 2)

        guard shouldProcessBody else { return }

        do {
            let result = try visionProcessor.process(sampleBuffer: sampleBuffer)
            onBodyPoseUpdate(result.bodyPose)
            onUpdate(result.joints)
        } catch {
            if (error as NSError).code != -10810 {
                print("⚠️ Vision request failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CameraPreview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}

// MARK: - PoseOverlayView

struct PoseOverlayView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let themeColor: Color

    private static let lines: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder), (.neck, .rightShoulder), (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip), (.leftHip, .rightHip),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.neck, .nose), (.nose, .leftEye), (.nose, .rightEye),
        (.leftEye, .leftEar), (.rightEye, .rightEar)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    for line in Self.lines {
                        if let p1 = joints[line.0], let p2 = joints[line.1] {
                            path.move(to: CGPoint(x: p1.x * geometry.size.width,
                                                  y: p1.y * geometry.size.height))
                            path.addLine(to: CGPoint(x: p2.x * geometry.size.width,
                                                     y: p2.y * geometry.size.height))
                        }
                    }
                }
                .stroke(themeColor.opacity(0.8),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                ForEach(Array(joints.keys), id: \.self) { key in
                    if let point = joints[key] {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .position(x: point.x * geometry.size.width,
                                      y: point.y * geometry.size.height)
                            .shadow(color: themeColor, radius: 4)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
