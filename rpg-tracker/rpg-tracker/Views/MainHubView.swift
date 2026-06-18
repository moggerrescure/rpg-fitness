import SwiftUI

struct MainHubView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @State private var currentTab: Int = 0
    @State private var showClassSelection: Bool = false
    @State private var showProfile: Bool = false
    @State private var toastMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                if currentTab == 0 || currentTab == 3 {
                    AnimatedBackgroundView(backgroundType: .general)
                } else {
                    Theme.background
                        .ignoresSafeArea()
                }
                
                if firebaseService.currentCharacter == nil {
                    ClassSelectionView {
                        showClassSelection = false
                    }
                } else {
                    VStack(spacing: 0) {
                        // Main Tab Views
                        ZStack {
                            switch currentTab {
                            case 0:
                                HomeDashboardView(showClassSelection: $showClassSelection, showProfile: $showProfile, toastMessage: $toastMessage)
                            case 1:
                                BattleArenaView()
                            case 2:
                                CameraTrackingView(selectedClass: firebaseService.currentCharacter?.selectedClass ?? .archer)
                            case 3:
                                ClanDashboardView()
                            default:
                                HomeDashboardView(showClassSelection: $showClassSelection, showProfile: $showProfile, toastMessage: $toastMessage)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Custom Bottom Nav Bar
                        CustomBottomNavBar(currentTab: $currentTab, activeColor: firebaseService.currentCharacter?.selectedClass.themeColor ?? Theme.primary)
                    }
                }
                
                // Floating Toast Notification
                if let msg = toastMessage {
                    VStack {
                        FloatingToastView(message: msg)
                            .padding(.top, 40)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .hideNavigationBar()
            .sheet(isPresented: $showClassSelection) {
                ClassSelectionView {
                    showClassSelection = false
                }
            }
            .sheet(isPresented: $showProfile) {
                if let char = firebaseService.currentCharacter {
                    PlayerProfileView(character: char)
                }
            }
        }
    }
}

// Floating Toast View for class changes
struct FloatingToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.success)
            Text(message)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.85))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.success.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
}

