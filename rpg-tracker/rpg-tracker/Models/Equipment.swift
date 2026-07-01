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
    case ring = "Ring"
    case amulet = "Amulet"
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
    
    func getIconName() -> String {
        if slot == .weapon {
            // Class-specific weapon icons
            switch classRestriction {
            case .archer:    return "arrow.up.right"
            case .mage:      return "wand.and.stars"
            case .healer:    return "cross.case.fill"
            case .swordsman: return "shield.fill"
            case .none:
                // Generic weapon icon by rarity
                switch rarity {
                case .mythical:   return "bolt.fill"
                case .legendary:  return "flame.fill"
                case .epic:       return "star.fill"
                default:          return "bolt.slash.fill"
                }
            }
        }
        if slot == .ring {
            return "circle.dotted"
        }
        if slot == .amulet {
            return "sparkles"
        }
        // Armor: by rarity or class
        guard let classRestriction = self.classRestriction else {
            return "shield.fill"
        }
        switch classRestriction {
        case .archer:    return "figure.run"
        case .mage:      return "bolt.shield.fill"
        case .swordsman: return "shield.fill"
        case .healer:    return "heart.square.fill"
        }
    }
    
    func getAssetImageName() -> String? {
        switch slot {
        case .weapon:
            switch classRestriction {
            case .archer:    return "weapon_archer_epic"
            case .mage:      return "weapon_mage_epic"
            case .healer:    return "weapon_healer_epic"
            case .swordsman: return "weapon_swordsman_epic"
            case .none:      return "weapon_swordsman_epic"
            }
        case .armor:
            return "shop_armor_epic"
        case .ring:
            return "shop_ring_epic"
        case .amulet:
            return "shop_amulet_epic"
        }
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
        return allShopWeapons.first(where: { $0.id == id })
    }
    
    static func findRing(by id: String) -> EquipmentItem? {
        return allShopRings.first(where: { $0.id == id })
    }
    
    static func findAmulet(by id: String) -> EquipmentItem? {
        return allShopAmulets.first(where: { $0.id == id })
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
    
    // Static database of shop weapons across all rarities
    static let allShopWeapons: [EquipmentItem] = [
        // --- COMMON ---
        EquipmentItem(id: "wpn_com_1", name: "Short Sword", slot: .weapon, rarity: .common, combatPowerBonus: 12, defense: 0, cost: 60, classRestriction: nil,
                      description: "A basic iron blade used by city guards and low-level adventurers."),
        EquipmentItem(id: "wpn_com_2", name: "Hunting Bow", slot: .weapon, rarity: .common, combatPowerBonus: 10, defense: 0, cost: 55, classRestriction: .archer,
                      description: "A lightweight bow ideal for hunting small game and scout missions."),
        EquipmentItem(id: "wpn_com_3", name: "Wooden Staff", slot: .weapon, rarity: .common, combatPowerBonus: 11, defense: 0, cost: 50, classRestriction: .mage,
                      description: "A simple staff carved from oak, channeling basic spell energy."),
        EquipmentItem(id: "wpn_com_4", name: "Healing Wand", slot: .weapon, rarity: .common, combatPowerBonus: 9, defense: 2, cost: 55, classRestriction: .healer,
                      description: "Infused with minor restorative runes to aid battlefield triage."),
        EquipmentItem(id: "wpn_com_5", name: "Dagger", slot: .weapon, rarity: .common, combatPowerBonus: 14, defense: 0, cost: 70, classRestriction: nil,
                      description: "Fast and precise, favored by rogues and backup fighters."),

        // --- RARE ---
        EquipmentItem(id: "wpn_rar_1", name: "Elven Longbow", slot: .weapon, rarity: .rare, combatPowerBonus: 28, defense: 0, cost: 260, classRestriction: .archer,
                      description: "Crafted from silvermoon wood, it fires arrows with uncanny precision."),
        EquipmentItem(id: "wpn_rar_2", name: "Frost Shard Staff", slot: .weapon, rarity: .rare, combatPowerBonus: 30, defense: 0, cost: 280, classRestriction: .mage,
                      description: "Topped with an ice crystal that slows enemy movement."),
        EquipmentItem(id: "wpn_rar_3", name: "Battle Axe", slot: .weapon, rarity: .rare, combatPowerBonus: 34, defense: 0, cost: 310, classRestriction: .swordsman,
                      description: "A heavy two-handed axe designed to cleave through armor."),
        EquipmentItem(id: "wpn_rar_4", name: "Blessed Mace", slot: .weapon, rarity: .rare, combatPowerBonus: 26, defense: 4, cost: 290, classRestriction: .healer,
                      description: "Enchanted by temple priests to boost both strike and recovery power."),
        EquipmentItem(id: "wpn_rar_5", name: "Silver Rapier", slot: .weapon, rarity: .rare, combatPowerBonus: 32, defense: 2, cost: 330, classRestriction: nil,
                      description: "A nimble thrusting sword forged from polished silver alloy."),

        // --- EPIC ---
        EquipmentItem(id: "wpn_epi_1", name: "Thunderstrike Bow", slot: .weapon, rarity: .epic, combatPowerBonus: 50, defense: 0, cost: 580, classRestriction: .archer,
                      description: "Arrows crackle with static electricity, paralysing on hit."),
        EquipmentItem(id: "wpn_epi_2", name: "Stormcaller Staff", slot: .weapon, rarity: .epic, combatPowerBonus: 54, defense: 0, cost: 620, classRestriction: .mage,
                      description: "Summons miniature lightning storms at will."),
        EquipmentItem(id: "wpn_epi_3", name: "Obsidian Claymore", slot: .weapon, rarity: .epic, combatPowerBonus: 60, defense: 0, cost: 690, classRestriction: .swordsman,
                      description: "Forged from volcanic glass, it shatters armor on contact."),
        EquipmentItem(id: "wpn_epi_4", name: "Celestial Sceptre", slot: .weapon, rarity: .epic, combatPowerBonus: 45, defense: 8, cost: 640, classRestriction: .healer,
                      description: "Channels divine light into powerful healing waves."),
        EquipmentItem(id: "wpn_epi_5", name: "Twin Fangs", slot: .weapon, rarity: .epic, combatPowerBonus: 56, defense: 0, cost: 710, classRestriction: nil,
                      description: "Dual curved blades that strike twice per attack cycle."),

        // --- LEGENDARY ---
        EquipmentItem(id: "wpn_leg_1", name: "Stardust Shortbow", slot: .weapon, rarity: .legendary, combatPowerBonus: 80, defense: 0, cost: 1300, classRestriction: .archer,
                      description: "Woven from celestial threads, arrows travel faster than light."),
        EquipmentItem(id: "wpn_leg_2", name: "Arcane Tome of Ruin", slot: .weapon, rarity: .legendary, combatPowerBonus: 85, defense: 0, cost: 1450, classRestriction: .mage,
                      description: "Ancient spellbook binding reality-rending incantations."),
        EquipmentItem(id: "wpn_leg_3", name: "Excalibur Replica", slot: .weapon, rarity: .legendary, combatPowerBonus: 90, defense: 5, cost: 1600, classRestriction: .swordsman,
                      description: "A near-perfect recreation of the legendary holy blade."),
        EquipmentItem(id: "wpn_leg_4", name: "Aether Lute", slot: .weapon, rarity: .legendary, combatPowerBonus: 70, defense: 15, cost: 1500, classRestriction: .healer,
                      description: "Musical healing resonates through allies boosting their recovery."),

        // --- MYTHICAL ---
        EquipmentItem(id: "wpn_myt_1", name: "Voidcleaver", slot: .weapon, rarity: .mythical, combatPowerBonus: 130, defense: 0, cost: 3000, classRestriction: .swordsman,
                      description: "Tears rifts in space with every swing, hitting enemies across dimensions."),
        EquipmentItem(id: "wpn_myt_2", name: "Nebula Strand Bow", slot: .weapon, rarity: .mythical, combatPowerBonus: 120, defense: 0, cost: 2800, classRestriction: .archer,
                      description: "Arrows materialise from starlight, striking before they are loosed."),
        EquipmentItem(id: "wpn_myt_3", name: "The Singularity Staff", slot: .weapon, rarity: .mythical, combatPowerBonus: 140, defense: 0, cost: 3500, classRestriction: .mage,
                      description: "Contains a compressed black hole at its tip, collapsing enemy defences."),
        EquipmentItem(id: "wpn_myt_4", name: "Genesis Rod", slot: .weapon, rarity: .mythical, combatPowerBonus: 110, defense: 25, cost: 3200, classRestriction: .healer,
                      description: "Channels the force of creation itself, restoring life on a cosmic scale."),
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
    
    static let allShopRings: [EquipmentItem] = [
        EquipmentItem(id: "rng_com_1", name: "Copper Band", slot: .ring, rarity: .common, combatPowerBonus: 5, defense: 1, cost: 80, classRestriction: nil,
                      description: "A simple copper ring that channels minor combat energy."),
        EquipmentItem(id: "rng_com_2", name: "Iron Loop", slot: .ring, rarity: .common, combatPowerBonus: 8, defense: 2, cost: 120, classRestriction: nil,
                      description: "A plain iron ring worn by city guards for basic protection."),
        EquipmentItem(id: "rng_rar_1", name: "Silver Signet", slot: .ring, rarity: .rare, combatPowerBonus: 15, defense: 4, cost: 280, classRestriction: nil,
                      description: "A silver ring bearing an unknown crest, resonating with arcane energy."),
        EquipmentItem(id: "rng_rar_2", name: "Moonstone Ring", slot: .ring, rarity: .rare, combatPowerBonus: 18, defense: 5, cost: 320, classRestriction: nil,
                      description: "Carved from moonstone, it amplifies reflexes under the night sky."),
        EquipmentItem(id: "rng_epi_1", name: "Obsidian Loop", slot: .ring, rarity: .epic, combatPowerBonus: 28, defense: 8, cost: 650, classRestriction: nil,
                      description: "Carved from dark volcanic glass, it channels raw elemental power."),
        EquipmentItem(id: "rng_epi_2", name: "Stormseal Ring", slot: .ring, rarity: .epic, combatPowerBonus: 32, defense: 10, cost: 750, classRestriction: nil,
                      description: "A ring crackling with trapped lightning, boosting strike speed."),
        EquipmentItem(id: "rng_leg_1", name: "Dragon's Eye Ring", slot: .ring, rarity: .legendary, combatPowerBonus: 50, defense: 14, cost: 1400, classRestriction: nil,
                      description: "A ring with a fiery red gemstone that burns with dragonflame energy."),
        EquipmentItem(id: "rng_leg_2", name: "Ring of the Ancients", slot: .ring, rarity: .legendary, combatPowerBonus: 55, defense: 16, cost: 1600, classRestriction: nil,
                      description: "An ancient ring rumored to grant the strength of fallen warriors."),
        EquipmentItem(id: "rng_myt_1", name: "Band of the Void", slot: .ring, rarity: .mythical, combatPowerBonus: 80, defense: 22, cost: 3200, classRestriction: nil,
                      description: "It feels completely weightless. Reality bends around the wearer's fists."),
    ]
    
    static let allShopAmulets: [EquipmentItem] = [
        EquipmentItem(id: "amu_com_1", name: "String Necklace", slot: .amulet, rarity: .common, combatPowerBonus: 4, defense: 2, cost: 70, classRestriction: nil,
                      description: "A simple string with a carved wooden bead. Surprisingly durable."),
        EquipmentItem(id: "amu_com_2", name: "Bone Charm", slot: .amulet, rarity: .common, combatPowerBonus: 6, defense: 3, cost: 100, classRestriction: nil,
                      description: "A carved bone charm worn by tribal warriors for courage in battle."),
        EquipmentItem(id: "amu_rar_1", name: "Sapphire Pendant", slot: .amulet, rarity: .rare, combatPowerBonus: 12, defense: 6, cost: 260, classRestriction: nil,
                      description: "A glowing blue sapphire pendant that sharpens mental focus."),
        EquipmentItem(id: "amu_rar_2", name: "Ember Amulet", slot: .amulet, rarity: .rare, combatPowerBonus: 14, defense: 7, cost: 300, classRestriction: nil,
                      description: "A fire opal amulet that keeps the wearer warm and energized."),
        EquipmentItem(id: "amu_epi_1", name: "Ruby Heart", slot: .amulet, rarity: .epic, combatPowerBonus: 22, defense: 12, cost: 620, classRestriction: nil,
                      description: "A red ruby that pulses faintly with each heartbeat, boosting vitality."),
        EquipmentItem(id: "amu_epi_2", name: "Stormcaller Pendant", slot: .amulet, rarity: .epic, combatPowerBonus: 26, defense: 14, cost: 720, classRestriction: nil,
                      description: "A charged crystal that crackles with electrical energy in combat."),
        EquipmentItem(id: "amu_leg_1", name: "Talisman of the Ancients", slot: .amulet, rarity: .legendary, combatPowerBonus: 38, defense: 20, cost: 1350, classRestriction: nil,
                      description: "An ancient golden talisman with a forgotten language etched inside."),
        EquipmentItem(id: "amu_leg_2", name: "Phoenix Feather Locket", slot: .amulet, rarity: .legendary, combatPowerBonus: 42, defense: 22, cost: 1550, classRestriction: nil,
                      description: "Contains a single phoenix feather that grants resilience in defeat."),
        EquipmentItem(id: "amu_myt_1", name: "Amulet of Antigravity", slot: .amulet, rarity: .mythical, combatPowerBonus: 65, defense: 30, cost: 3000, classRestriction: nil,
                      description: "A mysterious artifact that defies gravity. Every punch feels weightless."),
    ]
}

// MARK: - Reusable Item Icon View

struct ItemIconView: View {
    let item: EquipmentItem?
    let fallbackIcon: String
    
    var body: some View {
        if let item = item {
            if let assetName = item.getAssetImageName() {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Image(systemName: item.getIconName())
                    .resizable()
                    .scaledToFit()
            }
        } else {
            Image(systemName: fallbackIcon)
                .resizable()
                .scaledToFit()
        }
    }
}

