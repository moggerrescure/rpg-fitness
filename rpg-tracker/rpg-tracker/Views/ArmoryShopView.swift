import SwiftUI

struct ArmoryShopView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0 // 0: Inventory, 1: Shop
    @State private var filterByClass = true
    @State private var shopToastMessage: String? = nil
    
    private var character: Character {
        firebaseService.currentCharacter ?? Character(id: "local", username: "FitnessHero", selectedClass: .archer)
    }
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Panel
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ARMORY & SHOP")
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(Theme.textPrimary)
                            .tracking(1.5)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "centsign.circle.fill")
                                .foregroundColor(Theme.healerColor)
                            Text("\(character.gold) GOLD")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.healerColor)
                        }
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
                
                // Premium Pill Segment Selector
                HStack(spacing: 0) {
                    ForEach(0..<2) { idx in
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedTab = idx
                            }
                        }) {
                            Text(idx == 0 ? "MY ARMORY" : "ARMOR SHOP")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(selectedTab == idx ? Color.black : Theme.textSecondary)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    ZStack {
                                        if selectedTab == idx {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(character.selectedClass.themeColor)
                                                .glow(color: character.selectedClass.themeColor.opacity(0.4), radius: 6)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(4)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                if selectedTab == 0 {
                    // Inventory tab
                    InventoryListView(character: character, firebaseService: firebaseService)
                } else {
                    // Shop tab
                    ShopListView(
                        character: character,
                        firebaseService: firebaseService,
                        filterByClass: $filterByClass,
                        showToast: { msg in
                            shopToastMessage = msg
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if shopToastMessage == msg {
                                    shopToastMessage = nil
                                }
                            }
                        }
                    )
                }
            }
            
            // Toast notification
            if let msg = shopToastMessage {
                VStack {
                    Spacer()
                    FloatingToastView(message: msg)
                        .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
    }
}

// 1. Inventory List View
struct InventoryListView: View {
    let character: Character
    @ObservedObject var firebaseService: FirebaseService
    
    // We statically compute owned armors, caching to prevent re-evaluation lag
    private var ownedArmors: [EquipmentItem] {
        let starters = EquipmentItem.starterArmors.values.filter { character.ownedEquipmentIds.contains($0.id) }
        let purchased = EquipmentItem.allShopArmors.filter { character.ownedEquipmentIds.contains($0.id) }
        return Array(starters) + purchased
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if ownedArmors.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textMuted)
                        Text("NO ARMOR OWNED")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.top, 100)
                } else {
                    ForEach(ownedArmors) { armor in
                        let isEquipped = character.equippedArmorId == armor.id
                        let isRestricted = armor.classRestriction != nil && armor.classRestriction != character.selectedClass
                        
                        HStack(spacing: 16) {
                            // Emblem / Icon of the armor type with Rarity glow
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(armor.rarity.color.opacity(0.12))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(armor.rarity.color.opacity(0.3), lineWidth: 1.2)
                                    )
                                
                                Image(systemName: armor.getIconName())
                                    .font(.title3)
                                    .foregroundColor(armor.rarity.color)
                            }
                            .glow(color: armor.rarity.color.opacity(0.35), radius: 6)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(armor.name)
                                        .font(.subheadline)
                                        .fontWeight(.black)
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text(armor.rarity.rawValue.uppercased())
                                        .font(.system(size: 7, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(armor.rarity.color.opacity(0.2))
                                        .foregroundColor(armor.rarity.color)
                                        .cornerRadius(4)
                                }
                                
                                Text(armor.description)
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                                
                                HStack(spacing: 12) {
                                    Text("+\(armor.defense) DEFENSE")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundColor(Theme.success)
                                    
                                    if let restrict = armor.classRestriction {
                                        Text("\(restrict.rawValue.uppercased()) ONLY")
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundColor(restrict.themeColor)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Equip / Active Button
                            if isEquipped {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text("ACTIVE")
                                }
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.success.opacity(0.12))
                                .foregroundColor(Theme.success)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.success.opacity(0.4), lineWidth: 1)
                                )
                                .glow(color: Theme.success.opacity(0.2), radius: 4)
                            } else {
                                Button(action: {
                                    guard !isRestricted else { return }
                                    var updatedChar = character
                                    updatedChar.equipArmor(itemId: armor.id)
                                    firebaseService.syncCharacter(updatedChar)
                                }) {
                                    HStack(spacing: 4) {
                                        if isRestricted {
                                            Image(systemName: "lock.fill")
                                            Text("LOCKED")
                                        } else {
                                            Text("EQUIP")
                                        }
                                    }
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isRestricted ? Color.gray.opacity(0.08) : Theme.primary.opacity(0.15))
                                    .foregroundColor(isRestricted ? Theme.textMuted : Theme.primary)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isRestricted ? Color.clear : Theme.primary.opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .disabled(isRestricted)
                                .buttonStyle(TactileButtonStyle())
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isEquipped ? Theme.success.opacity(0.3) : armor.rarity.color.opacity(0.15), lineWidth: isEquipped ? 1.5 : 1)
                        )
                        .shadow(color: isEquipped ? Theme.success.opacity(0.08) : armor.rarity.color.opacity(0.05), radius: 8, x: 0, y: 3)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }
}

