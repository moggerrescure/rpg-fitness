import Foundation
import Vision
import CoreGraphics
import Combine

// MARK: - Agnostic Joint Mapping

enum AgnosticJointName: Sendable {
    case neck, root
    case shoulder, elbow, wrist
    case hip, knee, ankle
}

enum MovementMetric: Sendable {
    case angle(AgnosticJointName, AgnosticJointName, AgnosticJointName)
    case distance(AgnosticJointName, AgnosticJointName)
    case projectionY(AgnosticJointName, AgnosticJointName)
    /// Euclidean distance normalized by torso height (shoulder→hip)
    case normalizedDistance(AgnosticJointName, AgnosticJointName)
    /// Y-projection normalized by torso height
    case normalizedProjectionY(AgnosticJointName, AgnosticJointName)
    indirect case fallback(primary: MovementMetric, secondary: MovementMetric)
}

struct PhaseThresholds: Sendable {
    let relaxed: Double
    let contracted: Double
    let hysteresis: Double
}

struct PhaseTexts: Sendable {
    let contracting: String
    let contracted: String
    let extending: String
    let relaxed: String
}

struct BiomechanicsProfile: Sendable {
    let exerciseName: String
    let metric: MovementMetric
    let thresholds: PhaseThresholds
    let maxOccludedFrames: Int
    let texts: PhaseTexts
}

// MARK: - Side Selector
final class SideSelector {
    private var leftScore: Float = 0
    private var rightScore: Float = 0
    private let smoothingAlpha: Float = 0.25
    private let switchHysteresis: Float = 0.3

    private(set) var preferLeft: Bool = true

    func update(points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        let leftJoints: [VNHumanBodyPoseObservation.JointName] =
            [.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle]
        let rightJoints: [VNHumanBodyPoseObservation.JointName] =
            [.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle]

        let rawLeft  = leftJoints.compactMap  { points[$0]?.confidence }.reduce(0, +)
        let rawRight = rightJoints.compactMap { points[$0]?.confidence }.reduce(0, +)

        leftScore  = smoothingAlpha * rawLeft  + (1 - smoothingAlpha) * leftScore
        rightScore = smoothingAlpha * rawRight + (1 - smoothingAlpha) * rightScore

        if preferLeft && rightScore > leftScore + switchHysteresis {
            preferLeft = false
        } else if !preferLeft && leftScore > rightScore + switchHysteresis {
            preferLeft = true
        }
    }
}

// MARK: - Biomechanics Math

enum BiomechanicsMath {
    static func extractAgnosticJoints(
        from points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        preferLeft: Bool? = nil
    ) -> [AgnosticJointName: CGPoint] {
        var agnostic: [AgnosticJointName: CGPoint] = [:]

        let isLeft: Bool
        if let forced = preferLeft {
            isLeft = forced
        } else {
            let lScore = [points[.leftShoulder], points[.leftElbow], points[.leftWrist],
                          points[.leftHip], points[.leftKnee], points[.leftAnkle]]
                .compactMap { $0?.confidence }.reduce(0, +)
            let rScore = [points[.rightShoulder], points[.rightElbow], points[.rightWrist],
                          points[.rightHip], points[.rightKnee], points[.rightAnkle]]
                .compactMap { $0?.confidence }.reduce(0, +)
            isLeft = lScore >= rScore
        }

        let threshold: Float = 0.2

        func add(_ name: AgnosticJointName,
                 left: VNHumanBodyPoseObservation.JointName,
                 right: VNHumanBodyPoseObservation.JointName) {
            let target = isLeft ? left : right
            if let pt = points[target], pt.confidence > threshold {
                agnostic[name] = CGPoint(x: pt.location.x, y: pt.location.y)
            }
        }

        add(.shoulder, left: .leftShoulder, right: .rightShoulder)
        add(.elbow,    left: .leftElbow,    right: .rightElbow)
        add(.wrist,    left: .leftWrist,    right: .rightWrist)
        add(.hip,      left: .leftHip,      right: .rightHip)
        add(.knee,     left: .leftKnee,     right: .rightKnee)
        add(.ankle,    left: .leftAnkle,    right: .rightAnkle)

        if let neck = points[.neck] ?? points[.nose], neck.confidence > threshold {
            agnostic[.neck] = CGPoint(x: neck.location.x, y: neck.location.y)
        }
        if let root = points[.root], root.confidence > threshold {
            agnostic[.root] = CGPoint(x: root.location.x, y: root.location.y)
        }

        return agnostic
    }

