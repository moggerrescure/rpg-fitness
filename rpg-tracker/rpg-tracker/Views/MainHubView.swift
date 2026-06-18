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
                switch currentTab {
                case 0:
                    AnimatedBackgroundView(backgroundType: .tavern)
                case 1:
                    AnimatedBackgroundView(backgroundType: .arena)
                case 2:
                    AnimatedBackgroundView(backgroundType: .trainingRuins)
                case 3:
                    AnimatedBackgroundView(backgroundType: .clanHall)
                default:
                    AnimatedBackgroundView(backgroundType: .tavern)
                }
                
                if firebaseService.currentCharacter == nil {
                    ClassSelectionView {
                        showClassSelection = false
                    }
                } else {
                    ZStack(alignment: .bottom) {
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
                                ClanDashboardView(currentTab: $currentTab)
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
                                ZStack {
                                    if let avatar = char.avatarName, let uiImage = loadLocalAvatar(named: avatar) {
                                        Image(platformImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(char.selectedClass.themeColor.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Image(systemName: "person.crop.circle.fill")
                                                    .font(.system(size: 30))
                                                    .foregroundColor(char.selectedClass.themeColor)
                                            )
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [char.selectedClass.themeColor, char.selectedClass.themeColor.opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .glow(color: char.selectedClass.themeColor.opacity(0.35), radius: 6)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("LEVEL \(char.level)")
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(char.selectedClass.themeColor)
                                        .tracking(1.5)
                                    
                                    Text(char.username)
                                        .font(.system(.title3, design: .default))
                                        .fontWeight(.black)
                                        .foregroundColor(Theme.textPrimary)
                                }
                            }
                        }
                        .buttonStyle(TactileButtonStyle())
                        
                        Spacer()
                        
                        // Gold Count
                        HStack(spacing: 6) {
                            Image(systemName: "centsign.circle.fill")
                                .foregroundColor(Theme.healerColor)
                            Text("\(char.gold)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.cardBackground.opacity(0.85))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        
                        // Shop Cart Button
                        Button(action: { showArmoryShop = true }) {
                            Image(systemName: "cart.fill")
                                .foregroundColor(Theme.warning)
                                .padding(10)
                                .background(Theme.cardBackground.opacity(0.85))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(TactileButtonStyle())
                        
                        // Switch class gear icon
                        Button(action: { showClassSelection = true }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(Theme.textSecondary)
                                .padding(10)
                                .background(Theme.cardBackground.opacity(0.85))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(TactileButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Horizontal Class Switcher Panel
                    ClassSwitcherPanel(toastMessage: $toastMessage)
                    
                    // XP bar progression
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("XP PROGRESSION")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1)
                            Spacer()
                            Text("\(char.xp)/\(char.xpForNextLevel) XP")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Theme.cardBackground)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(char.selectedClass.themeColor)
                                    .frame(width: CGFloat(char.xp) / CGFloat(char.xpForNextLevel) * geo.size.width)
                                    .glow(color: char.selectedClass.themeColor.opacity(0.4), radius: 4)
                            }
                        }
                        .frame(height: 10)
                    }
                    .padding(.horizontal)
                    
                    // Combat Power details
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COMBAT FORCE POWER")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1)
                            Text("\(char.combatPower)")
                                .font(.system(size: 32, weight: .black, design: .monospaced))
                                .foregroundColor(Theme.textPrimary)
                                .glow(color: char.selectedClass.themeColor.opacity(0.35), radius: 6)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(char.selectedClass.themeColor.opacity(0.15))
                                .frame(width: 50, height: 50)
                            Image(systemName: "bolt.fill")
                                .font(.title)
                                .foregroundColor(char.selectedClass.themeColor)
                                .glow(color: char.selectedClass.themeColor.opacity(0.5), radius: 8)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.cardBackground.opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(LinearGradient(
                                colors: [char.selectedClass.themeColor.opacity(0.4), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.5)
                    )
                    .padding(.horizontal)
                    
                    // Gear Slots Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EQUIPPED SLOTS (TAP TO EDIT)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1)
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
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1)
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
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text("LEVEL 4")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(Theme.healerColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.healerColor.opacity(0.15))
                                .cornerRadius(6)
                                .glow(color: Theme.healerColor.opacity(0.35), radius: 4)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Theme.secondaryCard)
                                
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(LinearGradient(
                                        colors: [Theme.healerColor, Theme.warning],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(width: 0.65 * geo.size.width)
                                    .glow(color: Theme.healerColor.opacity(0.4), radius: 5)
                            }
                        }
                        .frame(height: 10)
                        
                        HStack {
                            Text("Next Tier reward:")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            Text("Dragon Pet (Legendary)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.healerColor)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.cardBackground.opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(LinearGradient(
                                colors: [Theme.healerColor.opacity(0.25), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.5)
                    )
                    .padding(.horizontal)
                    
                    // Space for floating tab bar
                    Spacer()
                        .frame(height: 100)
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
            VStack(spacing: 10) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(1)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.12))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                .glow(color: color.opacity(0.35), radius: 6)
                
                VStack(spacing: 2) {
                    Text(itemName)
                        .font(.system(.caption, design: .default))
                        .fontWeight(.black)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    
                    Text(combatBonus)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.success)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient(
                        colors: [color.opacity(0.35), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(TactileButtonStyle())
    }
}

struct QuestRow: View {
    let title: String
    let progress: String
    let completed: Bool
    let xpReward: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(completed ? Theme.success.opacity(0.15) : Theme.secondaryCard)
                    .frame(width: 28, height: 28)
                
                Image(systemName: completed ? "checkmark" : "circle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(completed ? Theme.success : Theme.textSecondary)
            }
            .glow(color: completed ? Theme.success.opacity(0.3) : .clear, radius: 4)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(completed ? Theme.textSecondary : Theme.textPrimary)
                    .lineLimit(2)
                
                Text(xpReward)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.success)
            }
            
            Spacer()
            
            Text(progress)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(completed ? Theme.success : Theme.textSecondary)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(completed ? Theme.success.opacity(0.1) : Theme.secondaryCard.opacity(0.5))
                .cornerRadius(6)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(completed ? Theme.success.opacity(0.3) : Theme.border, lineWidth: 1)
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
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.cardBackground.opacity(0.85))
                .shadow(color: activeColor.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(LinearGradient(
                    colors: [activeColor.opacity(0.35), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

struct NavBarItem: View {
    let icon: String
    let label: String
    let tab: Int
    @Binding var currentTab: Int
    let color: Color
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .scaleEffect(currentTab == tab ? 1.15 : 1.0)
                    .glow(color: currentTab == tab ? color.opacity(0.4) : .clear, radius: 4)
                
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
            }
            .foregroundColor(currentTab == tab ? color : Theme.textSecondary)
            .frame(width: 60, height: 44)
        }
        .buttonStyle(TactileButtonStyle())
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
