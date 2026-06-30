import Foundation

enum ClanRole: String, Codable {
    case leader = "Leader"
    case officer = "Officer"
    case member = "Member"
}

struct ClanMember: Codable, Identifiable {
    var id: String
    var username: String
    var level: Int
    var characterClass: CharacterClass
    var role: ClanRole
    var repsContributed: Int = 0
    var warAttacksUsed: Int = 0
    var warScoreContributed: Int = 0
}

enum ClanWarPhase: String, Codable {
    case searching
    case preparation
    case active
    case finished
}

struct ClanWar: Codable {
    var phase: ClanWarPhase = .searching
    var phaseEndsAt: Date
    var opponentClanId: String?
    var opponentClanName: String?
    var myClanScore: Int = 0
    var opponentClanScore: Int = 0
    
    // For backward compatibility / easy checks
    var isActive: Bool {
        phase == .active
    }
}

struct Clan: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var emblem: String
    var leaderId: String
    var members: [ClanMember] 
    var trophies: Int = 1000
    var totalReps: Int = 0
    var level: Int = 1
    var xp: Int = 0
    var activeWar: ClanWar? = nil
    var treasuryGold: Int? = 0
    
    var maxMembers: Int {
        return 10 + (level - 1) * 5
    }
    
    var isFull: Bool {
        members.count >= maxMembers
    }
}
