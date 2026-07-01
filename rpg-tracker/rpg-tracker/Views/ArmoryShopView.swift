import SwiftUI

/// Full-screen Armory & Shop with tabbed Weapon / Armor browsing,
/// item preview, buy / equip / unequip mechanics, and animated background.
struct ArmoryShopView: View {
    var initialSlot: EquipmentSlot = .weapon

    @ObservedObject var firebaseService = FirebaseService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSlot: EquipmentSlot = .weapon
    @State private var selectedItem: EquipmentItem? = nil
    @State private var filterByClass = true
    @State private var toastMessage: String? = nil
    @State private var toastIsSuccess = true

    private var character: Character {
        firebaseService.currentCharacter ?? Character(id: "local", username: "Hero", selectedClass: .archer)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            AnimatedBackgroundView(backgroundType: .shop)
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                ArmoryHeaderView(
                    character: character,
                    selectedSlot: $selectedSlot,
                    filterByClass: $filterByClass,
                    dismiss: { dismiss() }
                )

                // ── Equipped Preview Strip ───────────────────────────────
                EquippedPreviewStrip(character: character, selectedSlot: selectedSlot)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // ── Slot Tabs ────────────────────────────────────────────
                SlotTabRow(selectedSlot: $selectedSlot, accentColor: character.selectedClass.themeColor)
                    .padding(.top, 12)

                // ── Item List ────────────────────────────────────────────
                ShopItemList(
                    character: character,
                    slot: selectedSlot,
                    filterByClass: filterByClass,
                    selectedItem: $selectedItem,
                    onAction: handleItemAction
                )
            }
            .onAppear { selectedSlot = initialSlot }

            // ── Toast ────────────────────────────────────────────────────
            if let msg = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: toastIsSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(toastIsSuccess ? Theme.success : Theme.danger)
                        Text(msg)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke((toastIsSuccess ? Theme.success : Theme.danger).opacity(0.4), lineWidth: 1))
                    .padding(.bottom, 32)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(200)
            }
        }
    }

    // MARK: – Action handler

    private func handleItemAction(_ action: ItemAction, _ item: EquipmentItem) {
        guard var char = firebaseService.currentCharacter else { return }

        switch action {
        case .buy:
            guard char.gold >= item.cost else {
                showToast("Not enough gold!", success: false)
                return
            }
            char.gold -= item.cost
            if !char.ownedEquipmentIds.contains(item.id) {
                char.ownedEquipmentIds.append(item.id)
            }
            // Auto-equip on purchase if nothing equipped yet
            switch item.slot {
            case .weapon where char.equippedWeaponId == nil: char.equippedWeaponId = item.id
            case .armor  where char.equippedArmorId  == nil: char.equippedArmorId  = item.id
            case .ring   where char.equippedRingId   == nil: char.equippedRingId   = item.id
            case .amulet where char.equippedAmuletId == nil: char.equippedAmuletId = item.id
            default: break
            }
            firebaseService.syncCharacter(char)
            showToast("Purchased \(item.name)!", success: true)

        case .equip:
            switch item.slot {
            case .weapon: char.equippedWeaponId = item.id
            case .armor:  char.equippedArmorId  = item.id
            case .ring:   char.equippedRingId   = item.id
            case .amulet: char.equippedAmuletId = item.id
            }
            firebaseService.syncCharacter(char)
            showToast("Equipped \(item.name)!", success: true)

        case .unequip:
            switch item.slot {
            case .weapon: char.equippedWeaponId = nil
            case .armor:  char.equippedArmorId  = nil
            case .ring:   char.equippedRingId   = nil
            case .amulet: char.equippedAmuletId = nil
            }
            firebaseService.syncCharacter(char)
            showToast("\(item.name) unequipped", success: true)
        }
    }

    private func showToast(_ msg: String, success: Bool) {
        withAnimation(.spring()) {
            toastMessage = msg
            toastIsSuccess = success
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }
}

// MARK: – Item action enum

enum ItemAction {
    case buy, equip, unequip
}

// MARK: – Header

private struct ArmoryHeaderView: View {
    let character: Character
    @Binding var selectedSlot: EquipmentSlot
    @Binding var filterByClass: Bool
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ARMORY & SHOP")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.black)
                    .foregroundColor(Theme.textPrimary)
                    .tracking(1.5)

