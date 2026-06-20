import SwiftUI

struct InventoryView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: EquipmentSlot = .weapon
    @State private var selectedItem: EquipmentItem? = nil
    
    private var character: Character {
        firebaseService.currentCharacter ?? Character(id: "local", username: "Hero", selectedClass: .archer)
    }
    
    private var ownedWeapons: [EquipmentItem] {
        let items = character.ownedEquipmentIds.compactMap { id -> EquipmentItem? in
            EquipmentItem.findWeapon(by: id) ?? EquipmentItem.allShopArmors.first(where: { $0.id == id && $0.slot == .weapon })
        }
        return items.sorted { $0.rarity.rawValue > $1.rarity.rawValue }
    }
    
    private var ownedArmors: [EquipmentItem] {
        let items = character.ownedEquipmentIds.compactMap { EquipmentItem.findArmor(by: $0) }
        return items.sorted { $0.rarity.rawValue > $1.rarity.rawValue }
    }
    
    private var ownedRings: [EquipmentItem] {
        let items = character.ownedEquipmentIds.compactMap { EquipmentItem.findRing(by: $0) }
        return items.sorted { $0.rarity.rawValue > $1.rarity.rawValue }
    }
    
    private var ownedAmulets: [EquipmentItem] {
        let items = character.ownedEquipmentIds.compactMap { EquipmentItem.findAmulet(by: $0) }
        return items.sorted { $0.rarity.rawValue > $1.rarity.rawValue }
    }
    
    var body: some View {
        ZStack {
            AnimatedBackgroundView(backgroundType: .shop)
            Color.black.opacity(0.5).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MY INVENTORY")
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(Theme.textPrimary)
                            .tracking(1.5)
                        
                        Text("\(ownedWeapons.count + ownedArmors.count + ownedRings.count + ownedAmulets.count) ITEMS")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Theme.secondaryCard)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Tabs
                HStack(spacing: 0) {
                    TabButton(title: "WEAPONS", isSelected: selectedTab == .weapon) {
                        withAnimation { selectedTab = .weapon }
                    }
                    TabButton(title: "ARMOR", isSelected: selectedTab == .armor) {
                        withAnimation { selectedTab = .armor }
                    }
                    TabButton(title: "RINGS", isSelected: selectedTab == .ring) {
                        withAnimation { selectedTab = .ring }
                    }
                    TabButton(title: "AMULETS", isSelected: selectedTab == .amulet) {
                        withAnimation { selectedTab = .amulet }
                    }
                }
                .padding(4)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                // Grid
                ScrollView {
                    let items: [EquipmentItem] = {
                        switch selectedTab {
                        case .weapon: return ownedWeapons
                        case .armor: return ownedArmors
                        case .ring: return ownedRings
                        case .amulet: return ownedAmulets
                        }
                    }()
                    
                    if items.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textMuted)
                            Text("No \(selectedTab.rawValue.lowercased()) found")
                                .font(.headline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 100)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 16) {
                            ForEach(items) { item in
                                let isEquipped = (character.equippedWeaponId == item.id) || (character.equippedArmorId == item.id) || (character.equippedRingId == item.id) || (character.equippedAmuletId == item.id)
                                InventoryGridCell(item: item, isEquipped: isEquipped) {
                                    withAnimation(.spring()) {
                                        selectedItem = item
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            
            // Item Inspector Sheet
            if let item = selectedItem {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { selectedItem = nil }
                        }
                    
                    VStack {
                        Spacer()
                        InventoryItemSheet(item: item, character: character) {
                            withAnimation { selectedItem = nil }
                        }
                        .transition(.move(edge: .bottom))
                    }
                }
                .zIndex(100)
            }
        }
    }
}

struct TabButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(isSelected ? Color.black : Theme.textSecondary)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.primary)
                                .glow(color: Theme.primary.opacity(0.4), radius: 6)
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InventoryGridCell: View {
    var item: EquipmentItem
    var isEquipped: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(item.rarity.color.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isEquipped ? Theme.success : item.rarity.color.opacity(0.3), lineWidth: isEquipped ? 2 : 1)
                        )
                    
                    Image(systemName: item.getIconName())
                        .font(.system(size: 36))
                        .foregroundColor(item.rarity.color)
                        .glow(color: item.rarity.color.opacity(0.5), radius: 8)
                    
                    if isEquipped {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.success)
                                    .background(Circle().fill(Color.black))
                                    .padding(4)
                            }
                        }
                    }
                }
                
                Text(item.name)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }
}

struct InventoryItemSheet: View {
    var item: EquipmentItem
    var character: Character
    var onClose: () -> Void
    @ObservedObject var firebaseService = FirebaseService.shared
    
    var isEquipped: Bool {
        character.equippedWeaponId == item.id || character.equippedArmorId == item.id || character.equippedRingId == item.id || character.equippedAmuletId == item.id
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(item.rarity.color.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(item.rarity.color.opacity(0.5), lineWidth: 1.5)
                        )
                    
                    Image(systemName: item.getIconName())
                        .font(.system(size: 40))
                        .foregroundColor(item.rarity.color)
                        .glow(color: item.rarity.color.opacity(0.6), radius: 10)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    
                    Text(item.rarity.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.rarity.color.opacity(0.2))
                        .foregroundColor(item.rarity.color)
                        .cornerRadius(6)
                    
                    if let restricted = item.classRestriction {
                        Text("Class: \(restricted.rawValue)")
                            .font(.caption)
                            .foregroundColor(restricted == character.selectedClass ? Theme.success : Theme.danger)
                    } else {
                        Text("Class: All")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.leading, 8)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.textMuted)
                }
            }
            
            Text(item.description)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Stats Grid
            HStack {
                if item.slot == .weapon || item.combatPowerBonus > 0 {
                    StatBadge(icon: "bolt.fill", title: "POWER", value: "+\(item.combatPowerBonus)", color: Theme.danger)
                }
                if item.slot == .armor || item.defense > 0 {
                    StatBadge(icon: "shield.fill", title: "DEFENSE", value: "+\(item.defense)", color: Theme.success)
                }
            }
            
            // Equip Button
            Button(action: {
                // If wrong class, we shouldn't allow equip
                if let restriction = item.classRestriction, restriction != character.selectedClass {
                    return
                }
                
                firebaseService.equipItem(itemId: item.id, slot: item.slot)
                onClose()
            }) {
                HStack {
                    if isEquipped {
                        Image(systemName: "checkmark")
                        Text("EQUIPPED")
                    } else {
                        if let restriction = item.classRestriction, restriction != character.selectedClass {
                            Image(systemName: "lock.fill")
                            Text("WRONG CLASS")
                        } else {
                            Text("EQUIP ITEM")
                        }
                    }
                }
                .font(.headline)
                .fontWeight(.black)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Group {
                        if isEquipped {
                            Theme.success
                        } else if let restriction = item.classRestriction, restriction != character.selectedClass {
                            Theme.secondaryCard
                        } else {
                            Theme.primary
                        }
                    }
                )
                .cornerRadius(12)
            }
            .disabled(isEquipped || (item.classRestriction != nil && item.classRestriction != character.selectedClass))
        }
        .padding(24)
        .background(Theme.cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.border, lineWidth: 1)
                .opacity(0.5)
        )
    }
}

struct StatBadge: View {
    var icon: String
    var title: String
    var value: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