// 2. Shop List View
struct ShopListView: View {
    let character: Character
    @ObservedObject var firebaseService: FirebaseService
    @Binding var filterByClass: Bool
    let showToast: (String) -> Void
    
    // Compute shop armors with optional filtering
    private var filteredShopArmors: [EquipmentItem] {
        if filterByClass {
            return EquipmentItem.allShopArmors.filter {
                $0.classRestriction == nil || $0.classRestriction == character.selectedClass
            }
        } else {
            return EquipmentItem.allShopArmors
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Filter Toggle Panel
            Toggle(isOn: $filterByClass) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundColor(character.selectedClass.themeColor)
                    Text("SHOW MY CLASS ONLY (\(character.selectedClass.rawValue.uppercased()))")
                        .font(.system(size: 10, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: character.selectedClass.themeColor))
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Theme.cardBackground.opacity(0.5))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // List of armors in the shop
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(filteredShopArmors) { armor in
                        let isOwned = character.ownedEquipmentIds.contains(armor.id)
                        let canAfford = character.gold >= armor.cost
                        
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(armor.rarity.color.opacity(0.12))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(armor.rarity.color.opacity(0.3), lineWidth: 1.2)
                                    )
                                
                                Image(systemName: armor.getIconName())
                                    .font(.title3)
                                    .foregroundColor(armor.rarity.color)
                            }
                            .glow(color: armor.rarity.color.opacity(0.35), radius: 6)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(armor.name)
                                        .font(.subheadline)
                                        .fontWeight(.black)
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text(armor.rarity.rawValue.uppercased())
                                        .font(.system(size: 7, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(armor.rarity.color.opacity(0.2))
                                        .foregroundColor(armor.rarity.color)
                                        .cornerRadius(4)
                                }
                                
                                Text(armor.description)
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                                
                                HStack(spacing: 12) {
                                    Text("+\(armor.defense) DEFENSE")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundColor(Theme.success)
                                    
                                    if let restrict = armor.classRestriction {
                                        Text("\(restrict.rawValue.uppercased()) ONLY")
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundColor(restrict.themeColor)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Buy action
                            if isOwned {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("OWNED")
                                }
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundColor(Theme.textMuted)
                                .background(Color.gray.opacity(0.06))
                                .cornerRadius(8)
                            } else {
                                Button(action: {
                                    guard canAfford else { return }
                                    var updatedChar = character
                                    updatedChar.buyArmor(armor)
                                    firebaseService.syncCharacter(updatedChar)
                                    showToast("Purchased \(armor.name)!")
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "centsign.circle.fill")
                                            .foregroundColor(canAfford ? .black : Theme.textMuted)
                                        Text("\(armor.cost)")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(canAfford ? Theme.warning : Color.gray.opacity(0.08))
                                    .foregroundColor(canAfford ? .black : Theme.textMuted)
                                    .cornerRadius(8)
                                    .shadow(color: canAfford ? Theme.warning.opacity(0.35) : .clear, radius: 5, y: 2)
                                }
                                .disabled(!canAfford)
                                .buttonStyle(TactileButtonStyle())
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(armor.rarity.color.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: armor.rarity.color.opacity(0.05), radius: 8, x: 0, y: 3)
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}

// Satisfying tactile click bounce button style
struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
