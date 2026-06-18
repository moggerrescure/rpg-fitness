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
    
    let selectedClass: CharacterClass
    private let tracker = VisionTracker()
    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(selectedClass: CharacterClass) {
        self.selectedClass = selectedClass
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
        // If a PvP duel is active, register rep to damage opponent
        if firebaseService.activeBattle != nil {
            firebaseService.registerLocalRepetition()
        } else {
            // Otherwise add training XP/Gold rewards
            firebaseService.awardBattleRewards(xp: 15, gold: 5)
        }
    }
}
