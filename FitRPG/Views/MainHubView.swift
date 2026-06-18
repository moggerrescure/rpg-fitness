import SwiftUI

struct MainHubView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @State private var currentTab: Int = 0
    @State private var showClassSelection: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
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
                                HomeDashboardView(showClassSelection: $showClassSelection)
                            case 1:
                                BattleArenaView()
                            case 2:
                                CameraTrackingView(selectedClass: firebaseService.currentCharacter?.selectedClass ?? .archer)
                            case 3:
                                ClanDashboardView()
                            default:
                                HomeDashboardView(showClassSelection: $showClassSelection)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Custom Bottom Nav Bar
                        CustomBottomNavBar(currentTab: $currentTab, activeColor: firebaseService.currentCharacter?.selectedClass.themeColor ?? Theme.primary)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showClassSelection) {
                ClassSelectionView {
                    showClassSelection = false
                }
            }
        }
    }
}

// 1. Home Dashboard panel
struct HomeDashboardView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @Binding var showClassSelection: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top header profile
                if let char = firebaseService.currentCharacter {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LEVEL \(char.level)")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(char.selectedClass.themeColor)
                                .tracking(1)
                            
                            Text(char.username)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
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
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        
                        // Switch class gear icon
                        Button(action: { showClassSelection = true }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(Theme.textSecondary)
                                .padding(8)
                                .background(Theme.cardBackground)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
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
                    .background(Theme.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Gear Slots Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EQUIPPED SLOTS")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 16) {
                            // Slot Weapon
                            SlotCard(title: "Weapon", itemName: "Oak Bow", rarity: .rare, combatBonus: "+15 PWR", icon: "shield.fill", color: char.selectedClass.themeColor)
                            // Slot Armor
                            SlotCard(title: "Armor", itemName: "Leather Jerkin", rarity: .common, combatBonus: "+10 PWR", icon: "tshirt.fill", color: Theme.textMuted)
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
    
    var body: some View {
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
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
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
        .background(Theme.cardBackground)
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

struct MainHubView_Previews: PreviewProvider {
    static var previews: some View {
        MainHubView()
    }
}