                HStack(spacing: 6) {
                    Image(systemName: "centsign.circle.fill")
                        .foregroundColor(Theme.healerColor)
                    Text("\(character.gold) GOLD")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.healerColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.secondaryCard)
                        .clipShape(Circle())
                }

                // Class filter toggle
                Toggle("", isOn: $filterByClass)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: character.selectedClass.themeColor))
                    .overlay(
                        Text("MY CLASS")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundColor(filterByClass ? character.selectedClass.themeColor : Theme.textMuted)
                            .offset(x: -48)
                    )
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

// MARK: – Equipped preview strip at top

private struct EquippedPreviewStrip: View {
    let character: Character
    let selectedSlot: EquipmentSlot

    private var equippedWeapon: EquipmentItem? {
        guard let id = character.equippedWeaponId else { return EquipmentItem.starterWeapons[character.selectedClass] }
        return EquipmentItem.findWeapon(by: id) ?? EquipmentItem.allShopWeapons.first { $0.id == id }
    }

    private var equippedArmor: EquipmentItem? {
        guard let id = character.equippedArmorId else { return EquipmentItem.starterArmors[character.selectedClass] }
        return EquipmentItem.findArmor(by: id)
    }

    private func chipItem(for slot: EquipmentSlot) -> EquipmentItem? {
        switch slot {
        case .weapon: return equippedWeapon
        case .armor:  return equippedArmor
        case .ring:   return character.equippedRing
        case .amulet: return character.equippedAmulet
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach([EquipmentSlot.weapon, .armor, .ring, .amulet], id: \.rawValue) { slot in
                let item = chipItem(for: slot)
                let isActive = slot == selectedSlot
                VStack(spacing: 4) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill((item?.rarity.color ?? Color.gray).opacity(isActive ? 0.25 : 0.08))
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isActive ? (item?.rarity.color ?? character.selectedClass.themeColor) : Theme.border, lineWidth: isActive ? 2 : 1)
                            )

                        ItemIconView(item: item, fallbackIcon: slotIcon(slot))
                            .frame(width: 24, height: 24)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(item?.rarity.color ?? Theme.textMuted)
                    }
                    .glow(color: isActive ? (item?.rarity.color ?? character.selectedClass.themeColor).opacity(0.4) : .clear, radius: 5)

                    Text(slot.rawValue.uppercased())
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundColor(isActive ? Theme.textPrimary : Theme.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func slotIcon(_ slot: EquipmentSlot) -> String {
        switch slot {
        case .weapon: return "bolt.fill"
        case .armor:  return "shield.fill"
        case .ring:   return "circle.dotted"
        case .amulet: return "sparkles"
        }
    }
}

// MARK: – Slot tab row

private struct SlotTabRow: View {
    @Binding var selectedSlot: EquipmentSlot
    let accentColor: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach([EquipmentSlot.weapon, .armor, .ring, .amulet], id: \.rawValue) { slot in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSlot = slot
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: slotIcon(slot))
                            .font(.system(size: 14, weight: .bold))
                        Text(slot.rawValue.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(selectedSlot == slot ? accentColor : Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        VStack {
                            Spacer()
                            if selectedSlot == slot {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(accentColor)
                                    .frame(height: 2)
                            }
                        }
                    )
                }
                .buttonStyle(TactileButtonStyle())
            }
        }
        .background(Theme.cardBackground.opacity(0.85))
    }

    private func slotIcon(_ slot: EquipmentSlot) -> String {
        switch slot {
        case .weapon: return "bolt.fill"
        case .armor:  return "shield.fill"
        case .ring:   return "circle.dotted"
        case .amulet: return "sparkles"
        }
    }
}

// MARK: – Shop item list

private struct ShopItemList: View {
    let character: Character
    let slot: EquipmentSlot
    let filterByClass: Bool
    @Binding var selectedItem: EquipmentItem?
    let onAction: (ItemAction, EquipmentItem) -> Void

