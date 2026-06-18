import Foundation
import SwiftUI

enum ItemRarity: String, Codable, CaseIterable {
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
    case mythical = "Mythical"
    
    var color: Color {
        switch self {
        case .common: return Color.gray
        case .rare: return Theme.primary
        case .epic: return Theme.mageColor
        case .legendary: return Theme.healerColor
        case .mythical: return Color(hex: "EF4444") // Vibrant Crimson
        }
    }
}

enum EquipmentSlot: String, Codable {
    case weapon = "Weapon"
    case armor = "Armor"
}

struct EquipmentItem: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var slot: EquipmentSlot
    var rarity: ItemRarity
    var combatPowerBonus: Int
    var defense: Int
    var cost: Int
    var classRestriction: CharacterClass?
    var description: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: EquipmentItem, rhs: EquipmentItem) -> Bool {
        lhs.id == rhs.id
    }
    
    static func findArmor(by id: String) -> EquipmentItem? {
        if let starter = starterArmors.values.first(where: { $0.id == id }) {
            return starter
        }
        return allShopArmors.first(where: { $0.id == id })
    }
    
    static func findWeapon(by id: String) -> EquipmentItem? {
        if let starter = starterWeapons.values.first(where: { $0.id == id }) {
            return starter
        }
        return nil
    }
    
    static let starterWeapons: [CharacterClass: EquipmentItem] = [
        .archer: EquipmentItem(
            id: "w_arch_1",
            name: "Oak Recurve Bow",
            slot: .weapon,
            rarity: .common,
            combatPowerBonus: 15,
            defense: 0,
            cost: 0,
            classRestriction: .archer,
            description: "A solid, standard-issue wooden bow crafted from high-density mountain oak."
        ),
        .mage: EquipmentItem(
            id: "w_mage_1",
            name: "Apprentice Focus Staff",
            slot: .weapon,
            rarity: .common,
            combatPowerBonus: 18,
            defense: 0,
            cost: 0,
            classRestriction: .mage,
            description: "A pine staff inlaid with a small mana crystal to harness push-up kinetic energy."
        ),
        .swordsman: EquipmentItem(
            id: "w_swor_1",
            name: "Iron Broadsword",
            slot: .weapon,
            rarity: .common,
            combatPowerBonus: 22,
            defense: 0,
            cost: 0,
            classRestriction: .swordsman,
            description: "Heavy iron blade forged for slamming down on targets."
        ),
        .healer: EquipmentItem(
            id: "w_heal_1",
            name: "Runic Hand Bells",
            slot: .weapon,
            rarity: .common,
            combatPowerBonus: 12,
            defense: 0,
            cost: 0,
            classRestriction: .healer,
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
            defense: 3,
            cost: 0,
            classRestriction: .archer,
            description: "Lightweight leather protection that does not restrict movement."
        ),
        .mage: EquipmentItem(
            id: "a_mage_1",
            name: "Acolyte Robes",
            slot: .armor,
            rarity: .common,
            combatPowerBonus: 8,
            defense: 2,
            cost: 0,
            classRestriction: .mage,
            description: "Reinforced linen robes woven with magic warding runes."
        ),
        .swordsman: EquipmentItem(
            id: "a_swor_1",
            name: "Studded Chainmail",
            slot: .armor,
            rarity: .common,
            combatPowerBonus: 15,
            defense: 5,
            cost: 0,
            classRestriction: .swordsman,
            description: "Interlocking steel rings built to deflect heavy physical impacts."
        ),
        .healer: EquipmentItem(
            id: "a_heal_1",
            name: "Blessed Vestments",
            slot: .armor,
            rarity: .common,
            combatPowerBonus: 12,
            defense: 3,
            cost: 0,
            classRestriction: .healer,
            description: "White and gold vestments that inspire resilience in team combat."
        )
    ]
    
    // Static database of 35 generated armors categorized by rank/rarity
    static let allShopArmors: [EquipmentItem] = [
        // --- COMMON (8 Items) ---
        EquipmentItem(id: "arm_com_1", name: "Worn Leather Vest", slot: .armor, rarity: .common, combatPowerBonus: 5, defense: 2, cost: 40, classRestriction: nil,
                      description: "Scratched and dusty, but offers basic chest protection."),
        EquipmentItem(id: "arm_com_2", name: "Novice Robe", slot: .armor, rarity: .common, combatPowerBonus: 4, defense: 2, cost: 50, classRestriction: .mage,
                      description: "Simple wool weave to keep a young apprentice warm during magical study."),
        EquipmentItem(id: "arm_com_3", name: "Rusty Plate Mail", slot: .armor, rarity: .common, combatPowerBonus: 6, defense: 3, cost: 65, classRestriction: .swordsman,
                      description: "Squeaks with every step, but beats wearing a cotton shirt in battle."),
        EquipmentItem(id: "arm_com_4", name: "Trapper's Cloak", slot: .armor, rarity: .common, combatPowerBonus: 5, defense: 2, cost: 50, classRestriction: .archer,
                      description: "Camouflaged canvas that resists light scratches and jungle thorns."),
        EquipmentItem(id: "arm_com_5", name: "Coarse Vestments", slot: .armor, rarity: .common, combatPowerBonus: 4, defense: 2, cost: 55, classRestriction: .healer,
                      description: "Simple rough cloth vestments blessed by a local village priest."),
        EquipmentItem(id: "arm_com_6", name: "Recruit's Cuirass", slot: .armor, rarity: .common, combatPowerBonus: 6, defense: 3, cost: 80, classRestriction: nil,
                      description: "Mass-produced iron breastplate issued to newly enlisted guards."),
        EquipmentItem(id: "arm_com_7", name: "Boiled Leather Chest", slot: .armor, rarity: .common, combatPowerBonus: 7, defense: 3, cost: 95, classRestriction: nil,
                      description: "Stiffened hide offering improved protection against piercing cuts."),
        EquipmentItem(id: "arm_com_8", name: "Tattered Brigandine", slot: .armor, rarity: .common, combatPowerBonus: 8, defense: 4, cost: 120, classRestriction: nil,
                      description: "Fabric jacket reinforced with small steel plates, albeit slightly rusty."),
        
        // --- RARE (8 Items) ---
        EquipmentItem(id: "arm_rar_1", name: "Ranger's Swift-Coat", slot: .armor, rarity: .rare, combatPowerBonus: 12, defense: 6, cost: 220, classRestriction: .archer,
                      description: "Flexible green tunic lined with light bird feathers for rapid movement."),
        EquipmentItem(id: "arm_rar_2", name: "Sage's Rune-Cloak", slot: .armor, rarity: .rare, combatPowerBonus: 14, defense: 5, cost: 240, classRestriction: .mage,
                      description: "Woven wizard cloth that dampens minor kinetic spell vibrations."),
        EquipmentItem(id: "arm_rar_3", name: "Vanguard Half-Plate", slot: .armor, rarity: .rare, combatPowerBonus: 16, defense: 8, cost: 280, classRestriction: .swordsman,
                      description: "Polished steel plate protecting vital organs, favored by squad leaders."),
        EquipmentItem(id: "arm_rar_4", name: "Acolyte's Guard", slot: .armor, rarity: .rare, combatPowerBonus: 11, defense: 6, cost: 250, classRestriction: .healer,
                      description: "Infused with minor solar prayers to accelerate natural cellular recovery."),
        EquipmentItem(id: "arm_rar_5", name: "Heavy Scale Mail", slot: .armor, rarity: .rare, combatPowerBonus: 15, defense: 7, cost: 300, classRestriction: nil,
                      description: "Overlapping brass scales that deflect slicing swings and claw marks."),
        EquipmentItem(id: "arm_rar_6", name: "Gladiator's Leather", slot: .armor, rarity: .rare, combatPowerBonus: 13, defense: 6, cost: 310, classRestriction: nil,
                      description: "Worn in regional arenas, prioritizing flexibility and fast dodge maneuvers."),
        EquipmentItem(id: "arm_rar_7", name: "Hardened Iron Plate", slot: .armor, rarity: .rare, combatPowerBonus: 18, defense: 9, cost: 380, classRestriction: nil,
                      description: "Heavy solid iron breastplate constructed to absorb heavy physical impacts."),
        EquipmentItem(id: "arm_rar_8", name: "Shamanic Hide Jerkin", slot: .armor, rarity: .rare, combatPowerBonus: 15, defense: 7, cost: 350, classRestriction: nil,
                      description: "Embellished with animal bone charms to bolster the wearer's resilience."),
        
        // --- EPIC (8 Items) ---
        EquipmentItem(id: "arm_epi_1", name: "Windrunner Vest", slot: .armor, rarity: .epic, combatPowerBonus: 22, defense: 12, cost: 550, classRestriction: .archer,
                      description: "Lightweight vest woven from elastic silk harvested from deep forest spiders."),
        EquipmentItem(id: "arm_epi_2", name: "Archmage Shroud", slot: .armor, rarity: .epic, combatPowerBonus: 25, defense: 10, cost: 600, classRestriction: .mage,
                      description: "Cloak pulsating with purple ley-line energy that absorbs incoming impact."),
        EquipmentItem(id: "arm_epi_3", name: "Dragonscale Chestplate", slot: .armor, rarity: .epic, combatPowerBonus: 28, defense: 15, cost: 680, classRestriction: .swordsman,
                      description: "Crafted from red dragon whelp scales, naturally resistant to hot fires."),
        EquipmentItem(id: "arm_epi_4", name: "Templar Breastplate", slot: .armor, rarity: .epic, combatPowerBonus: 20, defense: 13, cost: 620, classRestriction: .healer,
                      description: "A blessed metal vestment optimized to shield frontline support healers."),
        EquipmentItem(id: "arm_epi_5", name: "Obsidian Chest", slot: .armor, rarity: .epic, combatPowerBonus: 26, defense: 14, cost: 700, classRestriction: nil,
                      description: "Carved from dark volcanic obsidian glass, absorbing physical shockwaves."),
        EquipmentItem(id: "arm_epi_6", name: "Ghost-Weave Robes", slot: .armor, rarity: .epic, combatPowerBonus: 23, defense: 11, cost: 720, classRestriction: nil,
                      description: "Partially phased out of the physical realm, letting blades graze past."),
        EquipmentItem(id: "arm_epi_7", name: "Gilded Plate Armor", slot: .armor, rarity: .epic, combatPowerBonus: 30, defense: 16, cost: 850, classRestriction: nil,
                      description: "Beautiful gold-trimmed plating over reinforced high-grade steel."),
        EquipmentItem(id: "arm_epi_8", name: "Assassin's Shroud", slot: .armor, rarity: .epic, combatPowerBonus: 24, defense: 12, cost: 780, classRestriction: nil,
                      description: "Treated with pitch-black shadow dyes that blend seamlessly into dark arenas."),
        
        // --- LEGENDARY (6 Items) ---
        EquipmentItem(id: "arm_leg_1", name: "Eagle-Eye Carapace", slot: .armor, rarity: .legendary, combatPowerBonus: 38, defense: 22, cost: 1200, classRestriction: .archer,
                      description: "Light breastplate imbued with the aerial grace and speed of a mountain eagle."),
        EquipmentItem(id: "arm_leg_2", name: "Chronos Mage Robe", slot: .armor, rarity: .legendary, combatPowerBonus: 40, defense: 20, cost: 1350, classRestriction: .mage,
                      description: "Manipulates time fabrics to slow down the speed of incoming projectiles."),
        EquipmentItem(id: "arm_leg_3", name: "Dreadnought Plate", slot: .armor, rarity: .legendary, combatPowerBonus: 45, defense: 26, cost: 1500, classRestriction: .swordsman,
                      description: "An absolute fortress of interlocking steel plates. Weighty but unbreakable."),
        EquipmentItem(id: "arm_leg_4", name: "Seraphim Regalia", slot: .armor, rarity: .legendary, combatPowerBonus: 35, defense: 21, cost: 1400, classRestriction: .healer,
                      description: "Woven from golden threads of pure light to repel shadow corruption."),
        EquipmentItem(id: "arm_leg_5", name: "Mythril Chain-Coat", slot: .armor, rarity: .legendary, combatPowerBonus: 42, defense: 24, cost: 1750, classRestriction: nil,
                      description: "Woven mythril rings: light as a feather, yet stronger than tempered steel."),
        EquipmentItem(id: "arm_leg_6", name: "Colossus Iron Aegis", slot: .armor, rarity: .legendary, combatPowerBonus: 48, defense: 28, cost: 1900, classRestriction: nil,
                      description: "Forged inside a dwarf forge using star cores, deflecting massive impacts."),
        
        // --- MYTHICAL (5 Items) ---
        EquipmentItem(id: "arm_myt_1", name: "Voidwalker Robes", slot: .armor, rarity: .mythical, combatPowerBonus: 60, defense: 36, cost: 2600, classRestriction: .mage,
                      description: "Ripping cosmic void tears, this armor absorbs 35% of all physical shock."),
        EquipmentItem(id: "arm_myt_2", name: "Eldritch Drake Scale", slot: .armor, rarity: .mythical, combatPowerBonus: 65, defense: 42, cost: 3000, classRestriction: .swordsman,
                      description: "Drake scales forged in volcanic magma, radiating orange lava cracks."),
        EquipmentItem(id: "arm_myt_3", name: "Astral Star-Cloak", slot: .armor, rarity: .mythical, combatPowerBonus: 58, defense: 38, cost: 2800, classRestriction: .archer,
                      description: "Glows with celestial nebula dust, bending gravity around incoming arrows."),
        EquipmentItem(id: "arm_myt_4", name: "Divine Aegis Regalia", slot: .armor, rarity: .mythical, combatPowerBonus: 55, defense: 40, cost: 3200, classRestriction: .healer,
                      description: "A sacred vestment radiating a golden aura that renders the wearer nearly immune."),
        EquipmentItem(id: "arm_myt_5", name: "Antigravity Nano-Suit", slot: .armor, rarity: .mythical, combatPowerBonus: 70, defense: 45, cost: 4500, classRestriction: nil,
                      description: "Futuristic nano-armor that neutralizes mass and gravity, dampening all force.")
    ]
}