// 1. Home Dashboard panel
struct HomeDashboardView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @Binding var showClassSelection: Bool
    @Binding var showProfile: Bool
    @Binding var toastMessage: String?
    @State private var showArmoryShop: Bool = false
    
    private var equippedWeapon: EquipmentItem? {
        guard let char = firebaseService.currentCharacter else { return nil }
        if let weaponId = char.equippedWeaponId {
            return EquipmentItem.findWeapon(by: weaponId)
        }
        return EquipmentItem.starterWeapons[char.selectedClass]
    }
    
    private var equippedArmor: EquipmentItem? {
        guard let char = firebaseService.currentCharacter else { return nil }
        if let armorId = char.equippedArmorId {
            return EquipmentItem.findArmor(by: armorId)
        }
        return EquipmentItem.starterArmors[char.selectedClass]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top header profile
                if let char = firebaseService.currentCharacter {
                    HStack {
                        Button(action: { showProfile = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(char.selectedClass.themeColor)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("LEVEL \(char.level)")
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(char.selectedClass.themeColor)
                                        .tracking(1)
                                    
                                    Text(char.username)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.textPrimary)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        // Gold Count
                        HStack(spacing: 6) {
                            Image(systemName: "centsign.circle.fill")
                                .foregroundColor(Theme.healerColor)
                            Text("\(char.gold)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.cardBackground.opacity(0.85))
                        .cornerRadius(12)
                        
                        // Shop Cart Button
                        Button(action: { showArmoryShop = true }) {
                            Image(systemName: "cart.fill")
                                .foregroundColor(Theme.warning)
                                .padding(8)
                                .background(Theme.cardBackground.opacity(0.85))
                                .clipShape(Circle())
                        }
                        
                        // Switch class gear icon
                        Button(action: { showClassSelection = true }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(Theme.textSecondary)
                                .padding(8)
                                .background(Theme.cardBackground.opacity(0.85))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Horizontal Class Switcher Panel
                    ClassSwitcherPanel(toastMessage: $toastMessage)
                    
                    // XP bar progression
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("XP PROGRESSION")
                                .font(.system(size: 10, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            Text("\(char.xp)/\(char.xpForNextLevel) XP")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.cardBackground)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(char.selectedClass.themeColor)
                                    .frame(width: CGFloat(char.xp) / CGFloat(char.xpForNextLevel) * geo.size.width)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal)
                    
                    // Combat Power details
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COMBAT FORCE POWER")
                                .font(.caption2)
                                .foregroundColor(Theme.textMuted)
                                .fontWeight(.bold)
                            Text("\(char.combatPower)")
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        Image(systemName: "bolt.fill")
                            .font(.largeTitle)
                            .foregroundColor(char.selectedClass.themeColor)
                            .glow(color: char.selectedClass.themeColor.opacity(0.4), radius: 8)
                    }
                    .padding()
                    .background(Theme.cardBackground.opacity(0.85))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Gear Slots Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EQUIPPED SLOTS (TAP TO EDIT)")
                            .font(.system(size: 10, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 16) {
                            // Slot Weapon
                            if let weapon = equippedWeapon {
                                SlotCard(
                                    title: "Weapon",
                                    itemName: weapon.name,
                                    rarity: weapon.rarity,
                                    combatBonus: "+\(weapon.combatPowerBonus) PWR",
                                    icon: "shield.fill",
                                    color: char.selectedClass.themeColor,
                                    action: { showArmoryShop = true }
                                )
                            } else {
                                SlotCard(
                                    title: "Weapon",
                                    itemName: "No Weapon",
                                    rarity: .common,
                                    combatBonus: "+0 PWR",
                                    icon: "shield.slash.fill",
                                    color: Theme.textMuted,
                                    action: { showArmoryShop = true }
                                )
                            }
                            
                            // Slot Armor
                            if let armor = equippedArmor {
                                SlotCard(
                                    title: "Armor",
                                    itemName: armor.name,
                                    rarity: armor.rarity,
                                    combatBonus: "+\(armor.defense) DEF",
                                    icon: "tshirt.fill",
                                    color: armor.rarity.color,
                                    action: { showArmoryShop = true }
                                )
                            } else {
                                SlotCard(
                                    title: "Armor",
                                    itemName: "No Armor",
                                    rarity: .common,
                                    combatBonus: "+0 DEF",
                                    icon: "tshirt.fill",
                                    color: Theme.textMuted,
                                    action: { showArmoryShop = true }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Quests card panel
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DAILY MISSION OBJECTIVES")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            QuestRow(title: "Perform 15 Squats in training", progress: "12/15", completed: false, xpReward: "+50 XP")
                            QuestRow(title: "Complete 1 real-time PvP match", progress: "1/1", completed: true, xpReward: "+80 XP")
                        }
                        .padding(.horizontal)
                    }
                    
                    // Season Pass progression bar
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("SEASON PASS: CHAPTER 1")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text("LEVEL 4")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.healerColor)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Theme.secondaryCard)
                                
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Theme.healerColor)
                                    .frame(width: 0.65 * geo.size.width)
                            }
                        }
                        .frame(height: 10)
                        
                        HStack {
                            Text("Next Tier reward:")
                                .font(.caption2)
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            Text("Dragon Pet (Legendary)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.healerColor)
                        }
                    }
                    .glassmorphicCard()
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showArmoryShop) {
                ArmoryShopView()
            }
        }
    }
}

