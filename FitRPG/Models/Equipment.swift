import Foundation
import SwiftUI

enum ItemRarity: String, Codable, CaseIterable {
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
    
    var color: Color {
        switch self {
        case .common: return Color.gray
        case .rare: return Theme.primary
        case .epic: return Theme.mageColor
        case .legendary: return Theme.healerColor
        }
    }
}

enum EquipmentSlot: String, Codable {
    case weapon = "Weapon"
    case armor = "Armor"
}

struct EquipmentItem: Codable, Identifiable {
    var id: String
    var name: String
    var slot: EquipmentSlot
    var rarity: ItemRarity
    var combatPowerBonus: Int
    var description: String
    
    static let starterWeapons: [CharacterClass: EquipmentItem] = [
        .archer: EquipmentItem(
            id: "w_arch_1",
            name: "Oak Recurve Bow",
            slot: .weapon,
            rarity: .common,
            combatPowerBonus: 15,
            description: "A solid, standard-issue wooden bow crafted from high-density mountain oak."
        ),
        .mage: EquipmentItem(
            id: "w_mage_1",
            name: "Apprentice Focus Staff",
            slot: .weapon,
            rarity: .common,
            combatPowerBonus: 18,
            description: "A pine staff inlaid with a small mana crystal to harness push-up kinetic energy."
        ),
        .swordsman: EquipmentItem(
            id: "w_swor_1",
            name: "Iron Broadsword",
            slot: .weapon,
            rarity: .common,
            combatPowerBonus: 22,
            description: "Heavy iron blade forged for slamming down on targets."
        ),
        .healer: EquipmentItem(
            id: "w_heal_1",
            name: "Runic Hand Bells",
            slot: .weapon,
            rarity: .common,
            combatPowerBonus: 12,
            description: "Bells tuned to resonate healing frequencies during intense bar workouts."
        )
    ]
    
    static let starterArmors: [CharacterClass: EquipmentItem] = [
        .archer: EquipmentItem(
            id: "a_arch_1",
            name: "Leather Jerkin",
            slot: .armor,
            rarity: .common,
            combatPowerBonus: 10,
            description: "Lightweight leather protection that does not restrict movement."
        ),
        .mage: EquipmentItem(
            id: "a_mage_1",
            name: "Acolyte Robes",
            slot: .armor,
            rarity: .common,
            combatPowerBonus: 8,
            description: "Reinforced linen robes woven with magic warding runes."
        ),
        .swordsman: EquipmentItem(
            id: "a_swor_1",
            name: "Studded Chainmail",
            slot: .armor,
            rarity: .common,
            combatPowerBonus: 15,
            description: "Interlocking steel rings built to deflect heavy physical impacts."
        ),
        .healer: EquipmentItem(
            id: "a_heal_1",
            name: "Blessed Vestments",
            slot: .armor,
            rarity: .common,
            combatPowerBonus: 12,
            description: "White and gold vestments that inspire resilience in team combat."
        )
    ]
}
