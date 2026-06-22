import Foundation
import Combine
import SwiftUI

// MARK: – Dungeon state

enum DungeonPhase: Equatable {
    case intro
    case combat(wave: Int)
    case waveClear(wave: Int)
    case victory
    case defeat
}

// MARK: – Boss definition

struct DungeonBoss {
    let id: String
    let name: String
    let subtitle: String
    let imageName: String          // Asset catalog name
    let color: Color               // Accent color
    let attackInterval: TimeInterval  // How often boss attacks (seconds)
    let attackDamage: Int          // Damage per attack when player is idle
    let repDamage: Int             // Damage player deals per rep
    var maxHP: Int
    var currentHP: Int

    static func wave(_ wave: Int, charLevel: Int) -> DungeonBoss {
        switch wave {
        case 1:
            let hp = 180 + charLevel * 8
            return DungeonBoss(
                id: "goblin_brute",
                name: "Goblin Brute",
                subtitle: "WAVE 1 · DUNGEON GUARDIAN",
                imageName: "boss_goblin_brute",
                color: Color(hex: "34D399"),
                attackInterval: 3.0,
                attackDamage: 8 + charLevel,
                repDamage: max(12, 200 / max(1, hp / 15)),
                maxHP: hp,
                currentHP: hp
            )
        case 2:
            let hp = 420 + charLevel * 14
            return DungeonBoss(
                id: "shadow_reaper",
                name: "Shadow Reaper",
                subtitle: "WAVE 2 · UNDEAD SENTINEL",
                imageName: "boss_shadow_reaper",
                color: Color(hex: "A78BFA"),
                attackInterval: 2.5,
                attackDamage: 15 + charLevel,
                repDamage: max(20, 350 / max(1, hp / 15)),
                maxHP: hp,
                currentHP: hp
            )
        default:
            let hp = 900 + charLevel * 20
            return DungeonBoss(
                id: "ancient_dragon",
                name: "Ancient Dragon",
                subtitle: "WAVE 3 · FINAL BOSS",
                imageName: "boss_ancient_dragon",
                color: Color(hex: "F97316"),
                attackInterval: 2.0,
                attackDamage: 25 + charLevel * 2,
                repDamage: max(30, 600 / max(1, hp / 15)),
                maxHP: hp,
                currentHP: hp
            )
        }
    }
}

// MARK: – ViewModel

@MainActor
class DungeonVM: ObservableObject {
    // Phase
    @Published var phase: DungeonPhase = .intro

    // Combat state
    @Published var boss: DungeonBoss?
    @Published var playerHP: Int = 100
    @Published var playerMaxHP: Int = 100
    @Published var repCount: Int = 0

    // Visual feedback
    @Published var bossShake: Bool = false
    @Published var playerFlash: Bool = false       // Red flash when player takes damage
    @Published var bossHPPercent: Double = 1.0
    @Published var playerHPPercent: Double = 1.0
    @Published var damageNumbers: [DamageNumber] = []
    @Published var lastCombo: Double = 1.0
    @Published var idleWarning: Bool = false        // Boss is about to attack

    // Loot
    @Published var droppedLoot: EquipmentItem?
    @Published var xpEarned: Int = 0
    @Published var goldEarned: Int = 0

    private var bossAttackTimer: AnyCancellable?
    private var idleWarningTimer: AnyCancellable?
    private var lastRepTime: Date = .distantPast
    private var cancellables = Set<AnyCancellable>()

    var currentWave: Int {
        switch phase {
        case .combat(let w): return w
        default: return 0
        }
    }

    init() {
        if let char = FirebaseService.shared.currentCharacter {
            let hp = 100 + char.level * 15
            playerMaxHP = hp
            playerHP = hp
            playerHPPercent = 1.0
        }
    }

    // MARK: – Public API

    func startDungeon() {
        phase = .combat(wave: 1)
        startWave(wave: 1)
    }

    func advanceWave() {
        guard case .waveClear(let w) = phase else { return }
        let next = w + 1
        phase = .combat(wave: next)
        startWave(wave: next)
    }

