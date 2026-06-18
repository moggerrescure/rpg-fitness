import Foundation
import Vision
import AVFoundation
import Combine
import SwiftUI

struct JointPoint: Identifiable {
    let id = UUID()
    let name: String
    let point: CGPoint // Normalized coordinates (0 to 1)
}

struct BoneLine: Identifiable {
    let id = UUID()
    let start: CGPoint
    let end: CGPoint
}

class VisionTracker: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var repCount: Int = 0
    @Published var isPersonDetected: Bool = false
    @Published var bodySkeletonPoints: [JointPoint] = []
    @Published var bodySkeletonLines: [BoneLine] = []
    @Published var isCorrectForm: Bool = true
    @Published var currentFeedback: String = "Align your entire body in frame"
    @Published var isSimulatorMode: Bool = false
    
    // Joint angle or distance state machines
    private var activeExercise: CharacterClass = .archer
    private var repState: RepState = .starting
    private let detectionQueue = DispatchQueue(label: "com.fitrpg.detectionQueue", qos: .userInteractive)
    
    private enum RepState {
        case starting
        case inProgress
        case peakReached
    }
    
    func setExercise(_ exerciseClass: CharacterClass) {
        self.activeExercise = exerciseClass
        self.repCount = 0
        self.repState = .starting
        self.currentFeedback = "Prepare for \(exerciseClass.primaryExercise)"
    }
    
    // SIMULATOR MOCK TRIGGER
    func simulateRepetition() {
        repCount += 1
        isCorrectForm = true
        currentFeedback = "Perfect form! Rep counted +1"
        // Generate mock skeleton movements
        generateMockSkeleton()
    }
    
    // Real Camera Session Hook (Setup helper)
    func processFrame(sampleBuffer: CMSampleBuffer) {
        guard !isSimulatorMode else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self else { return }
            if let results = request.results as? [VNHumanBodyPoseObservation], let observation = results.first {
                DispatchQueue.main.async {
                    self.isPersonDetected = true
                    self.analyzePose(observation)
                }
            } else {
                DispatchQueue.main.async {
                    self.isPersonDetected = false
                    self.bodySkeletonPoints = []
                    self.bodySkeletonLines = []
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    // Core Vision pose analytics
    private func analyzePose(_ observation: VNHumanBodyPoseObservation) {
        // Retrieve key joints
        guard
            let nose = try? observation.recognizedPoint(.nose),
            let neck = try? observation.recognizedPoint(.neck),
            let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
            let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
            let leftElbow = try? observation.recognizedPoint(.leftElbow),
            let rightElbow = try? observation.recognizedPoint(.rightElbow),
            let leftWrist = try? observation.recognizedPoint(.leftWrist),
            let rightWrist = try? observation.recognizedPoint(.rightWrist),
            let leftHip = try? observation.recognizedPoint(.leftHip),
            let rightHip = try? observation.recognizedPoint(.rightHip),
            let leftKnee = try? observation.recognizedPoint(.leftKnee),
            let rightKnee = try? observation.recognizedPoint(.rightKnee),
            let leftAnkle = try? observation.recognizedPoint(.leftAnkle),
            let rightAnkle = try? observation.recognizedPoint(.rightAnkle)
        else {
            return
        }
        
        // Ensure confidence thresholds are met (e.g. > 0.3)
        let joints = [
            ("nose", nose), ("neck", neck), 
            ("leftShoulder", leftShoulder), ("rightShoulder", rightShoulder),
            ("leftElbow", leftElbow), ("rightElbow", rightElbow),
            ("leftWrist", leftWrist), ("rightWrist", rightWrist),
            ("leftHip", leftHip), ("rightHip", rightHip),
            ("leftKnee", leftKnee), ("rightKnee", rightKnee),
            ("leftAnkle", leftAnkle), ("rightAnkle", rightAnkle)
        ]
        
        // Map UI points (Vision uses normalized coords with 0,0 at bottom-left)
        // Convert y coordinate for SwiftUI (0,0 at top-left)
        self.bodySkeletonPoints = joints.filter { $0.1.confidence > 0.3 }.map { name, joint in
            JointPoint(name: name, point: CGPoint(x: joint.location.x, y: 1.0 - joint.location.y))
        }
        
        // Build skeletal bone lines
        buildBones(observation)
        
        // Trigger specific exercise progression logic
        switch activeExercise {
        case .archer:
            trackSquat(leftHip: leftHip, leftKnee: leftKnee, leftAnkle: leftAnkle)
        case .mage:
            trackPushup(shoulder: leftShoulder, elbow: leftElbow, wrist: leftWrist)
        case .swordsman:
            trackPullup(neck: neck, leftWrist: leftWrist, rightWrist: rightWrist)
        case .healer:
            trackDip(shoulder: leftShoulder, elbow: leftElbow, wrist: leftWrist)
        }
    }
    
    // Exercise Rep State Machine Rules
    private func trackSquat(leftHip: VNRecognizedPoint, leftKnee: VNRecognizedPoint, leftAnkle: VNRecognizedPoint) {
        guard leftHip.confidence > 0.4 && leftKnee.confidence > 0.4 && leftAnkle.confidence > 0.4 else { return }
        
        // Squat logic: angle at knee between Hip and Ankle
        let hipLoc = leftHip.location
        let kneeLoc = leftKnee.location
        let ankleLoc = leftAnkle.location
        
        let angle = calculateAngle(p1: hipLoc, p2: kneeLoc, p3: ankleLoc)
        
        if repState == .starting && angle < 100 {
            repState = .inProgress
            currentFeedback = "Going down... keep balance"
        } else if repState == .inProgress && angle < 85 {
            repState = .peakReached
            currentFeedback = "Deep squat reached! Push up"
        } else if repState == .peakReached && angle > 150 {
            repState = .starting
            repCount += 1
            isCorrectForm = true
            currentFeedback = "Squat counted!"
        }
    }
    
    private func trackPushup(shoulder: VNRecognizedPoint, elbow: VNRecognizedPoint, wrist: VNRecognizedPoint) {
        guard shoulder.confidence > 0.4 && elbow.confidence > 0.4 && wrist.confidence > 0.4 else { return }
        
        let angle = calculateAngle(p1: shoulder.location, p2: elbow.location, p3: wrist.location)
        
        if repState == .starting && angle > 150 {
            repState = .inProgress
            currentFeedback = "Lower your body"
        } else if repState == .inProgress && angle < 95 {
            repState = .peakReached
            currentFeedback = "Chest low enough! Press up"
        } else if repState == .peakReached && angle > 145 {
            repState = .starting
            repCount += 1
            isCorrectForm = true
            currentFeedback = "Push-up counted!"
        }
    }
    
    private func trackPullup(neck: VNRecognizedPoint, leftWrist: VNRecognizedPoint, rightWrist: VNRecognizedPoint) {
        guard neck.confidence > 0.4 && (leftWrist.confidence > 0.4 || rightWrist.confidence > 0.4) else { return }
        
        let avgWristY = (leftWrist.location.y + rightWrist.location.y) / 2
        let neckY = neck.location.y
        
        // Vision y goes up, so chin above wrist means neckY > avgWristY
        if repState == .starting && neckY < avgWristY {
            repState = .inProgress
            currentFeedback = "Pull yourself up!"
        } else if repState == .inProgress && neckY >= avgWristY {
            repState = .peakReached
            currentFeedback = "Chin above bar! Lower down slowly"
        } else if repState == .peakReached && neckY < (avgWristY - 0.15) {
            repState = .starting
            repCount += 1
            isCorrectForm = true
            currentFeedback = "Pull-up counted!"
        }
    }
    
    private func trackDip(shoulder: VNRecognizedPoint, elbow: VNRecognizedPoint, wrist: VNRecognizedPoint) {
        guard shoulder.confidence > 0.4 && elbow.confidence > 0.4 && wrist.confidence > 0.4 else { return }
        
        let angle = calculateAngle(p1: shoulder.location, p2: elbow.location, p3: wrist.location)
        
        if repState == .starting && angle > 150 {
            repState = .inProgress
            currentFeedback = "Lower into the dip"
        } else if repState == .inProgress && angle < 100 {
            repState = .peakReached
            currentFeedback = "Push back up!"
        } else if repState == .peakReached && angle > 145 {
            repState = .starting
            repCount += 1
            isCorrectForm = true
            currentFeedback = "Dip counted!"
        }
    }
    
    private func calculateAngle(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
        let v1 = CGPoint(x: p1.x - p2.x, y: p1.y - p2.y)
        let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        
        let angle1 = atan2(v1.y, v1.x)
        let angle2 = atan2(v2.y, v2.x)
        
        var angle = (angle1 - angle2) * 180 / .pi
        if angle < 0 { angle += 360 }
        return angle > 180 ? 360 - angle : angle
    }
    
    private func buildBones(_ observation: VNHumanBodyPoseObservation) {
        var lines: [BoneLine] = []
        
        let boneJointPairs = [
            (VNHumanBodyPoseObservation.JointName.neck, VNHumanBodyPoseObservation.JointName.nose),
            (VNHumanBodyPoseObservation.JointName.neck, VNHumanBodyPoseObservation.JointName.leftShoulder),
            (VNHumanBodyPoseObservation.JointName.neck, VNHumanBodyPoseObservation.JointName.rightShoulder),
            (VNHumanBodyPoseObservation.JointName.leftShoulder, VNHumanBodyPoseObservation.JointName.leftElbow),
            (VNHumanBodyPoseObservation.JointName.leftElbow, VNHumanBodyPoseObservation.JointName.leftWrist),
            (VNHumanBodyPoseObservation.JointName.rightShoulder, VNHumanBodyPoseObservation.JointName.rightElbow),
            (VNHumanBodyPoseObservation.JointName.rightElbow, VNHumanBodyPoseObservation.JointName.rightWrist),
            (VNHumanBodyPoseObservation.JointName.leftShoulder, VNHumanBodyPoseObservation.JointName.leftHip),
            (VNHumanBodyPoseObservation.JointName.rightShoulder, VNHumanBodyPoseObservation.JointName.rightHip),
            (VNHumanBodyPoseObservation.JointName.leftHip, VNHumanBodyPoseObservation.JointName.rightHip),
            (VNHumanBodyPoseObservation.JointName.leftHip, VNHumanBodyPoseObservation.JointName.leftKnee),
            (VNHumanBodyPoseObservation.JointName.leftKnee, VNHumanBodyPoseObservation.JointName.leftAnkle),
            (VNHumanBodyPoseObservation.JointName.rightHip, VNHumanBodyPoseObservation.JointName.rightKnee),
            (VNHumanBodyPoseObservation.JointName.rightKnee, VNHumanBodyPoseObservation.JointName.rightAnkle)
        ]
        
        for (j1, j2) in boneJointPairs {
            if let pt1 = try? observation.recognizedPoint(j1), pt1.confidence > 0.3,
               let pt2 = try? observation.recognizedPoint(j2), pt2.confidence > 0.3 {
                lines.append(
                    BoneLine(
                        start: CGPoint(x: pt1.location.x, y: 1.0 - pt1.location.y),
                        end: CGPoint(x: pt2.location.x, y: 1.0 - pt2.location.y)
                    )
                )
            }
        }
        
        self.bodySkeletonLines = lines
    }
    
    private func generateMockSkeleton() {
        // Generate mock points inside the camera frame
        isPersonDetected = true
        let mockHead = CGPoint(x: 0.5, y: 0.2)
        let mockNeck = CGPoint(x: 0.5, y: 0.3)
        let mockLShoulder = CGPoint(x: 0.4, y: 0.35)
        let mockRShoulder = CGPoint(x: 0.6, y: 0.35)
        
        bodySkeletonPoints = [
            JointPoint(name: "nose", point: mockHead),
            JointPoint(name: "neck", point: mockNeck),
            JointPoint(name: "leftShoulder", point: mockLShoulder),
            JointPoint(name: "rightShoulder", point: mockRShoulder)
        ]
        
        bodySkeletonLines = [
            BoneLine(start: mockHead, end: mockNeck),
            BoneLine(start: mockNeck, end: mockLShoulder),
            BoneLine(start: mockNeck, end: mockRShoulder)
        ]
    }
}