    static func torsoHeight(joints: [AgnosticJointName: CGPoint]) -> Double? {
        guard let sh = joints[.shoulder], let hip = joints[.hip] else { return nil }
        let h = distance(p1: sh, p2: hip)
        return h > 0.04 ? h : nil
    }

    static func distance(p1: CGPoint, p2: CGPoint) -> Double {
        return hypot(p1.x - p2.x, p1.y - p2.y)
    }

    static func angleBetween(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
        let v1 = CGVector(dx: p1.x - p2.x, dy: p1.y - p2.y)
        let v2 = CGVector(dx: p3.x - p2.x, dy: p3.y - p2.y)

        let dotProduct = (v1.dx * v2.dx) + (v1.dy * v2.dy)
        let magnitude1 = hypot(v1.dx, v1.dy)
        let magnitude2 = hypot(v2.dx, v2.dy)
        guard magnitude1 > 0, magnitude2 > 0 else { return 0.0 }

        let cosineAngle = max(-1.0, min(1.0, dotProduct / (magnitude1 * magnitude2)))
        return acos(cosineAngle) * (180.0 / .pi)
    }

    static func projectedDistanceY(p1: CGPoint, p2: CGPoint) -> Double {
        return abs(p1.y - p2.y)
    }

    static func amplitudePercentage(current: Double, relaxed: Double, contracted: Double) -> Double {
        let totalRange = contracted - relaxed
        guard totalRange != 0 else { return 0.0 }
        let progress = (current - relaxed) / totalRange
        return max(0.0, min(100.0, progress * 100.0))
    }
}

// MARK: - Exercise Registry

enum RPGExerciseRegistry: Sendable {
    static func profile(for characterClass: CharacterClass) -> BiomechanicsProfile {
        switch characterClass {
        case .archer:
            // Squats
            return BiomechanicsProfile(exerciseName: "Squats",
                metric: .fallback(primary: .angle(.hip, .knee, .ankle), secondary: .angle(.shoulder, .hip, .knee)),
                thresholds: PhaseThresholds(relaxed: 165.0, contracted: 90.0, hysteresis: 15.0),
                maxOccludedFrames: 10,
                texts: PhaseTexts(contracting: "Going down...", contracted: "Deep squat! Push up", extending: "Stand tall", relaxed: "Ready"))
        case .mage:
            // Push-ups
            return BiomechanicsProfile(exerciseName: "Push-ups",
                metric: .angle(.shoulder, .elbow, .wrist),
                thresholds: PhaseThresholds(relaxed: 160.0, contracted: 90.0, hysteresis: 15.0),
                maxOccludedFrames: 8,
                texts: PhaseTexts(contracting: "Lower your body...", contracted: "Chest low! Press up", extending: "Lock out", relaxed: "Arms straight"))
        case .swordsman:
            // Pull-ups (Vertical Pull)
            // Vision y is normalized, 0 at top, 1 at bottom (since we flipped it in CameraManager: 1 - location.y)
            return BiomechanicsProfile(exerciseName: "Pull-ups",
                metric: .normalizedProjectionY(.wrist, .shoulder),
                thresholds: PhaseThresholds(relaxed: 1.1, contracted: 0.25, hysteresis: 0.15),
                maxOccludedFrames: 8,
                texts: PhaseTexts(contracting: "Pull up!", contracted: "Chin over bar!", extending: "Lower down slowly", relaxed: "Hang straight"))
        case .healer:
            // Dips
            return BiomechanicsProfile(exerciseName: "Dips",
                metric: .angle(.shoulder, .elbow, .wrist),
                thresholds: PhaseThresholds(relaxed: 160.0, contracted: 90.0, hysteresis: 15.0),
                maxOccludedFrames: 8,
                texts: PhaseTexts(contracting: "Lower into the dip...", contracted: "Push back up!", extending: "Extend arms", relaxed: "Ready"))
        }
    }
}

// MARK: - Movement Phase & Tracking State

enum MovementPhase: Sendable {
    case relaxed, contracting, contracted, extending, unknown
}

struct TrackingState: Sendable {
    var phase: MovementPhase = .unknown
    var repsCount: Int = 0
    var currentAmplitude: Double = 0.0

    fileprivate var missingFramesCount: Int = 0
    fileprivate var lastValidMetricValue: Double? = nil
    fileprivate var smoothedMetricValue: Double? = nil
}

// MARK: - RepetitionTracker

final class RepetitionTracker {
    private let profile: BiomechanicsProfile
    private(set) var state: TrackingState

    private let emaAlphaMin: Double = 0.15
    private let emaAlphaMax: Double = 0.80

    init(profile: BiomechanicsProfile) {
        self.profile = profile
        self.state = TrackingState()
    }