    func exitDungeon() {
        stopTimers()
        BattleEngine.shared.activeBattle = nil
        BattleEngine.shared.activeBoss = nil
    }

    /// Called by CameraTrackingVM / rep detection callback
    func onRepPerformed(combo: Double = 1.0) {
        guard case .combat = phase, var b = boss else { return }
        lastRepTime = Date()
        lastCombo = combo
        idleWarning = false

        // Player damages boss
        let dmg = Int(Double(b.repDamage) * max(1.0, combo))
        b.currentHP = max(0, b.currentHP - dmg)
        repCount += 1
        boss = b
        bossHPPercent = Double(b.currentHP) / Double(b.maxHP)

        // Damage number
        spawnDamageNumber(-dmg, isBossDmg: true)

        // Boss shake
        bossShake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.bossShake = false
        }

        // Check boss dead
        if b.currentHP <= 0 {
            handleWaveCleared()
        }
    }

    // MARK: – Private

    private func startWave(wave: Int) {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        repCount = 0
        var b = DungeonBoss.wave(wave, charLevel: char.level)
        boss = b
        bossHPPercent = 1.0
        lastRepTime = .distantPast
        idleWarning = false

        // Boss attack timer
        stopTimers()
        startBossAttackTimer(boss: b)
    }

    private func startBossAttackTimer(boss: DungeonBoss) {
        let interval = boss.attackInterval
        let damage = boss.attackDamage

        // Warning fires 1 second before boss attacks
        let warningInterval = max(0.5, interval - 1.0)

        bossAttackTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, case .combat = self.phase else { return }
                let timeSinceLastRep = Date().timeIntervalSince(self.lastRepTime)
                // Attack if player hasn't done a rep in the last `interval` seconds
                if timeSinceLastRep >= interval * 0.9 {
                    self.bossAttacksPlayer(damage: damage)
                }
                self.idleWarning = false
            }

        idleWarningTimer = Timer.publish(every: warningInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, case .combat = self.phase else { return }
                let timeSinceLastRep = Date().timeIntervalSince(self.lastRepTime)
                if timeSinceLastRep >= warningInterval * 0.9 {
                    self.idleWarning = true
                }
            }
    }

    private func bossAttacksPlayer(damage: Int) {
        playerHP = max(0, playerHP - damage)
        playerHPPercent = Double(playerHP) / Double(playerMaxHP)

        // Visual flash
        playerFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.playerFlash = false
        }

        spawnDamageNumber(-damage, isBossDmg: false)

        if playerHP <= 0 {
            stopTimers()
            phase = .defeat
        }
    }

    private func handleWaveCleared() {
        stopTimers()
        guard case .combat(let w) = phase else { return }

        if w >= 3 {
            phase = .victory
            grantVictoryRewards()
        } else {
            phase = .waveClear(wave: w)
        }
    }

    private func grantVictoryRewards() {
        xpEarned = 1000 + (boss?.maxHP ?? 0) / 10
        goldEarned = 500 + repCount * 5
        FirebaseService.shared.resolvePvEBattle(won: true, bossLootChance: 1.0, xp: xpEarned, gold: goldEarned) { droppedId in
            DispatchQueue.main.async {
                if let id = droppedId,
                   let item = EquipmentItem.findArmor(by: id) ?? EquipmentItem.findWeapon(by: id) {
                    self.droppedLoot = item
                }
            }
        }
    }

    private func stopTimers() {
        bossAttackTimer?.cancel()
        idleWarningTimer?.cancel()
        bossAttackTimer = nil
        idleWarningTimer = nil
    }

    private func spawnDamageNumber(_ value: Int, isBossDmg: Bool) {
        let id = UUID()
        let num = DamageNumber(id: id, value: value, isBossDamage: isBossDmg)
        damageNumbers.append(num)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.damageNumbers.removeAll { $0.id == id }
        }
    }
}

struct DamageNumber: Identifiable {
    let id: UUID
    let value: Int          // negative = damage dealt
    let isBossDamage: Bool  // true = player hits boss, false = boss hits player
}
