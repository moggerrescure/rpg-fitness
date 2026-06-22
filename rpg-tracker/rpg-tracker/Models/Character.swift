import Foundation
import SwiftUI

enum CharacterClass: String, Codable, CaseIterable, Identifiable {
    case archer = "Archer"
    case mage = "Mage"
    case swordsman = "Swordsman"
    case healer = "Healer"
    
    var id: String { self.rawValue }
    
    var primaryExercise: String {
        switch self {
        case .archer: return "Squats"
        case .mage: return "Push-ups"
        case .swordsman: return "Pull-ups"
        case .healer: return "Dips"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .archer: return Theme.archerColor
        case .mage: return Theme.mageColor
        case .swordsman: return Theme.swordsmanColor
        case .healer: return Theme.healerColor
        }
    }
    
    var description: String {
        switch self {
        case .archer:
            return "Uses squats to power arrows. Excels in ranged physical damage, buffs agility and increases team defense."
        case .mage:
            return "Harnesses the energy of push-ups for area destruction. Deals high magic damage and debuffs enemy resistances."
        case .swordsman:
            return "Performs pull-ups to slam blades. Extreme single-target melee damage, massive health pool, acts as team tank."
        case .healer:
            return "Performs chest/tricep dips to restore vitality. Heals wounds, grants shields, and revives fallen allies."
        }
    }
    
    var baseCombatPower: Int {
        switch self {
        case .archer: return 120
        case .mage: return 140
        case .swordsman: return 150
        case .healer: return 100
        }
    }
}

struct CharacterStats: Codable {
    var totalSquats: Int = 0
    var totalPushups: Int = 0
    var totalPullups: Int = 0
    var totalDips: Int = 0
    
    var totalReps: Int {
        totalSquats + totalPushups + totalPullups + totalDips
    }
}

struct ClassProgression: Codable {
    var level: Int = 1
    var xp: Int = 0
    var totalReps: Int = 0
    var storyStage: Int = 1
}

struct Character: Codable, Identifiable {
    var id: String // Matches FirebaseAuth UID
    var username: String
    var selectedClass: CharacterClass
    var energy: Int = 100
    var maxEnergy: Int = 100
    var basePower: Int = 100
    var gold: Int = 0
    var avatarName: String? = "avatar_knight"
    
    var statPoints: Int = 0
    var baseStrength: Int = 10
    var baseDexterity: Int = 10
    var baseIntelligence: Int = 10
    var baseVitality: Int = 10
    
    var stats: CharacterStats = CharacterStats()
    var equippedWeaponId: String? = nil
    var equippedArmorId: String? = nil
    var equippedRingId: String? = nil
    var equippedAmuletId: String? = nil
    var ownedEquipmentIds: [String] = ["w_arch_1", "a_arch_1", "w_mage_1", "a_mage_1", "w_swor_1", "a_swor_1", "w_heal_1", "a_heal_1"]
    var clanId: String? = nil
    var pvpWins: Int = 0
    var pvpTrophies: Int = 1000
    
    var friends: [String] = []
    var friendRequests: [String] = []
    
    var fcmToken: String? = nil
    var lastActive: Date? = nil
    var lastHealthSyncDate: Date? = nil
    
    var isOnline: Bool {
        guard let lastActive = lastActive else { return false }
        // Online if active in the last 15 minutes
        return Date().timeIntervalSince(lastActive) < 900
    }
    