    func process(joints: [AgnosticJointName: CGPoint]) -> TrackingState {
        guard let rawMetricValue = extractMetricValue(profile.metric, from: joints) else {
            return handleOcclusion()
        }

        state.missingFramesCount = 0
        state.lastValidMetricValue = rawMetricValue

        let smoothed: Double
        if let prev = state.smoothedMetricValue {
            let alpha = adaptiveAlpha(current: rawMetricValue, previous: prev)
            smoothed = alpha * rawMetricValue + (1.0 - alpha) * prev
        } else {
            smoothed = rawMetricValue
        }
        state.smoothedMetricValue = smoothed

        state.currentAmplitude = BiomechanicsMath.amplitudePercentage(
            current: smoothed,
            relaxed: profile.thresholds.relaxed,
            contracted: profile.thresholds.contracted
        )

        updatePhase(with: smoothed)
        return state
    }

    private func adaptiveAlpha(current: Double, previous: Double) -> Double {
        let totalRange = abs(profile.thresholds.contracted - profile.thresholds.relaxed)
        guard totalRange > 0 else { return 0.4 }

        let delta = abs(current - previous)
        let normalizedVelocity = min(1.0, delta / (totalRange * 0.15))

        return emaAlphaMin + normalizedVelocity * (emaAlphaMax - emaAlphaMin)
    }

    private func handleOcclusion() -> TrackingState {
        state.missingFramesCount += 1
        if state.missingFramesCount > profile.maxOccludedFrames {
            state.phase = .unknown
            state.currentAmplitude = 0.0
            state.lastValidMetricValue = nil
        }
        return state
    }

    private func updatePhase(with value: Double) {
        let t = profile.thresholds
        let isDecreasing = t.contracted < t.relaxed

        let reachedContracted = isDecreasing
            ? (value <= t.contracted + t.hysteresis)
            : (value >= t.contracted - t.hysteresis)
        let reachedRelaxed = isDecreasing
            ? (value >= t.relaxed - t.hysteresis)
            : (value <= t.relaxed + t.hysteresis)

        switch state.phase {
        case .unknown, .relaxed:
            if !reachedRelaxed {
                state.phase = .contracting
            }
        case .contracting:
            if reachedContracted {
                state.phase = .contracted
            } else if reachedRelaxed {
                state.phase = .relaxed
            }
        case .contracted:
            if !reachedContracted { state.phase = .extending }
        case .extending:
            if reachedRelaxed {
                state.phase = .relaxed
                state.repsCount += 1
            } else if reachedContracted {
                state.phase = .contracted
            }
        }
    }

    private func extractMetricValue(
        _ metric: MovementMetric,
        from joints: [AgnosticJointName: CGPoint]
    ) -> Double? {
        switch metric {
        case .angle(let j1, let j2, let j3):
            guard let p1 = joints[j1], let p2 = joints[j2], let p3 = joints[j3] else { return nil }
            return BiomechanicsMath.angleBetween(p1: p1, p2: p2, p3: p3)

        case .distance(let j1, let j2):
            guard let p1 = joints[j1], let p2 = joints[j2] else { return nil }
            return BiomechanicsMath.distance(p1: p1, p2: p2)

        case .projectionY(let j1, let j2):
            guard let p1 = joints[j1], let p2 = joints[j2] else { return nil }
            return BiomechanicsMath.projectedDistanceY(p1: p1, p2: p2)

        case .normalizedDistance(let j1, let j2):
            guard let p1 = joints[j1], let p2 = joints[j2] else { return nil }
            let raw = BiomechanicsMath.distance(p1: p1, p2: p2)
            guard let torso = BiomechanicsMath.torsoHeight(joints: joints) else {
                return raw
            }
            return raw / torso

        case .normalizedProjectionY(let j1, let j2):
            guard let p1 = joints[j1], let p2 = joints[j2] else { return nil }
            let raw = BiomechanicsMath.projectedDistanceY(p1: p1, p2: p2)
            guard let torso = BiomechanicsMath.torsoHeight(joints: joints) else {
                return raw
            }
            return raw / torso

        case .fallback(let primary, let secondary):
            return extractMetricValue(primary, from: joints)
                ?? extractMetricValue(secondary, from: joints)
        }
    }
}

// MARK: - AITrackerEngine

@MainActor
final class AITrackerEngine: ObservableObject {
    @Published private(set) var repsCount: Int = 0
    @Published private(set) var feedbackMessage: String = "Initializing AI..."
    @Published private(set) var isCorrectForm: Bool = true
    @Published private(set) var isPersonDetected: Bool = false

