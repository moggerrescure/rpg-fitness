import Foundation
import Combine
import SwiftUI

enum DungeonState: String {
    case intro = "Dungeon Entrance"
    case wave1 = "Wave 1: Guardian"
    case wave1Clear = "Wave 1 Cleared"
    case wave2 = "Wave 2: Elite Guardian"
    case wave2Clear = "Wave 2 Cleared"
    case wave3 = "Wave 3: Dungeon Boss"
    case victory = "Dungeon Cleared"
    case defeat = "Defeated"
}

@MainActor
class DungeonVM: ObservableObject {
    @Published var currentState: DungeonState = .intro
    @Published var currentBoss: Boss?
    @Published var activeBattle: Battle?
    @Published var showCameraTracker = false
    @Published var droppedLoot: EquipmentItem? = nil
    
    // Dungeon specific progress
    @Published var playerHealth: Int = 0
    @Published var playerMaxHealth: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        if let char = FirebaseService.shared.currentCharacter {
            playerMaxHealth = 100 + (char.level * 15)
            playerHealth = playerMaxHealth
        }
        
        // Listen to BattleEngine
        BattleEngine.shared.$activeBattle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] battle in
                guard let self = self, let battle = battle else { return }
                
                // Only process dungeon battles
                if battle.type != .bossRaid { return } // reusing bossRaid type or create a new one. We will use a custom battle id.
                guard battle.id.starts(with: "dungeon_") else { return }
                
                self.activeBattle = battle
                
                // Track player health from battle to persist across waves
                if let localPlayer = battle.localTeam.first {
                    self.playerHealth = localPlayer.health
                }
                
                if battle.status == .completed {
                    if let winnerId = battle.winnerId {
                        if winnerId == FirebaseService.shared.currentCharacter?.id {
                            // Player won the wave
                            self.handleWaveCleared()
                        } else {
                            // Player lost
                            self.currentState = .defeat
                        }
                    } else {
                        // Draw/Time out
                        self.currentState = .defeat
                    }
                    self.activeBattle = nil
                    self.showCameraTracker = false
                }
            }
            .store(in: &cancellables)
    }
    
    func startDungeon() {
        currentState = .wave1
        startWave()
    }
    
    private func handleWaveCleared() {
        switch currentState {
        case .wave1:
            currentState = .wave1Clear
        case .wave2:
            currentState = .wave2Clear
        case .wave3:
            currentState = .victory
            generateDungeonReward()
        default:
            break
        }
    }
    
    func advanceWave() {
        switch currentState {
        case .wave1Clear:
            currentState = .wave2
            startWave()
        case .wave2Clear:
            currentState = .wave3
            startWave()
        default:
            break
        }
    }
    
    private func startWave() {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        
        var template: Boss
        
        switch currentState {
        case .wave1:
            template = Boss.templates.first { $0.id == "boss_goblin" } ?? Boss.templates[0]
            template.maxHealth = 200 + (char.level * 10)
        case .wave2:
            template = Boss.templates.first { $0.id == "boss_orc" } ?? Boss.templates[1]
            template.maxHealth = 500 + (char.level * 15)
        case .wave3:
            template = Boss.templates.first { $0.id == "boss_dragon" } ?? Boss.templates.last!
            template.maxHealth = 1200 + (char.level * 20)
        default:
            return
        }
        template.currentHealth = template.maxHealth
        
        self.currentBoss = template
        
        let localPlayer = BattlePlayer(
            id: char.id,
            name: char.username,
            characterClass: char.selectedClass,
            health: self.playerHealth,
            maxHealth: self.playerMaxHealth,
            avatarName: char.avatarName
        )
        
        let newBattle = Battle(
            id: "dungeon_\(UUID().uuidString)",
            type: .bossRaid, // Reusing bossRaid mechanics
            status: .active,
            localTeam: [localPlayer],
            opponentTeam: [],
            secondsRemaining: 120
        )
        
        // Start via BattleEngine directly (bypass startBossRaid wrapper to inject our custom battle)
        BattleEngine.shared.activeBattle = newBattle
        BattleEngine.shared.activeBoss = template
        
        self.showCameraTracker = true
    }
    
    private func generateDungeonReward() {
        FirebaseService.shared.resolvePvEBattle(won: true, bossLootChance: 1.0, xp: 1000, gold: 500) { droppedId in
            DispatchQueue.main.async {
                if let id = droppedId, let item = EquipmentItem.findArmor(by: id) ?? EquipmentItem.findWeapon(by: id) {
                    self.droppedLoot = item
                }
            }
        }
    }
    
    func exitDungeon() {
        self.activeBattle = nil
        BattleEngine.shared.activeBattle = nil
        BattleEngine.shared.activeBoss = nil
    }
}