    // Track stats and progression for each class independently
    var progressions: [String: ClassProgression] = [
        CharacterClass.archer.rawValue: ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1),
        CharacterClass.mage.rawValue: ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1),
        CharacterClass.swordsman.rawValue: ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1),
        CharacterClass.healer.rawValue: ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1)
    ]
    
    // Custom initializer to match mock initialization calls in services & viewmodels
    init(
        id: String,
        username: String,
        selectedClass: CharacterClass,
        level: Int = 1,
        xp: Int = 0,
        gold: Int = 0,
        energy: Int = 100,
        maxEnergy: Int = 100,
        basePower: Int = 100,
        statPoints: Int = 0,
        baseStrength: Int = 10,
        baseDexterity: Int = 10,
        baseIntelligence: Int = 10,
        baseVitality: Int = 10,
        stats: CharacterStats = CharacterStats(),
        equippedWeaponId: String? = nil,
        equippedArmorId: String? = nil,
        equippedRingId: String? = nil,
        equippedAmuletId: String? = nil,
        ownedEquipmentIds: [String]? = nil,
        clanId: String? = nil,
        pvpWins: Int = 0,
        pvpTrophies: Int = 1000,
        friends: [String] = [],
        friendRequests: [String] = [],
        fcmToken: String? = nil,
        lastActive: Date? = nil,
        lastHealthSyncDate: Date? = nil,
        progressions: [String: ClassProgression]? = nil,
        avatarName: String? = "avatar_knight"
    ) {
        self.id = id
        self.username = username
        self.selectedClass = selectedClass
        self.energy = energy
        self.maxEnergy = maxEnergy
        self.basePower = basePower
        self.statPoints = statPoints
        self.lastActive = lastActive
        self.baseStrength = baseStrength
        self.baseDexterity = baseDexterity
        self.baseIntelligence = baseIntelligence
        self.baseVitality = baseVitality
        self.gold = gold
        self.avatarName = avatarName ?? "avatar_knight"
        self.stats = stats
        self.equippedWeaponId = equippedWeaponId
        self.equippedArmorId = equippedArmorId
        self.equippedRingId = equippedRingId
        self.equippedAmuletId = equippedAmuletId
        self.ownedEquipmentIds = ownedEquipmentIds ?? ["w_arch_1", "a_arch_1", "w_mage_1", "a_mage_1", "w_swor_1", "a_swor_1", "w_heal_1", "a_heal_1"]
        self.clanId = clanId
        self.pvpWins = pvpWins
        self.pvpTrophies = pvpTrophies
        self.friends = friends
        self.friendRequests = friendRequests
        self.fcmToken = fcmToken
        self.lastHealthSyncDate = lastHealthSyncDate
        
        var baseProgressions = progressions ?? [
            CharacterClass.archer.rawValue: ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1),
            CharacterClass.mage.rawValue: ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1),
            CharacterClass.swordsman.rawValue: ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1),
            CharacterClass.healer.rawValue: ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1)
        ]
        
        if progressions == nil {
            baseProgressions[selectedClass.rawValue] = ClassProgression(level: level, xp: xp, totalReps: stats.totalReps, storyStage: 1)
        }
        self.progressions = baseProgressions
    }
    
    mutating func buyArmor(_ armor: EquipmentItem) {
        guard gold >= armor.cost else { return }
        gold -= armor.cost
        if !ownedEquipmentIds.contains(armor.id) {
            ownedEquipmentIds.append(armor.id)
        }
    }

    /// Universal buy: deducts gold and adds to owned list regardless of slot.
    mutating func buyItem(_ item: EquipmentItem) {
        guard gold >= item.cost else { return }
        gold -= item.cost
        if !ownedEquipmentIds.contains(item.id) {
            ownedEquipmentIds.append(item.id)
        }
    }
    
    mutating func equipArmor(itemId: String) {
        if ownedEquipmentIds.contains(itemId) {
            equippedArmorId = itemId
        }
    }
    
    mutating func equipWeapon(itemId: String) {
        if ownedEquipmentIds.contains(itemId) {
            equippedWeaponId = itemId
        }
    }
    
    mutating func equipRing(itemId: String) {
        if ownedEquipmentIds.contains(itemId) {
            equippedRingId = itemId
        }
    }
    
    mutating func equipAmulet(itemId: String) {
        if ownedEquipmentIds.contains(itemId) {
            equippedAmuletId = itemId
        }
    }
    
    // Helper to get actual Equipment objects
    var equippedWeapon: EquipmentItem? {
        guard let id = equippedWeaponId else { return nil }
        return EquipmentItem.findWeapon(by: id) ?? EquipmentItem.allShopArmors.first(where: { $0.id == id && $0.slot == .weapon })
    }
    
    var equippedArmor: EquipmentItem? {
        guard let id = equippedArmorId else { return nil }
        return EquipmentItem.findArmor(by: id)
    }
    
    var equippedRing: EquipmentItem? {
        guard let id = equippedRingId else { return nil }
        return EquipmentItem.findRing(by: id)
    }
    
    var equippedAmulet: EquipmentItem? {
        guard let id = equippedAmuletId else { return nil }
        return EquipmentItem.findAmulet(by: id)
    }
    
    var totalDefense: Int {
        let gearDef = (equippedArmor?.defense ?? 0) + (equippedWeapon?.defense ?? 0) + (equippedRing?.defense ?? 0) + (equippedAmulet?.defense ?? 0)
        return gearDef + (baseVitality * 2)
    }
    
    // Computed Properties mapped to the currently active class
    var level: Int {
        progressions[selectedClass.rawValue]?.level ?? 1
    }
    
    var xp: Int {
        progressions[selectedClass.rawValue]?.xp ?? 0
    }
    
    var xpForNextLevel: Int {
        level * 150 // Linear difficulty scale
    }
    
    var storyStage: Int {
        progressions[selectedClass.rawValue]?.storyStage ?? 1
    }
    
    var combatPower: Int {
        let levelMultiplier = 1.0 + (Double(level - 1) * 0.1)
        let gearBonus = (equippedWeapon?.combatPowerBonus ?? 0) + (equippedArmor?.combatPowerBonus ?? 0) + (equippedRing?.combatPowerBonus ?? 0) + (equippedAmulet?.combatPowerBonus ?? 0)
        
        let statBonus: Int
        switch selectedClass {
        case .swordsman: statBonus = baseStrength * 2
        case .archer: statBonus = baseDexterity * 2
        case .mage: statBonus = baseIntelligence * 2
        case .healer: statBonus = baseIntelligence + baseVitality
        }
        
        return Int(Double(basePower + selectedClass.baseCombatPower + statBonus + gearBonus) * levelMultiplier)
    }
    
    mutating func allocateStatPoint(stat: String) {
        guard statPoints > 0 else { return }
        switch stat {
        case "STR": baseStrength += 1
        case "DEX": baseDexterity += 1
        case "INT": baseIntelligence += 1
        case "VIT": baseVitality += 1
        default: return
        }
        statPoints -= 1
    }
    
    mutating func addXP(_ amount: Int) -> Bool {
        var prog = progressions[selectedClass.rawValue] ?? ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1)
        prog.xp += amount
        var leveledUp = false
        while prog.xp >= (prog.level * 150) {
            prog.xp -= (prog.level * 150)
            prog.level += 1
            maxEnergy += 5
            energy = maxEnergy // Restore energy on level up
            basePower += 15
            statPoints += 3
            leveledUp = true
        }
        progressions[selectedClass.rawValue] = prog
        return leveledUp
    }
    
    mutating func recordReps(for cls: CharacterClass, count: Int) {
        var prog = progressions[cls.rawValue] ?? ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1)
        prog.totalReps += count
        progressions[cls.rawValue] = prog
        
        // Sync to retro-compatible stats struct
        switch cls {
        case .archer: stats.totalSquats += count
        case .mage: stats.totalPushups += count
        case .swordsman: stats.totalPullups += count
        case .healer: stats.totalDips += count
        }
    }
    
    mutating func advanceStoryStage(completedStage: Int) {
        var prog = progressions[selectedClass.rawValue] ?? ClassProgression(level: 1, xp: 0, totalReps: 0, storyStage: 1)
        if completedStage >= prog.storyStage {
            prog.storyStage = completedStage + 1
            progressions[selectedClass.rawValue] = prog
        }
    }
}
