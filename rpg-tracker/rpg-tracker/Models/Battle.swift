import Foundation

enum BattleType: String, Codable {
    case duel1v1 = "1v1 Duel"
    case team3v3 = "3v3 Team Battle"
    case bossRaid = "Boss Raid"
    case clanWar = "Clan War Battle"
}

enum BattleStatus: String, Codable {
    case searching = "Searching..."
    case active = "Active Combat"
    case completed = "Finished"
}

struct BattlePlayer: Codable, Identifiable {
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

struct Battle: Codable, Identifiable {
    var id: String
    var type: BattleType
    var status: BattleStatus
    var localTeam: [BattlePlayer]
    var opponentTeam: [BattlePlayer]
    var winnerId: String? = nil
    var createdAt: Date = Date()
    var secondsRemaining: Int = 60
    var combatLog: [CombatEvent] = []
}