    private var profile: BiomechanicsProfile?
    private var repetitionTracker: RepetitionTracker?
    private let sideSelector = SideSelector()

    init() { }

    func setExercise(_ characterClass: CharacterClass) {
        self.profile = RPGExerciseRegistry.profile(for: characterClass)
        
        if let profile = self.profile {
            self.repetitionTracker = RepetitionTracker(profile: profile)
            self.feedbackMessage = profile.texts.relaxed
        }
    }

    func processFrame(joints rawJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]?) {
        guard let tracker = repetitionTracker, let profile = self.profile else { return }
        guard let rawJoints = rawJoints, !rawJoints.isEmpty else {
            self.isPersonDetected = false
            return
        }

        self.isPersonDetected = true

        // SideSelector only needs to know if the joint exists (since CameraManager filtered by confidence > 0.2)
        sideSelector.updateSidePreference(points: rawJoints)

        let agnosticJoints = BiomechanicsMath.extractAgnosticJoints(
            from: rawJoints,
            preferLeft: sideSelector.preferLeft
        )

        let state = tracker.process(joints: agnosticJoints)
        syncStateToUI(state: state, profile: profile)
    }

    private func syncStateToUI(state: TrackingState, profile: BiomechanicsProfile) {
        if self.repsCount != state.repsCount {
            self.repsCount = state.repsCount
        }

        let newFeedback: String
        switch state.phase {
        case .relaxed:     
            newFeedback = profile.texts.relaxed
            self.isCorrectForm = true
        case .contracting: 
            newFeedback = profile.texts.contracting
            self.isCorrectForm = true
        case .contracted:  
            newFeedback = profile.texts.contracted
            self.isCorrectForm = true
        case .extending:   
            newFeedback = profile.texts.extending
            self.isCorrectForm = true
        case .unknown:     
            newFeedback = "Body parts occluded. Adjust camera!"
            self.isCorrectForm = false
        }

        if self.feedbackMessage != newFeedback {
            self.feedbackMessage = newFeedback
        }
    }

    func simulateRepetition() {
        self.repsCount += 1
        self.isCorrectForm = true
        self.feedbackMessage = "Perfect form! Rep counted +1"
        self.isPersonDetected = true
    }

    func reset() {
        self.repsCount = 0
        self.isPersonDetected = false
        if let profile = self.profile {
            self.repetitionTracker = RepetitionTracker(profile: profile)
            self.feedbackMessage = profile.texts.relaxed
        }
    }
}

// SideSelector extension for dictionary checks
extension SideSelector {
    func updateSidePreference(points: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        let leftJoints: [VNHumanBodyPoseObservation.JointName] =
            [.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle]
        let rightJoints: [VNHumanBodyPoseObservation.JointName] =
            [.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle]

        let rawLeft = Float(leftJoints.filter { points[$0] != nil }.count)
        let rawRight = Float(rightJoints.filter { points[$0] != nil }.count)

        leftScore  = smoothingAlpha * rawLeft  + (1 - smoothingAlpha) * leftScore
        rightScore = smoothingAlpha * rawRight + (1 - smoothingAlpha) * rightScore

        if preferLeft && rightScore > leftScore + switchHysteresis {
            preferLeft = false
        } else if !preferLeft && leftScore > rightScore + switchHysteresis {
            preferLeft = true
        }
    }
}

extension BiomechanicsMath {
    static func extractAgnosticJoints(
        from points: [VNHumanBodyPoseObservation.JointName: CGPoint],
        preferLeft: Bool
    ) -> [AgnosticJointName: CGPoint] {
        var agnostic: [AgnosticJointName: CGPoint] = [:]

        func add(_ name: AgnosticJointName,
                 left: VNHumanBodyPoseObservation.JointName,
                 right: VNHumanBodyPoseObservation.JointName) {
            let target = preferLeft ? left : right
            if let pt = points[target] {
                agnostic[name] = pt
            }
        }

        add(.shoulder, left: .leftShoulder, right: .rightShoulder)
        add(.elbow,    left: .leftElbow,    right: .rightElbow)
        add(.wrist,    left: .leftWrist,    right: .rightWrist)
        add(.hip,      left: .leftHip,      right: .rightHip)
        add(.knee,     left: .leftKnee,     right: .rightKnee)
        add(.ankle,    left: .leftAnkle,    right: .rightAnkle)

        if let pt = points[.neck] ?? points[.nose] {
            agnostic[.neck] = pt
        }
        if let pt = points[.root] {
            agnostic[.root] = pt
        }

        return agnostic
    }
}
