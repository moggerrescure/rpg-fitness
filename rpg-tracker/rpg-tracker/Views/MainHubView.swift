import SwiftUI

struct MainHubView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @ObservedObject var multiplayerService = MultiplayerService.shared
    @State private var currentTab: Int = 0
    @State private var showClassSelection: Bool = false
    @State private var showProfile: Bool = false
    @State private var toastMessage: String? = nil
    @State private var showDungeonRun: Bool = false
    @State private var showNotifications: Bool = false
    @State private var showTeamLobby: Bool = false

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
                case 4:
                    AnimatedBackgroundView(backgroundType: .mountain)
                default:
                    AnimatedBackgroundView(backgroundType: .general)
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
                                HomeDashboardView(showClassSelection: $showClassSelection, showProfile: $showProfile, toastMessage: $toastMessage, showNotifications: $showNotifications)
                            case 1:
                                TrainingSelectionView()
                            case 2:
                                BattleArenaView()
                            case 3:
                                ClanDashboardView(currentTab: $currentTab)
                            case 4:
                                WorldBossDashboardView(currentTab: $currentTab)
                            default:
                                HomeDashboardView(showClassSelection: $showClassSelection, showProfile: $showProfile, toastMessage: $toastMessage, showNotifications: $showNotifications)
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
                
                // MARK: - Friend Duel Countdown Overlay
                if let countdown = multiplayerService.friendDuelCountdown {
                    Color.black.opacity(0.92).ignoresSafeArea()
                        .zIndex(300)
                    
                    FriendDuelCountdownOverlay(countdown: countdown)
                        .zIndex(301)
                        .transition(.opacity.combined(with: .scale))
                }
                
                // Incoming Duel Challenge Overlay
                if let duelTicket = MultiplayerService.shared.incomingDuel {
                    Color.black.opacity(0.85).ignoresSafeArea()
                        .zIndex(200)
                    
                    VStack(spacing: 24) {
                        Image(duelTicket.playerAvatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(duelTicket.playerClass.themeColor, lineWidth: 3))
                            .shadow(color: duelTicket.playerClass.themeColor, radius: 15)
                        
                        Text("\(duelTicket.playerName) challenged you to a Duel!")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Class: \(duelTicket.playerClass.rawValue) | Level: \(duelTicket.playerLevel)")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack(spacing: 20) {
                            Button("Decline") {
                                MultiplayerService.shared.declineDuel(duelTicket)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                            
                            Button("Accept!") {
                                MultiplayerService.shared.acceptDuel(duelTicket)
                                currentTab = 2 // Switch to Battle Arena tab
                            }
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 32)
                            .background(Color.green)
                            .cornerRadius(12)
                            .shadow(color: Color.green.opacity(0.5), radius: 10)
                        }
                    }
                    .padding(30)
                    .background(Theme.cardBackground)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(duelTicket.playerClass.themeColor, lineWidth: 2)
                    )
                    .padding(.horizontal, 20)
                    .zIndex(201)
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Incoming 3v3 Team Invite Overlay
                if let teamTicket = multiplayerService.incomingTeamInvite {
                    Color.black.opacity(0.85).ignoresSafeArea()
                        .zIndex(202)
                    
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(teamTicket.playerClass.themeColor.opacity(0.2))
                                .frame(width: 80, height: 80)
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 30))
                                .foregroundColor(teamTicket.playerClass.themeColor)
                        }
                        .shadow(color: teamTicket.playerClass.themeColor.opacity(0.5), radius: 15)
                        
                        VStack(spacing: 6) {
                            Text("3V3 TEAM INVITE")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(Theme.warning)
                                .tracking(3)
                            Text("\(teamTicket.playerName) wants you\non their team!")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text("\(teamTicket.playerClass.rawValue) • Level \(teamTicket.playerLevel)")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        HStack(spacing: 16) {
                            Button("Decline") {
                                withAnimation(.spring) {
                                    multiplayerService.declineTeamInvite(teamTicket)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 28)
                            .background(Color.red.opacity(0.75))
                            .cornerRadius(14)
                            
                            Button("Join Team!") {
                                multiplayerService.acceptTeamInvite(teamTicket)
                                currentTab = 1
                            }
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 28)
                            .background(Color.green)
                            .cornerRadius(14)
                            .shadow(color: Color.green.opacity(0.4), radius: 10)
                        }
                    }
                    .padding(28)
                    .background(Theme.cardBackground)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(teamTicket.playerClass.themeColor, lineWidth: 2)
                    )
                    .padding(.horizontal, 20)
                    .zIndex(203)
                    .transition(.scale.combined(with: .opacity))
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
            .sheet(isPresented: $showNotifications) {
                NotificationCenterView()
            }
            .task {
                // Try to set up listeners immediately; if character isn't loaded yet,
                // onChange below will retry when it becomes available.
                MultiplayerService.shared.listenForIncomingDuels()
                if let uid = firebaseService.currentCharacter?.id {
                    NotificationManager.shared.listenForInAppNotifications(userId: uid)
                }
            }
            .onChange(of: firebaseService.currentCharacter?.id) { newId in
                if let uid = newId {
                    NotificationManager.shared.listenForInAppNotifications(userId: uid)
                    // Re-setup incoming duel/team listeners now that we have a valid UID.
                    // This handles the timing race where character loads after .task runs.
                    MultiplayerService.shared.listenForIncomingDuels()
                } else {
                    NotificationManager.shared.stopListening()
                }
            }
            // Deep-link navigation from notification taps
            .onReceive(NotificationManager.shared.$pendingDeepLink) { link in
                guard let link = link else { return }
                switch link {
                case "duel", "arena":
                    currentTab = 2  // Battle Arena tab
                case "friends":
                    currentTab = 0  // Home tab (Friends sheet opens from there)
                default:
                    break
                }
                NotificationManager.shared.pendingDeepLink = nil
            }
            // Auto-switch to Battle Arena when friend countdown finishes
            .onChange(of: multiplayerService.friendDuelCountdown) { newVal in
                if newVal == nil && multiplayerService.activeBattle != nil {
                    withAnimation { currentTab = 2 }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowDungeonRun"))) { _ in
                showDungeonRun = true
            }
            .fullScreenCover(isPresented: $showDungeonRun) {
                DungeonRunView()
            }
        }
    }
}

