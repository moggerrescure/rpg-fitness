import Foundation
import Combine

class BattleVM: ObservableObject {
    @Published var isSearching: Bool = false
    @Published var activeBattle: Battle?
    @Published var duelFinished: Bool = false
    @Published var winnerName: String = ""
    @Published var showCameraTracker: Bool = false
    
    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Bind to firebaseService activeBattle state
        firebaseService.$activeBattle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] battle in
                guard let self = self else { return }
                self.activeBattle = battle
                if let battle = battle, battle.status == .completed {
                    self.duelFinished = true
                    if let winnerId = battle.winnerId {
                        if winnerId == self.firebaseService.currentCharacter?.id {
                            self.winnerName = "VICTORY!"
                        } else {
                            self.winnerName = "DEFEAT!"
                        }
                    } else {
                        self.winnerName = "DRAW!"
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    var currentClass: CharacterClass {
        firebaseService.currentCharacter?.selectedClass ?? .swordsman
    }
    
    func startQueue() {
        isSearching = true
        firebaseService.startMatchmaking(for: currentClass) { [weak self] success in
            if success {
                self?.isSearching = false
                self?.showCameraTracker = true
            }
        }
    }
    
    func cancelQueue() {
        isSearching = false
        firebaseService.leaveMatch()
    }
    
    func endMatch() {
        firebaseService.leaveMatch()
        duelFinished = false
        showCameraTracker = false
    }
}
