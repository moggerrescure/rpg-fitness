import Foundation

enum BossDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case epic = "Epic"
}

struct BossSkill: Codable, Identifiable {
    var id = UUID().uuidString
    var name: String
    var damageMultiplier: Double
    var cooldown: TimeInterval
    var isUnblockable: Bool
    var lastUsedAt: Date?
}

struct Boss: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var difficulty: BossDifficulty
    var maxHealth: Int
    var currentHealth: Int
    var attackPower: Int
    var avatarName: String
    var isGlobalWorldBoss: Bool = false
    
    // Time in seconds between boss attacks
    var attackInterval: TimeInterval
    var skills: [BossSkill] = []
    
    // Loot
    var xpReward: Int
    var goldReward: Int
    var lootDropChance: Double // 0.0 to 1.0
    var possibleLootRarity: [ItemRarity]
}

struct WorldBoss: Codable, Identifiable {
    var id: String
    var bossTemplateId: String
    var maxHealth: Int
    var currentHealth: Int
    var isActive: Bool
    var startedAt: Date
    var topAttackers: [String: Int] // Dictionary of userId: damage dealt
}

extension Boss {
    static let templates: [Boss] = [
        Boss(
            id: "boss_goblin",
            name: "Goblin Brute",
            description: "A mindless brute with heavy attacks.",
            difficulty: .easy,
            maxHealth: 500,
            currentHealth: 500,
            attackPower: 15,
            avatarName: "avatar_goblin", // placeholder
            attackInterval: 4.0,
            skills: [
                BossSkill(name: "Smash", damageMultiplier: 1.5, cooldown: 12.0, isUnblockable: false)
            ],
            xpReward: 300,
            goldReward: 50,
            lootDropChance: 0.3,
            possibleLootRarity: [.common, .rare]
        ),
        Boss(
            id: "boss_orc",
            name: "Orc Warlord",
            description: "A fearsome tactician with relentless strikes.",
            difficulty: .normal,
            maxHealth: 1500,
            currentHealth: 1500,
            attackPower: 25,
            avatarName: "avatar_orc", // placeholder
            attackInterval: 3.5,
            skills: [
                BossSkill(name: "Savage Cleave", damageMultiplier: 2.0, cooldown: 15.0, isUnblockable: false),
                BossSkill(name: "Bloodlust Strike", damageMultiplier: 1.2, cooldown: 8.0, isUnblockable: true)
            ],
            xpReward: 800,
            goldReward: 150,
            lootDropChance: 0.6,
            possibleLootRarity: [.rare, .epic]
        ),
        Boss(
            id: "boss_dragon",
            name: "Ancient Dragon",
            description: "A legend brought to life. Its fire consumes all.",
            difficulty: .epic,
            maxHealth: 5000,
            currentHealth: 5000,
            attackPower: 60,
            avatarName: "avatar_dragon",
            attackInterval: 3.0,
            skills: [
                BossSkill(name: "Hellfire Breath", damageMultiplier: 2.5, cooldown: 20.0, isUnblockable: true),
                BossSkill(name: "Tail Swipe", damageMultiplier: 1.5, cooldown: 10.0, isUnblockable: false)
            ],
            xpReward: 2500,
            goldReward: 1000,
            lootDropChance: 1.0,
            possibleLootRarity: [.epic, .legendary]
        )
    ]
}