// MARK: - Friend Duel Countdown Overlay
struct FriendDuelCountdownOverlay: View {
    let countdown: Int
    @State private var ringProgress: CGFloat = 1.0
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            // Crossed-swords badge
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        LinearGradient(colors: [Color.red, Color.orange],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: ringProgress)

                Image(systemName: "figure.fencing")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.orange, Color.red],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 10) {
                Text("BATTLE BEGINS IN")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(4)

                // Countdown number with glow
                ZStack {
                    Text(countdown > 0 ? "\(countdown)" : "FIGHT!")
                        .font(.system(size: countdown > 0 ? 88 : 52, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.orange, Color.red],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: Color.orange.opacity(0.6), radius: 20)
                        .shadow(color: Color.red.opacity(0.4), radius: 40)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: countdown)
                }
                .frame(height: 110)
            }

            Text("Prepare for combat!")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            pulse = true
            ringProgress = 0.0
        }
        .onChange(of: countdown) { _ in
            withAnimation(.easeInOut(duration: 0.9)) {
                ringProgress = countdown > 0 ? CGFloat(countdown) / 3.0 : 0
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
    @Binding var showNotifications: Bool
    @State private var showArmoryShop: Bool = false
    @State private var armoryInitialSlot: EquipmentSlot = .weapon
    @State private var questsAnimated: Bool = false
    @State private var showFriends: Bool = false

    private var character: Character? { firebaseService.currentCharacter }

    private var equippedWeapon: EquipmentItem? {
        guard let char = character else { return nil }
        if let id = char.equippedWeaponId { return EquipmentItem.findWeapon(by: id) }
        return EquipmentItem.starterWeapons[char.selectedClass]
    }

    private var equippedArmor: EquipmentItem? {
        guard let char = character else { return nil }
        if let id = char.equippedArmorId { return EquipmentItem.findArmor(by: id) }
        return EquipmentItem.starterArmors[char.selectedClass]
    }

    private var equippedRing: EquipmentItem? {
        guard let char = character, let id = char.equippedRingId else { return nil }
        return EquipmentItem.findRing(by: id)
    }

    private var equippedAmulet: EquipmentItem? {
        guard let char = character, let id = char.equippedAmuletId else { return nil }
        return EquipmentItem.findAmulet(by: id)
    }

    private var dailyQuests: [DailyQuest] {
        DailyQuestEngine.dailyQuests()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if let char = character {
                    DashboardNavBar(
                        char: char,
                        showProfile: $showProfile,
                        showNotifications: $showNotifications,
                        onShop: { showArmoryShop = true },
                        onSwitchClass: { showClassSelection = true },
                        onFriends: { showFriends = true }
                    )

                    HeroCard(
                        char: char,
                        equippedWeapon: equippedWeapon,
                        equippedArmor: equippedArmor,
                        equippedRing: equippedRing,
                        equippedAmulet: equippedAmulet,
                        onWeaponTap:  { armoryInitialSlot = .weapon;  showArmoryShop = true },
                        onArmorTap:   { armoryInitialSlot = .armor;   showArmoryShop = true },
                        onRingTap:    { armoryInitialSlot = .ring;    showArmoryShop = true },
                        onAmuletTap:  { armoryInitialSlot = .amulet;  showArmoryShop = true }
                    )
                    .padding(.horizontal)
                    .padding(.top, 14)

                    ClassSwitcherPanel(toastMessage: $toastMessage)
                        .padding(.top, 14)

                    DailyQuestsSection(
                        quests: dailyQuests,
                        character: char,
                        animated: questsAnimated
                    )
                    .padding(.top, 18)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation { questsAnimated = true }
                        }
                    }

                    DungeonEntryCard(char: char)
                        .padding(.horizontal)
                        .padding(.top, 18)

                    Color.clear.frame(height: 110)
                }
            }
        }
        .sheet(isPresented: $showArmoryShop) {
            ArmoryShopView(initialSlot: armoryInitialSlot)
        }
        .sheet(isPresented: $showFriends) {
            FriendsView()
                .environmentObject(FirebaseService.shared)
                .environmentObject(MultiplayerService.shared)
        }
    }
}

