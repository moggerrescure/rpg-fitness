import Foundation

enum BattleType: String, Codable, Equatable {
    case duel1v1 = "1v1 Duel"
    case team3v3 = "3v3 Team Battle"
    case bossRaid = "Boss Raid"
    case clanWar = "Clan War Battle"
    case worldBoss = "World Boss"
}

enum BattleStatus: String, Codable, Equatable {
    case searching = "Searching..."
    case active = "Active Combat"
    case completed = "Finished"
}

struct BattlePlayer: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var characterClass: CharacterClass
    var health: Int
    var maxHealth: Int
    var reps: Int = 0
    var shield: Int = 0
    var avatarName: String? = "avatar_knight"
    
    var isDead: Bool {
        health <= 0
    }
}

enum CombatActionType: String, Codable {
    case attack = "Attack"
    case heal = "Heal"
    case shield = "Shield"
    case debuff = "Debuff"
    case skill = "Skill"
}

struct CombatEvent: Codable, Identifiable {
    var id: String = UUID().uuidString
    var timestamp: Date = Date()
    var actorName: String
    var targetName: String
    var actionType: CombatActionType
    var value: Int
    var detailText: String
    var isCritical: Bool?
}

struct Battle: Codable, Identifiable, Equatable {
    var id: String
    var type: BattleType
    var status: BattleStatus
    var localTeam: [BattlePlayer]
    var opponentTeam: [BattlePlayer]
    var winnerId: String? = nil
    var surrenderedBy: String? = nil
    /// Uids allowed to write combat state (rules). Set on create; immutable for clients.
    var participantUids: [String] = []
    var createdAt: Date = Date()
    var secondsRemaining: Int = 60
    var combatLog: [CombatEvent] = []
    
    static func == (lhs: Battle, rhs: Battle) -> Bool {
        lhs.id == rhs.id
            && lhs.status == rhs.status
            && lhs.winnerId == rhs.winnerId
            && lhs.surrenderedBy == rhs.surrenderedBy
            && lhs.localTeam == rhs.localTeam
            && lhs.opponentTeam == rhs.opponentTeam
            && lhs.combatLog.count == rhs.combatLog.count
            && lhs.secondsRemaining == rhs.secondsRemaining
    }

    mutating func ensureParticipantUids() {
        if participantUids.isEmpty {
            participantUids = Array(Set(localTeam.map(\.id) + opponentTeam.map(\.id)))
                .filter { !Self.isBotPlayerId($0) }
        }
    }

    /// Bot / NPC combatants created by CF or client fallback (`bot_…`, `bot_fallback_…`, `bot_cwar_…`).
    static func isBotPlayerId(_ id: String) -> Bool {
        let lower = id.lowercased()
        return lower.hasPrefix("bot") || lower.contains("_bot_")
    }

    var hasBotCombatants: Bool {
        localTeam.contains { Self.isBotPlayerId($0.id) }
            || opponentTeam.contains { Self.isBotPlayerId($0.id) }
    }

    /// One AI pulse: one random alive opponent bot hits a local, one ally bot hits an opponent.
    /// Returns whether any damage was applied (server-orientation teams: host localTeam).
    @discardableResult
    mutating func applyBotCombatTick(damagePerHit: Int) -> Bool {
        let dmg = max(1, damagePerHit)
        var didHit = false

        let oppBotIndices = opponentTeam.indices.filter {
            !opponentTeam[$0].isDead && Self.isBotPlayerId(opponentTeam[$0].id)
        }
        if let oi = oppBotIndices.randomElement() {
            let aliveLocals = localTeam.enumerated().filter { !$0.element.isDead }
            if let target = aliveLocals.randomElement() {
                let before = localTeam[target.offset].health
                localTeam[target.offset].health = max(0, before - dmg)
                opponentTeam[oi].reps += 1
                combatLog.append(CombatEvent(
                    actorName: opponentTeam[oi].name,
                    targetName: localTeam[target.offset].name,
                    actionType: .attack,
                    value: dmg,
                    detailText: "\(opponentTeam[oi].name) strikes for \(dmg) DMG!"
                ))
                didHit = true
            }
        }

        let allyBotIndices = localTeam.indices.filter {
            !localTeam[$0].isDead && Self.isBotPlayerId(localTeam[$0].id)
        }
        if let li = allyBotIndices.randomElement() {
            let aliveOpps = opponentTeam.enumerated().filter { !$0.element.isDead }
            if let target = aliveOpps.randomElement() {
                let before = opponentTeam[target.offset].health
                opponentTeam[target.offset].health = max(0, before - dmg)
                localTeam[li].reps += 1
                combatLog.append(CombatEvent(
                    actorName: localTeam[li].name,
                    targetName: opponentTeam[target.offset].name,
                    actionType: .attack,
                    value: dmg,
                    detailText: "\(localTeam[li].name) strikes for \(dmg) DMG!"
                ))
                didHit = true
            }
        }

        return didHit
    }

    /// Local forfeit: mark completed and set winner to the opposing side.
    mutating func applyLocalSurrender(by uid: String) {
        status = .completed
        surrenderedBy = uid
        let onLocal = localTeam.contains { $0.id == uid }
        if onLocal {
            winnerId = opponentTeam.first?.id ?? "opp"
        } else if opponentTeam.contains(where: { $0.id == uid }) {
            winnerId = localTeam.first?.id ?? "opp"
        } else {
            winnerId = opponentTeam.first?.id ?? "opp"
        }
    }

    /// Client-side winner when CF has not stamped winnerId yet (honors surrenderedBy).
    mutating func deriveClientWinnerId(preferringMyUid myUid: String) {
        if let surrenderedBy, !surrenderedBy.isEmpty {
            applyLocalSurrender(by: surrenderedBy)
            return
        }
        let myAlive = localTeam.contains { $0.health > 0 }
        let oppAlive = opponentTeam.contains { $0.health > 0 }
        let myReps = localTeam.map(\.reps).reduce(0, +)
        let oppReps = opponentTeam.map(\.reps).reduce(0, +)
        let myHP = localTeam.map(\.health).reduce(0, +)
        let oppHP = opponentTeam.map(\.health).reduce(0, +)

        if !oppAlive && myAlive { winnerId = myUid }
        else if !myAlive && oppAlive { winnerId = opponentTeam.first?.id ?? "opp" }
        else if myReps > oppReps { winnerId = myUid }
        else if oppReps > myReps { winnerId = opponentTeam.first?.id ?? "opp" }
        else if myHP > oppHP { winnerId = myUid }
        else if oppHP > myHP { winnerId = opponentTeam.first?.id ?? "opp" }
        else { winnerId = "draw" }
    }
}
