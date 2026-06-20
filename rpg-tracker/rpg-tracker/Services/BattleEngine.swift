import Foundation
import Combine

@MainActor
class BattleEngine: ObservableObject {
    static let shared = BattleEngine()
    
    @Published var activeBattle: Battle?
    @Published var activeBoss: Boss?
    @Published var droppedLoot: EquipmentItem?
    
    private var battleTimer: Timer?
    
    private init() {}
    
    func startBossRaid(bossTemplate: Boss, player: Character) {
        let localPlayer = BattlePlayer(
            id: player.id,
            name: player.username,
            characterClass: player.selectedClass,
            health: 100 + (player.level * 15),
            maxHealth: 100 + (player.level * 15),
            avatarName: player.avatarName
        )
        
        let newBattle = Battle(
            id: "raid_\(UUID().uuidString.prefix(6))",
            type: .bossRaid,
            status: .active,
            localTeam: [localPlayer],
            opponentTeam: [], // Boss is handled separately in activeBoss
            secondsRemaining: 120 // 2 minutes to beat the boss
        )
        
        // Scale boss stats based on player level
        var scaledBoss = bossTemplate
        scaledBoss.maxHealth += player.level * 40
        scaledBoss.currentHealth = scaledBoss.maxHealth
        scaledBoss.attackPower += player.level * 2
        
        self.activeBoss = scaledBoss
        self.activeBattle = newBattle
        
        startTimer()
    }
    
    func startBotDuel(botTemplate: Boss, player: Character, type: BattleType = .duel1v1) {
        let localPlayer = BattlePlayer(
            id: player.id,
            name: player.username,
            characterClass: player.selectedClass,
            health: 100 + (player.level * 10), // Use PvP health formula
            maxHealth: 100 + (player.level * 10),
            avatarName: player.avatarName
        )
        
        // Scale bot stats based on player level
        var scaledBot = botTemplate
        scaledBot.maxHealth += player.level * 30
        scaledBot.currentHealth = scaledBot.maxHealth
        scaledBot.attackPower += player.level * 2
        
        let oppPlayer = BattlePlayer(
            id: scaledBot.id,
            name: scaledBot.name,
            characterClass: .swordsman, // default for bot
            health: scaledBot.maxHealth,
            maxHealth: scaledBot.maxHealth,
            avatarName: scaledBot.avatarName
        )
        
        let newBattle = Battle(
            id: "bot_duel_\(UUID().uuidString.prefix(6))",
            type: type,
            status: .active,
            localTeam: [localPlayer],
            opponentTeam: [oppPlayer],
            secondsRemaining: 60 // 1 minute for duels
        )
        
        self.activeBoss = scaledBot
        self.activeBattle = newBattle
        
        startTimer()
    }
    