// MARK: - Dashboard Nav Bar
struct DashboardNavBar: View {
    let char: Character
    @Binding var showProfile: Bool
    @Binding var showNotifications: Bool
    let onShop: () -> Void
    let onSwitchClass: () -> Void
    let onFriends: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: { showProfile = true }) {
                HStack(spacing: 11) {
                    ZStack {
                        Circle()
                            .fill(char.selectedClass.themeColor.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(char.selectedClass.themeColor)
                    }
                    .overlay(Circle().stroke(char.selectedClass.themeColor.opacity(0.6), lineWidth: 1.5))
                    .glow(color: char.selectedClass.themeColor.opacity(0.3), radius: 6)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("LVL \(char.level) · \(char.selectedClass.rawValue.uppercased())")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(char.selectedClass.themeColor)
                            .tracking(0.8)
                        Text(char.username)
                            .font(.system(.callout, design: .default))
                            .fontWeight(.black)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .buttonStyle(TactileButtonStyle())

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "centsign.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.healerColor)
                Text("\(char.gold)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Theme.cardBackground.opacity(0.9))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.healerColor.opacity(0.25), lineWidth: 1))

            navIconButton(systemName: "bell.fill", color: Theme.textPrimary, action: { showNotifications = true })
            navIconButton(systemName: "person.2.fill", color: Theme.primary, action: { onFriends() })
            navIconButton(systemName: "cart.fill", color: Theme.warning, action: { onShop() })
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func navIconButton(systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(Theme.cardBackground.opacity(0.9))
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(TactileButtonStyle())
    }
}

// MARK: - Hero Card
struct HeroCard: View {
    let char: Character
    let equippedWeapon: EquipmentItem?
    let equippedArmor: EquipmentItem?
    let equippedRing: EquipmentItem?
    let equippedAmulet: EquipmentItem?
    let onWeaponTap: () -> Void
    let onArmorTap: () -> Void
    let onRingTap: () -> Void
    let onAmuletTap: () -> Void

    private var xpProgress: CGFloat {
        let cap = max(1, char.xpForNextLevel)
        return min(CGFloat(char.xp) / CGFloat(cap), 1.0)
    }
    private var energyProgress: CGFloat {
        guard char.maxEnergy > 0 else { return 0 }
        return min(CGFloat(char.energy) / CGFloat(char.maxEnergy), 1.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 18) {
                // Avatar with energy ring
                ZStack {
                    Circle()
                        .stroke(Theme.secondaryCard, lineWidth: 4)
                        .frame(width: 84, height: 84)
                    Circle()
                        .trim(from: 0, to: energyProgress)
                        .stroke(
                            AngularGradient(
                                colors: [char.selectedClass.themeColor, char.selectedClass.themeColor.opacity(0.4)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 84, height: 84)
                        .rotationEffect(.degrees(-90))
                        .glow(color: char.selectedClass.themeColor.opacity(0.5), radius: 5)

                    Circle()
                        .fill(char.selectedClass.themeColor.opacity(0.14))
                        .frame(width: 72, height: 72)
                    Image(systemName: heroClassIcon(char.selectedClass))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(char.selectedClass.themeColor)
                        .glow(color: char.selectedClass.themeColor.opacity(0.5), radius: 6)
                }

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("COMBAT POWER")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                            .tracking(1)
                        Text("\(char.combatPower)")
                            .font(.system(size: 30, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .glow(color: char.selectedClass.themeColor.opacity(0.3), radius: 5)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("XP")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            Text("\(char.xp) / \(char.xpForNextLevel)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Theme.secondaryCard)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [char.selectedClass.themeColor, char.selectedClass.themeColor.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: xpProgress * geo.size.width)
                                    .glow(color: char.selectedClass.themeColor.opacity(0.4), radius: 3)
                            }
                        }
                        .frame(height: 6)

                        HStack(spacing: 5) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(char.selectedClass.themeColor)
                            Text("ENERGY \(char.energy)/\(char.maxEnergy)")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundColor(char.selectedClass.themeColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(char.selectedClass.themeColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(18)

            Divider().background(Theme.border).padding(.horizontal, 14)

            // Gear strip
            HStack(spacing: 0) {
                GearSlotStrip(slot: "WEAPON", item: equippedWeapon, fallbackIcon: "bolt.slash.fill",
                              accentColor: char.selectedClass.themeColor, action: onWeaponTap)
                    .frame(maxWidth: .infinity)

                Rectangle().fill(Theme.border).frame(width: 1, height: 52)

                GearSlotStrip(slot: "ARMOR", item: equippedArmor, fallbackIcon: "tshirt.fill",
                              accentColor: Theme.textMuted, action: onArmorTap)
                    .frame(maxWidth: .infinity)

                Rectangle().fill(Theme.border).frame(width: 1, height: 52)

                GearSlotStrip(slot: "RING", item: equippedRing, fallbackIcon: "circle.dotted",
                              accentColor: equippedRing != nil ? equippedRing!.rarity.color : Theme.textMuted,
                              action: onRingTap)
                    .frame(maxWidth: .infinity)

                Rectangle().fill(Theme.border).frame(width: 1, height: 52)

                GearSlotStrip(slot: "AMULET", item: equippedAmulet, fallbackIcon: "sparkles",
                              accentColor: equippedAmulet != nil ? equippedAmulet!.rarity.color : Theme.textMuted,
                              action: onAmuletTap)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
        }
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.cardBackground.opacity(0.9)))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(LinearGradient(
                    colors: [char.selectedClass.themeColor.opacity(0.45), Color.clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ), lineWidth: 1.5)
        )
        .shadow(color: char.selectedClass.themeColor.opacity(0.12), radius: 16, y: 6)
    }

    private func heroClassIcon(_ c: CharacterClass) -> String {
        switch c {
        case .archer:    return "arrow.up.right.circle.fill"
        case .mage:      return "wand.and.stars"
        case .swordsman: return "shield.fill"
        case .healer:    return "cross.case.fill"
        }
    }
}

// MARK: - Gear Slot Strip
struct GearSlotStrip: View {
    let slot: String
    let item: EquipmentItem?
    let fallbackIcon: String
    let accentColor: Color
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    // Pulsing ring for empty slot
                    if item == nil {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(accentColor.opacity(isPulsing ? 0.5 : 0.15), lineWidth: isPulsing ? 2 : 1)
                            .frame(width: 40, height: 40)
                            .scaleEffect(isPulsing ? 1.08 : 1.0)
                            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulsing)
                    }

                    RoundedRectangle(cornerRadius: 10)
                        .fill((item?.rarity.color ?? accentColor).opacity(item != nil ? 0.18 : 0.07))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    item?.rarity.color ?? accentColor,
                                    lineWidth: item != nil ? 1.5 : 0.5
                                )
                                .opacity(item != nil ? 0.6 : 0)
                        )

                    if item != nil {
                        Image(systemName: item!.getIconName())
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(item!.rarity.color)
                    } else {
                        // "+" icon for empty slots
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(accentColor.opacity(0.4))
                    }
                }
                .glow(color: (item?.rarity.color ?? Color.clear).opacity(0.35), radius: 5)

                Text(slot)
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundColor(item != nil ? Theme.textSecondary : Theme.textMuted)

                if let item = item {
                    Text(item.name)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(item.rarity.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("EMPTY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(accentColor.opacity(0.4))
                }
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(TactileButtonStyle())
        .onAppear {
            if item == nil {
                isPulsing = true
            }
        }
        .onChange(of: item?.id) { _, _ in
            isPulsing = (item == nil)
        }
    }
}

// MARK: - Daily Quests Section
struct DailyQuestsSection: View {
    let quests: [DailyQuest]
    let character: Character
    let animated: Bool

    private var resetLabel: String {
        let secs = Int(DailyQuestEngine.secondsUntilReset)
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return "\(h)h \(m)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "target")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.warning)
                    Text("DAILY MISSIONS")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                        .tracking(1)
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                    Text("RESETS IN \(resetLabel)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.secondaryCard.opacity(0.6))
                .cornerRadius(8)
            }
            .padding(.horizontal)

            VStack(spacing: 10) {
                ForEach(Array(quests.enumerated()), id: \.element.id) { idx, quest in
                    let progress = DailyQuestEngine.progress(for: quest, character: character)
                    DailyQuestCard(quest: quest, progress: progress, index: idx, animated: animated)
                }
            }
            .padding(.horizontal)

            let completedCount = quests.filter {
                DailyQuestEngine.progress(for: $0, character: character) >= 1.0
            }.count
            if completedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.success)
                    Text("\(completedCount)/\(quests.count) COMPLETED TODAY")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(Theme.success)
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Daily Quest Card
struct DailyQuestCard: View {
    let quest: DailyQuest
    let progress: Double
    let index: Int
    let animated: Bool

    private var isComplete: Bool { progress >= 1.0 }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(quest.iconColor.opacity(isComplete ? 0.22 : 0.13))
                    .frame(width: 46, height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(quest.iconColor.opacity(isComplete ? 0.6 : 0.25), lineWidth: 1.5)
                    )
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(quest.iconColor)
                        .glow(color: quest.iconColor.opacity(0.5), radius: 5)
                } else {
                    Image(systemName: quest.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(quest.iconColor)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(quest.title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(isComplete ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(isComplete, color: Theme.textMuted)
                    .lineLimit(1)

                Text(quest.description)
                    .font(.system(size: 10, design: .default))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Theme.secondaryCard)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(
                                colors: [quest.iconColor, quest.iconColor.opacity(0.6)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: animated ? min(CGFloat(progress), 1.0) * geo.size.width : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(Double(index) * 0.12), value: animated)
                            .glow(color: quest.iconColor.opacity(0.4), radius: 3)
                    }
                }
                .frame(height: 4)
            }

            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(quest.xpReward) XP")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Theme.primary.opacity(0.12))
                    .cornerRadius(6)
                Text("+\(quest.goldReward)g")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(Theme.healerColor)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Theme.healerColor.opacity(0.12))
                    .cornerRadius(6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isComplete ? quest.iconColor.opacity(0.06) : Theme.cardBackground.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isComplete ? quest.iconColor.opacity(0.3) : Theme.border, lineWidth: 1)
        )
        .shadow(color: isComplete ? quest.iconColor.opacity(0.08) : Color.black.opacity(0.07), radius: 8, y: 3)
        .scaleEffect(animated ? 1 : 0.94)
        .opacity(animated ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(Double(index) * 0.08), value: animated)
    }
}

// MARK: - Dungeon Entry Card
struct DungeonEntryCard: View {
    let char: Character
    @State private var pulse = false

    var body: some View {
        Button(action: {
            NotificationCenter.default.post(name: NSNotification.Name("ShowDungeonRun"), object: nil)
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.danger.opacity(0.18))
                        .frame(width: 52, height: 52)
                        .scaleEffect(pulse ? 1.18 : 1.0)
                        .opacity(pulse ? 0.3 : 0.18)
                        .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: pulse)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.danger)
                        .glow(color: Theme.danger.opacity(0.6), radius: 8)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("DUNGEON RUN")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(0.5)
                    Text("3 waves · Endless combat · Loot drops")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(
                LinearGradient(
                    colors: [Color(hex: "9B1C1C"), Color(hex: "7F1D1D"), Color(hex: "450A0A")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.danger.opacity(0.4), lineWidth: 1.5))
            .shadow(color: Theme.danger.opacity(0.35), radius: 12, y: 5)
        }
        .buttonStyle(TactileButtonStyle())
        .onAppear { pulse = true }
    }
}

// MARK: - SlotCard (legacy compat)
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
                    .foregroundColor(Theme.textSecondary).tracking(1)
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.12)).frame(width: 52, height: 52)
                    Image(systemName: icon).font(.title3).foregroundColor(color)
                }
                .glow(color: color.opacity(0.35), radius: 6)
                VStack(spacing: 2) {
                    Text(itemName).font(.system(.caption)).fontWeight(.black).foregroundColor(Theme.textPrimary).lineLimit(1)
                    Text(combatBonus).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(Theme.success)
                }
            }
            .padding(.vertical, 16).padding(.horizontal, 10).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LinearGradient(colors: [color.opacity(0.35), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(TactileButtonStyle())
    }
}

