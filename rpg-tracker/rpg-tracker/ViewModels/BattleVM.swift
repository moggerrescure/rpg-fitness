import Foundation
import Combine

class BattleVM: ObservableObject {
    @Published var isSearching: Bool = false
    @Published var activeBattle: Battle?
    @Published var duelFinished: Bool = false
    @Published var winnerName: String = ""
    @Published var showCameraTracker: Bool = false
    
    // PvP selector additions
    @Published var selectedPvPType: BattleType = .duel1v1
    @Published var invitedFriends: [String] = []
    
    let friendsList: [String] = ["AquaHealer", "FireMage", "WindArcher", "KnightDave"]
    
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
        firebaseService.startMatchmaking(
            for: currentClass,
            type: selectedPvPType,
            invitedFriends: invitedFriends
        ) { [weak self] success in
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
        invitedFriends.removeAll() // Clear invited friends after match
    }
    
    // Friend slot manager
    func inviteFriend(_ name: String) {
        guard invitedFriends.count < 2 else { return }
        if !invitedFriends.contains(name) {
            invitedFriends.append(name)
        }
    }
    
    func removeFriend(_ name: String) {
        if let idx = invitedFriends.firstIndex(of: name) {
            invitedFriends.remove(at: idx)
        }
    }
}