    private func startTimer() {
        droppedLoot = nil
        battleTimer?.invalidate()
        battleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func tick() {
        guard var battle = activeBattle, var boss = activeBoss else { return }
        guard battle.status == .active else {
            battleTimer?.invalidate()
            return
        }
        
        battle.secondsRemaining -= 1
        
        let isEnraged = Double(boss.currentHealth) < Double(boss.maxHealth) * 0.5
        let currentInterval = isEnraged ? boss.attackInterval * 0.7 : boss.attackInterval
        
        // Use a persistent property or just math to find if it's time to attack
        // To avoid state, check if elapsed crossed a multiple of currentInterval
        let totalElapsed = 120 - battle.secondsRemaining
        let prevElapsed = 120 - (battle.secondsRemaining + 1)
        
        if totalElapsed > 0 && Int(Double(totalElapsed) / currentInterval) > Int(Double(prevElapsed) / currentInterval) {
            performBossAttack(boss: &boss, battle: &battle, isEnraged: isEnraged)
        }
        
        // Check win/loss
        if battle.type == .duel1v1 {
            // Duel win conditions: time runs out or someone dies
            let localDead = battle.localTeam.first?.isDead == true
            let oppDead = battle.opponentTeam.first?.isDead == true
            
            if localDead {
                battle.status = .completed
                battle.winnerId = battle.opponentTeam.first?.id
                battleTimer?.invalidate()
                FirebaseService.shared.awardBattleRewards(xp: 50, gold: 15, isPvP: true)
                FirebaseService.shared.activeBattle = nil
            } else if oppDead {
                battle.status = .completed
                battle.winnerId = battle.localTeam.first?.id
                battleTimer?.invalidate()
                FirebaseService.shared.awardBattleRewards(xp: 250, gold: 60, isPvP: true)
                FirebaseService.shared.activeBattle = nil
            } else if battle.secondsRemaining <= 0 {
                battle.status = .completed
                let myReps = battle.localTeam.first?.reps ?? 0
                let oppReps = battle.opponentTeam.first?.reps ?? 0
                
                if myReps > oppReps {
                    battle.winnerId = battle.localTeam.first?.id
                    FirebaseService.shared.awardBattleRewards(xp: 250, gold: 60, isPvP: true)
                } else if oppReps > myReps {
                    battle.winnerId = battle.opponentTeam.first?.id
                    FirebaseService.shared.awardBattleRewards(xp: 50, gold: 15, isPvP: true)
                } else {
                    battle.winnerId = "draw"
                    FirebaseService.shared.awardBattleRewards(xp: 100, gold: 30, isPvP: true)
                }
                
                battleTimer?.invalidate()
            }
        } else {
            // Boss Raid win conditions
            if battle.localTeam.first?.isDead == true || battle.secondsRemaining <= 0 {
                battle.status = .completed
                battle.winnerId = "boss"
                battleTimer?.invalidate()
            } else if boss.currentHealth <= 0 {
                battle.status = .completed
                battle.winnerId = battle.localTeam.first?.id
                battleTimer?.invalidate()
                
                // Server-Side Loot & Rewards resolution
                FirebaseService.shared.resolvePvEBattle(won: true, bossLootChance: boss.lootDropChance, xp: boss.xpReward, gold: boss.goldReward) { droppedId in
                    DispatchQueue.main.async {
                        if let id = droppedId, let item = EquipmentItem.findArmor(by: id) ?? EquipmentItem.findWeapon(by: id) {
                            self.droppedLoot = item
                            // The server already granted XP, Gold, and the Item.
                            // The local Firestore snapshot listener will automatically update `currentCharacter`.
                        }
                    }
                }
            }
        }
        
        self.activeBattle = battle
        self.activeBoss = boss
    }
    
    private func performBossAttack(boss: inout Boss, battle: inout Battle, isEnraged: Bool) {
        guard var player = battle.localTeam.first, !player.isDead else { return }
        
        let now = Date()
        var usedSkill: BossSkill? = nil
        
        // Find a skill that is off cooldown
        for i in 0..<boss.skills.count {
            let skill = boss.skills[i]
            if let lastUsed = skill.lastUsedAt {
                if now.timeIntervalSince(lastUsed) >= skill.cooldown {
                    usedSkill = skill
                    boss.skills[i].lastUsedAt = now
                    break
                }
            } else {
                usedSkill = skill
                boss.skills[i].lastUsedAt = now
                break
            }
        }
        
        var damage = isEnraged ? Int(Double(boss.attackPower) * 1.5) : boss.attackPower
        var skillText = ""
        var isUnblockable = false
        
        if let skill = usedSkill {
            damage = Int(Double(damage) * skill.damageMultiplier)
            skillText = "[SKILL: \(skill.name)] "
            isUnblockable = skill.isUnblockable
        }
        
        // Apply player defense
        if !isUnblockable {
            if let char = FirebaseService.shared.currentCharacter,
               let armorId = char.equippedArmorId,
               let armor = EquipmentItem.findArmor(by: armorId) {
                damage = max(1, damage - armor.defense)
            }
        } else {
            skillText += "(Unblockable) "
        }
        
        player.health = max(0, player.health - damage)
        battle.localTeam[0] = player
        
        // If it's a duel, also update the bot's reps
        if battle.type == .duel1v1, !battle.opponentTeam.isEmpty {
            battle.opponentTeam[0].reps += 1
        }
        
        let enrageText = isEnraged ? "[ENRAGED] " : ""
        let event = CombatEvent(
            actorName: boss.name,
            targetName: player.name,
            actionType: usedSkill != nil ? .skill : .attack,
            value: damage,
            detailText: "\(enrageText)\(skillText)\(boss.name) strikes for \(damage) DMG!"
        )
        battle.combatLog.append(event)
    }
    
    func registerPlayerRepetition(isCorrectForm: Bool = true, isCritical: Bool = false) {
        guard var battle = activeBattle, var boss = activeBoss, battle.status == .active else { return }
        guard var player = battle.localTeam.first, !player.isDead else { return }
        
        player.reps += 1
        battle.localTeam[0] = player
        
        // Calculate damage
        let basePower = FirebaseService.shared.currentCharacter?.combatPower ?? 10
        var damage = Int(Double(basePower) * 0.15) // 15% of combat power per rep
        
        if !isCorrectForm {
            damage = max(1, damage / 2) // 50% damage penalty for bad form
        }
        
        if battle.type == .duel1v1 && !battle.opponentTeam.isEmpty {
            battle.opponentTeam[0].health = max(0, battle.opponentTeam[0].health - damage)
        } else {
            boss.currentHealth = max(0, boss.currentHealth - damage)
            if boss.isGlobalWorldBoss {
                FirebaseService.shared.attackWorldBoss(damage: damage)
            }
        }
        
        let formText = isCorrectForm ? "" : "[BAD FORM] "
        let critText = isCritical ? "[CRIT] " : ""
        let event = CombatEvent(
            actorName: player.name,
            targetName: boss.name,
            actionType: .attack,
            value: damage,
            detailText: "\(formText)\(critText)\(player.name) hits for \(damage) DMG!",
            isCritical: isCritical
        )
        battle.combatLog.append(event)
        
        self.activeBattle = battle
        self.activeBoss = boss
    }
    
    func endBattle() {
        battleTimer?.invalidate()
        activeBattle = nil
        activeBoss = nil
    }
}