    private var allItems: [EquipmentItem] {
        switch slot {
        case .weapon: return EquipmentItem.allShopWeapons
        case .armor:  return EquipmentItem.allShopArmors
        case .ring:   return EquipmentItem.allShopRings
        case .amulet: return EquipmentItem.allShopAmulets
        }
    }

    private var filteredItems: [EquipmentItem] {
        if filterByClass {
            return allItems.filter { $0.classRestriction == nil || $0.classRestriction == character.selectedClass }
        }
        return allItems
    }

    // Also add starter items that the player owns to the top
    private var starterItems: [EquipmentItem] {
        switch slot {
        case .weapon: return Array(EquipmentItem.starterWeapons.values.filter { character.ownedEquipmentIds.contains($0.id) })
        case .armor:  return Array(EquipmentItem.starterArmors.values.filter { character.ownedEquipmentIds.contains($0.id) })
        default: return []
        }
    }

    private var displayItems: [EquipmentItem] {
        // Starters at top (if owned), then shop items
        let owned = filteredItems.filter { character.ownedEquipmentIds.contains($0.id) }
        let unowned = filteredItems.filter { !character.ownedEquipmentIds.contains($0.id) }
        let starters = starterItems.filter { item in !filteredItems.contains(where: { $0.id == item.id }) }
        return starters + owned + unowned
    }

    private func equippedId(for slot: EquipmentSlot) -> String? {
        switch slot {
        case .weapon: return character.equippedWeaponId
        case .armor:  return character.equippedArmorId
        case .ring:   return character.equippedRingId
        case .amulet: return character.equippedAmuletId
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                // Empty state hint for ring/amulet if nothing bought yet
                if displayItems.isEmpty {
                    let slotColor = character.selectedClass.themeColor
                    VStack(spacing: 16) {
                        Image(systemName: slot == .ring ? "circle.dotted" : "sparkles")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(slotColor.opacity(0.4))
                        Text("No \(slot.rawValue)s Yet")
                            .font(.system(.headline, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(Theme.textSecondary)
                        Text("Purchase a \(slot.rawValue.lowercased()) below to boost your Combat Power")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(30)
                    .background(slotColor.opacity(0.06))
                    .cornerRadius(18)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(slotColor.opacity(0.15), lineWidth: 1))
                    .padding(.top, 10)
                }

                ForEach(displayItems) { item in
                    let isOwned    = character.ownedEquipmentIds.contains(item.id)
                    let isEquipped = equippedId(for: slot) == item.id
                    let canAfford  = character.gold >= item.cost
                    let isSelected = selectedItem?.id == item.id

                    ShopItemRow(
                        item: item,
                        isOwned: isOwned,
                        isEquipped: isEquipped,
                        canAfford: canAfford,
                        isExpanded: isSelected,
                        accentColor: character.selectedClass.themeColor,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedItem = (selectedItem?.id == item.id) ? nil : item
                            }
                        },
                        onAction: { action in onAction(action, item) }
                    )
                }

                Color.clear.frame(height: 30)
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
    }
}


// MARK: – Individual shop row

private struct ShopItemRow: View {
    let item: EquipmentItem
    let isOwned: Bool
    let isEquipped: Bool
    let canAfford: Bool
    let isExpanded: Bool
    let accentColor: Color
    let onTap: () -> Void
    let onAction: (ItemAction) -> Void

    private var statLabel: String {
        var parts: [String] = []
        if item.combatPowerBonus > 0 { parts.append("+\(item.combatPowerBonus) PWR") }
        if item.defense > 0 { parts.append("+\(item.defense) DEF") }
        return parts.joined(separator: "  ")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // ── Main row ──────────────────────────────────────────
                HStack(spacing: 14) {
                    ZStack {
                        ItemIconView(item: item, fallbackIcon: "questionmark")
                            .frame(width: 52, height: 52)
                            .foregroundColor(item.rarity.color)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isEquipped ? item.rarity.color : item.rarity.color.opacity(0.3), lineWidth: isEquipped ? 2 : 1)
                            )
                    }
                    .glow(color: isEquipped ? item.rarity.color.opacity(0.45) : .clear, radius: 7)

                    // Info
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.black)
                                .foregroundColor(Theme.textPrimary)

                            RarityBadge(rarity: item.rarity)