struct SlotCard: View {
    let title: String
    let itemName: String
    let rarity: ItemRarity
    let combatBonus: String
    let icon: String
    let color: Color
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 9, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textMuted)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .padding(12)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(spacing: 2) {
                    Text(itemName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    
                    Text(combatBonus)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.success)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Theme.cardBackground.opacity(0.85))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuestRow: View {
    let title: String
    let progress: String
    let completed: Bool
    let xpReward: String
    
    var body: some View {
        HStack {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(completed ? Theme.success : Theme.textMuted)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(completed ? Theme.textSecondary : Theme.textPrimary)
                
                Text(xpReward)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.success)
            }
            
            Spacer()
            
            Text(progress)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(completed ? Theme.success : Theme.textSecondary)
                .fontWeight(.bold)
        }
        .padding()
        .background(Theme.cardBackground.opacity(0.85))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(completed ? Theme.success.opacity(0.2) : Theme.border, lineWidth: 1)
        )
    }
}

// Custom Bottom Nav controller bar
struct CustomBottomNavBar: View {
    @Binding var currentTab: Int
    let activeColor: Color
    
    var body: some View {
        HStack {
            NavBarItem(icon: "gamecontroller.fill", label: "HUB", tab: 0, currentTab: $currentTab, color: activeColor)
            Spacer()
            NavBarItem(icon: "shield.fill", label: "PVP", tab: 1, currentTab: $currentTab, color: activeColor)
            Spacer()
            NavBarItem(icon: "camera.fill", label: "TRAIN", tab: 2, currentTab: $currentTab, color: activeColor)
            Spacer()
            NavBarItem(icon: "person.3.fill", label: "CLAN", tab: 3, currentTab: $currentTab, color: activeColor)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.border),
            alignment: .top
        )
    }
}

struct NavBarItem: View {
    let icon: String
    let label: String
    let tab: Int
    @Binding var currentTab: Int
    let color: Color
    
    var body: some View {
        Button(action: { currentTab = tab }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(currentTab == tab ? color : Theme.textSecondary)
            .frame(width: 60, height: 44)
        }
    }
}

struct ClassSwitcherPanel: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @Binding var toastMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SWITCH ACTIVE HERO CLASS")
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Theme.textSecondary)
                .tracking(1.5)
                .padding(.horizontal)
            
            HStack(spacing: 8) {
                ForEach(CharacterClass.allCases) { charClass in
                    let isSelected = firebaseService.currentCharacter?.selectedClass == charClass
                    let prog = firebaseService.currentCharacter?.progressions[charClass.rawValue]
                    let lvl = prog?.level ?? 1
                    
                    Button(action: {
                        guard var char = firebaseService.currentCharacter else { return }
                        if char.selectedClass != charClass {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                char.selectedClass = charClass
                                firebaseService.syncCharacter(char)
                                toastMessage = "Class changed to \(charClass.rawValue)!"
                            }
                            
                            // Auto-clear toast
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if toastMessage == "Class changed to \(charClass.rawValue)!" {
                                    withAnimation {
                                        toastMessage = nil
                                    }
                                }
                            }
                        }
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(charClass.themeColor.opacity(isSelected ? 0.25 : 0.08))
                                    .frame(width: 38, height: 38)
                                
                                Image(systemName: classIcon(for: charClass))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(charClass.themeColor)
                            }
                            .glow(color: isSelected ? charClass.themeColor.opacity(0.3) : .clear, radius: 5)
                            
                            VStack(spacing: 1) {
                                Text(charClass.rawValue.uppercased())
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                                
                                Text("LVL \(lvl)")
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundColor(isSelected ? charClass.themeColor : Theme.textMuted)
                            }
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? Theme.secondaryCard.opacity(0.9) : Theme.cardBackground.opacity(0.6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? charClass.themeColor : Theme.border, lineWidth: isSelected ? 2 : 1)
                        )
                        .scaleEffect(isSelected ? 1.02 : 0.98)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func classIcon(for cls: CharacterClass) -> String {
        switch cls {
        case .archer: return "arrow.up.forward.app.fill"
        case .mage: return "bolt.heart.fill"
        case .swordsman: return "hammer.fill"
        case .healer: return "cross.case.fill"
        }
    }
}

struct MainHubView_Previews: PreviewProvider {
    static var previews: some View {
        MainHubView()
    }
}
