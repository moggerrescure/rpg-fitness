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

struct Character: Codable, Identifiable {
    var id: String // Matches FirebaseAuth UID
    var username: String
    var selectedClass: CharacterClass
    var level: Int = 1
    var xp: Int = 0
    var gold: Int = 100
    var energy: Int = 100
    var maxEnergy: Int = 100
    var basePower: Int = 100
    
    var stats: CharacterStats = CharacterStats()
    var equippedWeaponId: String? = nil
    var equippedArmorId: String? = nil
    var clanId: String? = nil
    
    // Level Progression Logic
    var xpForNextLevel: Int {
        level * 150 // Linear difficulty scale
    }
    
    var combatPower: Int {
        // Base power scaled by level and class base modifiers
        let levelMultiplier = 1.0 + (Double(level - 1) * 0.1)
        return Int(Double(basePower + selectedClass.baseCombatPower) * levelMultiplier)
    }
    
    mutating func addXP(_ amount: Int) -> Bool {
        xp += amount
        var leveledUp = false
        while xp >= xpForNextLevel {
            xp -= xpForNextLevel
            level += 1
            maxEnergy += 5
            energy = maxEnergy // Restore energy on level up
            basePower += 15
            leveledUp = true
        }
        return leveledUp
    }
}