                            if isEquipped {
                                Text("EQUIPPED")
                                    .font(.system(size: 7, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(accentColor)
                                    .cornerRadius(4)
                            }
                        }

                        if let restrict = item.classRestriction {
                            Text("\(restrict.rawValue.uppercased()) ONLY")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(restrict.themeColor)
                        }

                        Text(statLabel)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.success)
                    }

                    Spacer()

                    // Action badge (right)
                    if isOwned || isEquipped {
                        VStack(spacing: 3) {
                            Image(systemName: isEquipped ? "checkmark.circle.fill" : "bag.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(isEquipped ? accentColor : Theme.textMuted)
                            Text(isEquipped ? "EQUIP." : "OWNED")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundColor(isEquipped ? accentColor : Theme.textMuted)
                        }
                    } else {
                        VStack(spacing: 3) {
                            Image(systemName: "centsign.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(canAfford ? Theme.healerColor : Theme.textMuted)
                            Text("\(item.cost)")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(canAfford ? Theme.healerColor : Theme.textMuted)
                        }
                    }

                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(14)

                // ── Expanded details ──────────────────────────────────
                if isExpanded {
                    Divider().background(Theme.border).padding(.horizontal, 14)

                    VStack(spacing: 12) {
                        // Description
                        Text(item.description)
                            .font(.system(size: 12, design: .default))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Stats row
                        HStack(spacing: 12) {
                            if item.combatPowerBonus > 0 {
                                StatChip(icon: "bolt.fill", label: "POWER", value: "+\(item.combatPowerBonus)", color: accentColor)
                            }
                            if item.defense > 0 {
                                StatChip(icon: "shield.fill", label: "DEFENSE", value: "+\(item.defense)", color: Theme.success)
                            }
                        }

                        // Action buttons
                        HStack(spacing: 10) {
                            if !isOwned {
                                // Buy
                                ActionButton(
                                    label: canAfford ? "BUY  \(item.cost)g" : "NEED \(item.cost - (firebaseService.character?.gold ?? 0))g MORE",
                                    icon: canAfford ? "cart.fill" : "lock.fill",
                                    color: canAfford ? Theme.healerColor : Color.gray,
                                    enabled: canAfford
                                ) { onAction(.buy) }
                            } else if isEquipped {
                                // Unequip
                                ActionButton(
                                    label: "UNEQUIP",
                                    icon: "xmark.circle.fill",
                                    color: Theme.danger,
                                    enabled: true
                                ) { onAction(.unequip) }
                            } else {
                                // Equip
                                ActionButton(
                                    label: "EQUIP",
                                    icon: "checkmark.circle.fill",
                                    color: accentColor,
                                    enabled: true
                                ) { onAction(.equip) }
                            }
                        }
                    }
                    .padding(14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background(
            ZStack {
                if isEquipped {
                    accentColor.opacity(0.12)
                } else {
                    Theme.cardBackground.opacity(0.7)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isEquipped ? accentColor.opacity(0.4) : item.rarity.color.opacity(0.15),
                    lineWidth: isEquipped ? 1.5 : 1
                )
        )
        .shadow(color: isEquipped ? accentColor.opacity(0.1) : Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        .buttonStyle(TactileButtonStyle())
    }

    // Shortcut for gold computation
    private var firebaseService: FirebaseService { .shared }
}

// MARK: – Sub-components

private struct RarityBadge: View {
    let rarity: ItemRarity
    var body: some View {
        Text(rarity.rawValue.uppercased())
            .font(.system(size: 7, weight: .black, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(rarity.color.opacity(0.2))
            .foregroundColor(rarity.color)
            .cornerRadius(4)
    }
}

private struct StatChip: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                Text(value)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1))
        .frame(maxWidth: .infinity)
    }
}

private struct ActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            }
            .foregroundColor(enabled ? .white : Theme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(enabled ? color : Color.gray.opacity(0.15))
            .cornerRadius(12)
            .shadow(color: enabled ? color.opacity(0.3) : .clear, radius: 6, y: 2)
        }
        .disabled(!enabled)
        .buttonStyle(TactileButtonStyle())
    }
}

// MARK: – Character extension helper inside view file scope

private extension FirebaseService {
    var character: Character? { currentCharacter }
}