// MARK: - QuestRow (legacy compat)
struct QuestRow: View {
    let title: String
    let progress: String
    let completed: Bool
    let xpReward: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(completed ? Theme.success.opacity(0.15) : Theme.secondaryCard).frame(width: 28, height: 28)
                Image(systemName: completed ? "checkmark" : "circle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(completed ? Theme.success : Theme.textSecondary)
            }
            .glow(color: completed ? Theme.success.opacity(0.3) : .clear, radius: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(completed ? Theme.textSecondary : Theme.textPrimary).lineLimit(2)
                Text(xpReward).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(Theme.success)
            }
            Spacer()
            Text(progress)
                .font(.system(.caption, design: .monospaced)).foregroundColor(completed ? Theme.success : Theme.textSecondary).fontWeight(.bold)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(completed ? Theme.success.opacity(0.1) : Theme.secondaryCard.opacity(0.5)).cornerRadius(6)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground.opacity(0.8)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(completed ? Theme.success.opacity(0.3) : Theme.border, lineWidth: 1))
    }
}

// Custom Bottom Nav controller bar
struct CustomBottomNavBar: View {
    @Binding var currentTab: Int
    let activeColor: Color
    
    var body: some View {
        HStack {
            NavBarItem(icon: "house.fill", label: "HOME", tab: 0, currentTab: $currentTab, color: activeColor)
            Spacer()
            NavBarItem(icon: "figure.cross.training", label: "TRAIN", tab: 1, currentTab: $currentTab, color: activeColor)
            Spacer()
            NavBarItem(icon: "trophy.fill", label: "ARENA", tab: 2, currentTab: $currentTab, color: activeColor)
            Spacer()
            NavBarItem(icon: "shield.lefthalf.filled", label: "CLAN", tab: 3, currentTab: $currentTab, color: activeColor)
            Spacer()
            NavBarItem(icon: "flame.fill", label: "RAIDS", tab: 4, currentTab: $currentTab, color: activeColor)
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
