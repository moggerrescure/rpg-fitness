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
}

struct ClanWar: Codable {
    var opponentClanId: String
    var opponentClanName: String
    var myClanScore: Int = 0
    var opponentClanScore: Int = 0
    var endsAt: Date
    var isActive: Bool {
        endsAt > Date()
    }
}

struct Clan: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var emblem: String
    var leaderId: String
    var members: [ClanMember] // Max 3 players
    var trophies: Int = 1000
    var totalReps: Int = 0
    var activeWar: ClanWar? = nil
    
    var isFull: Bool {
        members.count >= 3
    }
}
