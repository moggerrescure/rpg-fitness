import Foundation
import Combine
import SwiftUI

class CameraTrackingVM: ObservableObject {
    @Published var repCount: Int = 0
    @Published var isPersonDetected: Bool = false
    @Published var isCorrectForm: Bool = true
    @Published var feedbackMessage: String = "Place your device 2 meters away"
    @Published var isSimulatorMode: Bool = true // Default to simulator mode for ease of local testing
    
    @Published var skeletonPoints: [JointPoint] = []
    @Published var skeletonLines: [BoneLine] = []
    
    // Boss HP & Combat Metrics
    @Published var bossMaxHP: Int = 0
    @Published var bossCurrentHP: Int = 0
    @Published var damagePerRep: Int = 0
    @Published var hpBarShake: Bool = false
    @Published var hpBarBurn: Bool = false
    @Published var activeCombo: Double = 1.0
    @Published var comboCount: Int = 0
    @Published var floatingComboBadge: String? = nil
    
    let selectedClass: CharacterClass
    let targetReps: Int?
    var onComplete: ((Int) -> Void)?
    
    private let tracker = VisionTracker()
    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastRepTimestamp: Date? = nil
    private var hasTriggeredCompletion = false
    
    init(selectedClass: CharacterClass, targetReps: Int? = nil, bossMaxHP: Int? = nil, damagePerRep: Int? = nil, onComplete: ((Int) -> Void)? = nil) {
        self.selectedClass = selectedClass
        self.onComplete = onComplete
        
        let maxHP = bossMaxHP ?? 0
        let dmg = damagePerRep ?? 0
        self.bossMaxHP = maxHP
        self.bossCurrentHP = maxHP
        self.damagePerRep = dmg
        
        if maxHP > 0 && dmg > 0 {
            self.targetReps = Int(ceil(Double(maxHP) / Double(dmg)))
        } else {
            self.targetReps = targetReps
        }
        
        tracker.setExercise(selectedClass)
        tracker.isSimulatorMode = self.isSimulatorMode
        
        setupBindings()
    }
    
    private func setupBindings() {
        tracker.$repCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newCount in
                guard let self = self else { return }
                if newCount > self.repCount {
                    self.repCount = newCount
                    self.onRepetitionPerformed()
                }
            }
            .store(in: &cancellables)
            
        tracker.$isPersonDetected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPersonDetected)
            
        tracker.$isCorrectForm
            .receive(on: DispatchQueue.main)
            .assign(to: &$isCorrectForm)
            
        tracker.$currentFeedback
            .receive(on: DispatchQueue.main)
            .assign(to: &$feedbackMessage)
            
        tracker.$bodySkeletonPoints
            .receive(on: DispatchQueue.main)
            .assign(to: &$skeletonPoints)
            
        tracker.$bodySkeletonLines
            .receive(on: DispatchQueue.main)
            .assign(to: &$skeletonLines)
            
        $isSimulatorMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.tracker.isSimulatorMode = mode
            }
            .store(in: &cancellables)
    }
    
    func simulateRep() {
        tracker.simulateRepetition()
    }
    
    private func onRepetitionPerformed() {
        // Compute speed cadence for combo multipliers
        let now = Date()
        if let last = lastRepTimestamp {
            let diff = now.timeIntervalSince(last)
            if diff < 2.2 {
                comboCount += 1
                let multiplier = 1.0 + Double(min(10, comboCount)) * 0.1 // Max 2.0x multiplier
                activeCombo = multiplier
                hpBarBurn = true
                
                // Trigger shake on combo hits
                if comboCount % 2 == 0 {
                    hpBarShake = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                        // Keep shaking if boss is low HP
                        if let self = self, Double(self.bossCurrentHP) / Double(self.bossMaxHP) > 0.25 {
                            self.hpBarShake = false
                        }
                    }
                }
                
                floatingComboBadge = String(format: "COMBO x%.1f!", activeCombo)
                
                // Auto-clear floating badge
                let currentCombo = multiplier
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    if self?.activeCombo == currentCombo {
                        self?.floatingComboBadge = nil
                    }
                }
            } else {
                comboCount = 0
                activeCombo = 1.0
                if Double(bossCurrentHP) / Double(bossMaxHP) > 0.25 {
                    hpBarBurn = false
                    hpBarShake = false
                }
            }
        } else {
            // First rep starts combo chain
            comboCount = 1
            activeCombo = 1.0
        }
        lastRepTimestamp = now
        
        // Apply damage if combat details are configured
        if bossMaxHP > 0 {
            let actualDmg = Int(Double(damagePerRep) * activeCombo)
            bossCurrentHP = max(0, bossCurrentHP - actualDmg)
            
            // Check if boss HP falls below threshold (25% left)
            if Double(bossCurrentHP) / Double(bossMaxHP) <= 0.25 {
                hpBarBurn = true
                hpBarShake = true
            }
        }
        
        // Record reps to character profile
        if firebaseService.activeBattle != nil {
            firebaseService.registerLocalRepetition()
        } else {
            firebaseService.awardBattleRewards(xp: 15, gold: 5)
        }
        
        // Check complete conditions
        if !hasTriggeredCompletion {
            if bossMaxHP > 0 {
                if bossCurrentHP <= 0 {
                    hasTriggeredCompletion = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard let self = self else { return }
                        self.onComplete?(self.repCount)
                    }
                }
            } else if let target = targetReps, repCount >= target {
                hasTriggeredCompletion = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    self.onComplete?(self.repCount)
                }
            }
        }
    }
}
