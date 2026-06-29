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
    @Published var friendsList: [String] = []
    
    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Bind to firebaseService friends list
        firebaseService.$friends
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.friendsList = list
            }
            .store(in: &cancellables)
            
            
        // Bind to BattleEngine activeBattle state for Boss Raids
        BattleEngine.shared.$activeBattle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] battle in
                guard let self = self else { return }
                // Only process if it's a bossRaid
                if battle?.type == .bossRaid {
                    let oldBattle = self.activeBattle
                    self.activeBattle = battle
                    
                    if oldBattle == nil && battle != nil && battle?.status == .active {
                        self.showCameraTracker = true
                    }
                    
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
            }
            .store(in: &cancellables)
            
        // Bind to MultiplayerService activeBattle state for real 1v1, team3v3, clanWar PvP
        MultiplayerService.shared.$activeBattle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] battle in
                guard let self = self else { return }
                
                // CRITICAL: when leaveMatch()/endMatch() clears the battle, battle == nil.
                // nil?.type matches nothing in the type-check below, so BattleVM.activeBattle
                // would never be cleared → battle screen would stay visible forever.
                // Handle nil explicitly first.
                if battle == nil {
                    self.activeBattle = nil
                    self.duelFinished = false
                    self.showCameraTracker = false
                    return
                }
                
                // Only process if it's a known battle type
                if battle?.type == .bossRaid || battle?.type == .worldBoss || battle?.type == .duel1v1 || battle?.type == .clanWar || battle?.type == .team3v3 {
                    let oldBattle = self.activeBattle
                    self.activeBattle = battle
                    
                    // showCameraTracker opens CameraTrackingView as a fullScreenCover.
                    // For PvP (duel1v1, team3v3, clanWar) the camera is embedded inside
                    // CombatArenaView — do NOT set this flag or a duplicate "ARCHER CAMP"
                    // screen opens on top of the arena UI.
                    let isPvP = battle?.type == .duel1v1 || battle?.type == .team3v3 || battle?.type == .clanWar
                    if oldBattle == nil && battle != nil && battle?.status == .active && !isPvP {
                        self.showCameraTracker = true
                    }

                    
                    if let battle = battle, battle.status == .completed {
                        self.duelFinished = true
                        
                        if battle.type == .bossRaid || battle.type == .worldBoss {
                            // Calculate total damage dealt to the boss
                            if let bossPlayer = battle.opponentTeam.first {
                                let damageDealt = bossPlayer.maxHealth - bossPlayer.health
                                self.winnerName = "\(damageDealt) DMG!"
                                if battle.type == .worldBoss {
                                    self.firebaseService.attackWorldBoss(damage: damageDealt)
                                }
                            }
                        } else {
                            if let winnerId = battle.winnerId {
                                let won = winnerId == self.firebaseService.currentCharacter?.id
                                if won {
                                    self.winnerName = "VICTORY!"
                                } else {
                                    self.winnerName = "DEFEAT!"
                                }
                                
                                if self.selectedPvPType == .clanWar || battle.type == .clanWar {
                                    self.firebaseService.recordClanWarBattle(won: won)
                                }
                            } else {
                                self.winnerName = "DRAW!"
                                if self.selectedPvPType == .clanWar || battle.type == .clanWar {
                                    self.firebaseService.recordClanWarBattle(won: false)
                                }
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
            
        MultiplayerService.shared.$isSearching
            .receive(on: DispatchQueue.main)
            .sink { [weak self] searching in
                // Always forward isSearching state — the old guard on selectedPvPType
                // caused the matchmaking queue view to never appear if the type
                // hadn't been set yet when the update arrived.
                self?.isSearching = searching
            }
            .store(in: &cancellables)
    }
    
    var currentClass: CharacterClass {
        firebaseService.currentCharacter?.selectedClass ?? .swordsman
    }
    
    func startQueue(type: BattleType? = nil) {
        let queueType = type ?? selectedPvPType
        if queueType == .bossRaid {
            // Boss raids usually start their own queue through BossRaidView
            MultiplayerService.shared.startMatchmaking(for: currentClass, type: queueType, invitedFriends: invitedFriends)
        } else {
            MultiplayerService.shared.startMatchmaking(for: currentClass, type: queueType, invitedFriends: invitedFriends)
        }
    }
    
    func cancelQueue() {
        isSearching = false
        MultiplayerService.shared.leaveMatch()
    }
    
    func endMatch() {
        BattleEngine.shared.endBattle()
        MultiplayerService.shared.leaveMatch()
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
