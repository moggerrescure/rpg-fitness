import SwiftUI

enum BattleArenaSheetType: Identifiable, Equatable {
    case generalCameraTracker
    case storyStagePrep(stage: Int)
    case storyCameraTracker(exerciseClass: CharacterClass, bossMaxHP: Int, damagePerRep: Int, bossName: String?, bossImage: String?)
    case pvpInviteFriends
    
    var id: String {
        switch self {
        case .generalCameraTracker:
            return "generalCameraTracker"
        case .storyStagePrep(let stage):
            return "storyStagePrep_\(stage)"
        case .storyCameraTracker(let cls, let hp, let dmg, let name, _):
            return "storyCameraTracker_\(cls.rawValue)_\(hp)_\(dmg)_\(name ?? "")"
        case .pvpInviteFriends:
            return "pvpInviteFriends"
        }
    }
    
    static func == (lhs: BattleArenaSheetType, rhs: BattleArenaSheetType) -> Bool {
        lhs.id == rhs.id
    }
}

enum StorySetupStep: Equatable {
    case warpAnimation    // github-like warp animation
    case activeMap        // actual map view
}

struct BattleArenaView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = BattleVM()
    @State private var selectedTab: Int = 0 // 0: Arena, 1: 1v1 Leaderboards
    @State private var isInLobby: Bool = false
    @State private var showInviteSheet: Bool = false
    @State private var showMatchmakingClassPicker: Bool = false
    @State private var showBossRaid: Bool = false
    var initialPvPType: BattleType? = nil
    
    // Story mode state extensions
    @State private var isStoryModeActive: Bool = false
    @State private var isStoryCoop: Bool = false
    @State private var storyCoopFriend: String? = nil
    @State private var selectedStoryStage: Int? = nil
    @State private var activeSheet: BattleArenaSheetType? = nil
    @State private var storySetupStep: StorySetupStep? = nil
    @State private var selectedStoryExerciseClass: CharacterClass? = nil
    @State private var selectedStoryTargetReps: Int = 0
    @State private var selectedStoryBossMaxHP: Int = 0
    @State private var selectedStoryDamagePerRep: Int = 0
    @State private var showStoryWinOverlay: Bool = false
    
    var body: some View {
        ZStack {
            if selectedTab == 1 {
                PvPLeaderboardView()
            } else {
                ZStack {
                    Color.clear
                        .ignoresSafeArea()
                    
                    if viewModel.isSearching || viewModel.activeBattle != nil {
                        ZStack {
                            if viewModel.isSearching {
                                // Searching screen uses .forest background
                                MatchmakingQueueView(cancelAction: viewModel.cancelQueue)
                            } else if let battle = viewModel.activeBattle {
                                CombatArenaView(battle: battle, viewModel: viewModel)
                            }
                        }
                        .toolbar(.hidden, for: .tabBar)
                    } else if MultiplayerService.shared.isInTeamLobby {
                        // New direct 3v3 flow: show team lobby with slots + countdown
                        TeamLobbyView(onBattleStarted: { })
                            .environmentObject(MultiplayerService.shared)
                            .environmentObject(FirebaseService.shared)
                    } else if isInLobby {
                        BattleArenaTeamLobbyView(viewModel: viewModel, backAction: {
                            isInLobby = false
                            MultiplayerService.shared.leaveMatch()
                            viewModel.selectedPvPType = .duel1v1
                        }, inviteAction: {
                            showInviteSheet = true
                        }, searchAction: {
                            showMatchmakingClassPicker = true
                        })
                    } else if storySetupStep == .warpAnimation {
                        WarpTransitionView {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                isStoryModeActive = true
                                storySetupStep = .activeMap
                            }
                        }
                    } else if isStoryModeActive {
                        StoryMapView(
                            isCoop: isStoryCoop,
                            coopFriend: storyCoopFriend,
                            onBack: {
                                withAnimation {
                                    isStoryModeActive = false
                                    storySetupStep = nil
                                }
                            },
                            onSelectStage: { stage in
                                selectedStoryStage = stage
                                activeSheet = .storyStagePrep(stage: stage)
                            }
                        )
                    } else {
                        // Selector view (uses .mountain background as requested)
                        ZStack {
                            AnimatedBackgroundView(backgroundType: .arena)
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()
                            
                            PvPModeSelectorView(
                                select1v1: {
                                    viewModel.selectedPvPType = .duel1v1
                                    showMatchmakingClassPicker = true
                                },
                                select3v3: {
                                    viewModel.selectedPvPType = .team3v3
                                    viewModel.invitedFriends.removeAll()
                                    showInviteSheet = true
                                },
                                selectStory: {
                                    isStoryCoop = false
                                    storyCoopFriend = nil
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        storySetupStep = .warpAnimation
                                    }
                                },
                                selectBossRaid: {
                                    showBossRaid = true
                                }
                            )
                        }
                    }
                }
                .overlay(
                    Group {
                        if viewModel.duelFinished {
                            if viewModel.selectedPvPType == .bossRaid {
                                BossRaidResultOverlay(
                                    winnerTitle: viewModel.winnerName,
                                    closeAction: viewModel.endMatch
                                )
                            } else {
                                DuelResultOverlay(winnerTitle: viewModel.winnerName, closeAction: viewModel.endMatch)
                            }
                        }
                        if showStoryWinOverlay {
                            StoryWinOverlay(stage: selectedStoryStage ?? 1, closeAction: {
                                showStoryWinOverlay = false
                            })
                        }
                    }
                )
            }
            
            // Header Segment Control (Hidden during active combat/searching/story mode/setup step)
            if viewModel.activeBattle == nil && !viewModel.isSearching && !isStoryModeActive && storySetupStep == nil {
                VStack {
                    PillSegmentPicker(
                        selection: $selectedTab,
                        items: ["ARENA", "1V1 LEADERBOARD"],
                        accentColor: FirebaseService.shared.currentCharacter?.selectedClass.themeColor ?? Theme.primary
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $showBossRaid) {
            BossRaidView()
        }
        .fullScreenCover(item: $activeSheet) { sheet in
            switch sheet {
            case .generalCameraTracker:
                CameraTrackingView(selectedClass: viewModel.currentClass)
            case .storyStagePrep(let stage):
                StoryStagePrepView(
                    stage: stage,
                    isCoop: isStoryCoop,
                    coopFriend: storyCoopFriend,
                    onStartWorkout: { exerciseClass, bossHP, repDMG in
                        selectedStoryExerciseClass = exerciseClass
                        selectedStoryBossMaxHP = bossHP
                        selectedStoryDamagePerRep = repDMG
                        activeSheet = nil
                        
                        let bName: String
                        let bImg: String
                        if stage == 10 {
                            bName = "Gorgon's Behemoth"
                            bImg = "boss_gorgon_behemoth"
                        } else if stage == 20 {
                            bName = "Dark Lord"
                            bImg = "boss_dark_lord"
                        } else if stage == 30 {
                            bName = "Ice Colossus"
                            bImg = "boss_ice_colossus"
                        } else if stage == 40 {
                            bName = "Volcanic Demon"
                            bImg = "boss_volcanic_peak"
                        } else {
                            bName = "Stage \(stage) Boss"
                            bImg = "boss_gorgon_behemoth"
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            activeSheet = .storyCameraTracker(exerciseClass: exerciseClass, bossMaxHP: bossHP, damagePerRep: repDMG, bossName: bName, bossImage: bImg)
                        }
                    }
                )
            case .storyCameraTracker(let exerciseClass, let bossMaxHP, let damagePerRep, let bossName, let bossImage):
                CameraTrackingView(
                    selectedClass: exerciseClass,
                    bossMaxHP: bossMaxHP,
                    damagePerRep: damagePerRep,
                    bossName: bossName,
                    bossImage: bossImage,
                    onComplete: { repsCompleted in
                        activeSheet = nil
                        handleStoryStageWin()
                    }
                )
            case .pvpInviteFriends:
                InviteFriendsSheet(viewModel: viewModel)
                    .environmentObject(MultiplayerService.shared)
                    .environmentObject(FirebaseService.shared)
            }
        }
        .sheet(isPresented: $showMatchmakingClassPicker) {
            MatchmakingClassPickerSheet(onSelected: { chosenClass in
                showMatchmakingClassPicker = false
                if var char = FirebaseService.shared.currentCharacter {
                    char.selectedClass = chosenClass
                    FirebaseService.shared.syncCharacter(char)
                }
                viewModel.startQueue()
            }, accentColor: viewModel.currentClass.themeColor)
        }
        .onChange(of: viewModel.showCameraTracker) { _, newValue in
            if newValue {
                activeSheet = .generalCameraTracker
            } else if activeSheet == .generalCameraTracker {
                activeSheet = nil
            }
        }
        .onChange(of: showInviteSheet) { _, newValue in
            if newValue {
                activeSheet = .pvpInviteFriends
            } else if activeSheet == .pvpInviteFriends {
                activeSheet = nil
            }
        }
        .onChange(of: activeSheet) { _, newValue in
            if newValue == nil {
                if showInviteSheet {
                    showInviteSheet = false
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                if viewModel.activeBattle != nil {
                    // Surrender the match if app goes to background
                    MultiplayerService.shared.surrenderMatch()
                } else if viewModel.isSearching {
                    // Just cancel queue if we are searching
                    viewModel.cancelQueue()
                }
            }
        }
        .navigationTitle("ARENA & ARENAS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if initialPvPType != nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
        .onChange(of: viewModel.activeBattle) { oldBattle, newBattle in
            if oldBattle != nil && newBattle == nil && initialPvPType != nil {
                dismiss()
            }
        }
        .onChange(of: viewModel.isSearching) { oldSearching, newSearching in
            if oldSearching && !newSearching && viewModel.activeBattle == nil && initialPvPType != nil {
                dismiss()
            }
        }
        .onAppear {
            if let type = initialPvPType {
                viewModel.selectedPvPType = type
                if type == .bossRaid {
                    showBossRaid = true
                } else if type == .worldBoss {
                    viewModel.startQueue(type: .worldBoss)
                } else {
                    viewModel.startQueue()
                }
            }
        }
    }
    
    private func handleStoryStageWin() {
        guard let stage = selectedStoryStage, var char = FirebaseService.shared.currentCharacter else { return }
        
        char.advanceStoryStage(completedStage: stage)
        
        let xpReward = stage * 50
        let goldReward = stage * 10
        _ = char.addXP(xpReward)
        char.gold += goldReward
        
        FirebaseService.shared.syncCharacter(char)
        showStoryWinOverlay = true
    }
}


// 1. PvP Mode selector (Beautiful Hero Cards Grid)
struct PvPModeSelectorView: View {
    let select1v1: () -> Void
    let select3v3: () -> Void
    let selectStory: () -> Void
    let selectBossRaid: () -> Void

    @State private var appear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Spacer for segment control
                Color.clear.frame(height: 76)

                // ── HEADER ─────────────────────────────────────────
                VStack(spacing: 12) {
                    // Decorative badge
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.warning)
                        Text("CHOOSE YOUR BATTLE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.warning)
                            .tracking(2)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.warning)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.warning.opacity(0.1))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.warning.opacity(0.3), lineWidth: 1))

                    Text("SELECT BATTLEGROUND")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(1)
                        .multilineTextAlignment(.center)
                        .glow(color: Theme.warning.opacity(0.2), radius: 8)

                    Text("Every rep counts. Every match matters.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 22)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)

                // ── 2×2 HERO CARD GRID ─────────────────────────────
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ArenaHeroCard(
                        title: "STORY\nCAMPAIGN",
                        subtitle: "20 Islands · Epic Bosses",
                        detail: "CO-OP / SOLO",
                        icon: "map.fill",
                        gradient: [Color(hex: "1A4D2E"), Color(hex: "071C10")],
                        accentColor: Color(hex: "34D399"),
                        badge: "CO-OP",
                        badgeColor: Color(hex: "34D399"),
                        animDelay: 0.08,
                        appear: appear,
                        action: selectStory
                    )
                    ArenaHeroCard(
                        title: "1V1\nSPEED DUEL",
                        subtitle: "60s Exercise Race",
                        detail: "PVP · RANKED",
                        icon: "figure.martial.arts",
                        gradient: [Color(hex: "7F1D1D"), Color(hex: "2D0A0A")],
                        accentColor: Color(hex: "F87171"),
                        badge: "PVP",
                        badgeColor: Color(hex: "F87171"),
                        animDelay: 0.14,
                        appear: appear,
                        action: select1v1
                    )
                    ArenaHeroCard(
                        title: "3V3\nCO-OP",
                        subtitle: "Team Attacks & Heals",
                        detail: "INVITE FRIENDS",
                        icon: "person.3.fill",
                        gradient: [Color(hex: "1E3A5F"), Color(hex: "071424")],
                        accentColor: Color(hex: "60A5FA"),
                        badge: "TEAM",
                        badgeColor: Color(hex: "60A5FA"),
                        animDelay: 0.20,
                        appear: appear,
                        action: select3v3
                    )
                    ArenaHeroCard(
                        title: "BOSS\nRAID",
                        subtitle: "Reps = Direct Damage",
                        detail: "WORLD BOSS",
                        icon: "flame.fill",
                        gradient: [Color(hex: "7C2D12"), Color(hex: "2A0D04")],
                        accentColor: Color(hex: "FB923C"),
                        badge: "RAID",
                        badgeColor: Color(hex: "FB923C"),
                        animDelay: 0.26,
                        appear: appear,
                        action: selectBossRaid
                    )
                }
                .padding(.horizontal, 16)

                Color.clear.frame(height: 110)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}

// ── Arena Hero Card ────────────────────────────────────────────────────────

private struct ArenaHeroCard: View {
    let title: String
    let subtitle: String
    let detail: String
    let icon: String
    let gradient: [Color]
    let accentColor: Color
    let badge: String
    let badgeColor: Color
    let animDelay: Double
    let appear: Bool
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Base gradient
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

                // Top-right accent glow
                RadialGradient(
                    colors: [accentColor.opacity(0.3), Color.clear],
                    center: UnitPoint(x: 0.85, y: 0.15),
                    startRadius: 0, endRadius: 90
                )

                // Noise/texture overlay
                Color.white.opacity(0.02)

                VStack(alignment: .leading, spacing: 0) {
                    // Top row: badge + arrow
                    HStack(alignment: .top) {
                        Text(badge)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(badgeColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(badgeColor.opacity(0.15))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(badgeColor.opacity(0.4), lineWidth: 1))

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accentColor.opacity(0.5))
                    }

                    Spacer()

                    // Center: Big icon
                    Image(systemName: icon)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(accentColor)
                        .glow(color: accentColor.opacity(0.6), radius: 12)
                        .padding(.bottom, 12)

                    // Title
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Subtitle
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                        .padding(.top, 3)

                    // Detail line
                    HStack(spacing: 4) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 5, height: 5)
                        Text(detail)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor.opacity(0.8))
                    }
                    .padding(.top, 5)
                }
                .padding(16)
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        LinearGradient(
                            colors: [accentColor.opacity(pressed ? 0.8 : 0.4), accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: accentColor.opacity(pressed ? 0.35 : 0.18), radius: pressed ? 16 : 10, x: 0, y: pressed ? 4 : 6)
            .scaleEffect(pressed ? 0.96 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 50, pressing: { isPressing in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                pressed = isPressing
            }
        }, perform: {})
        .opacity(appear ? 1 : 0)
        .scaleEffect(appear ? 1 : 0.88)
        .animation(.spring(response: 0.5, dampingFraction: 0.72).delay(animDelay), value: appear)
    }
}

// 2. 3v3 Party/Lobby screen
struct BattleArenaTeamLobbyView: View {
    @ObservedObject var viewModel: BattleVM
    let backAction: () -> Void
    let inviteAction: () -> Void
    let searchAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)
            
            // Header
            HStack {
                Button(action: backAction) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Theme.cardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(TactileButtonStyle())
                
                Spacer()
                
                Text("CO-OP LOBBY (3V3)")
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.black)
                    .foregroundColor(Theme.textPrimary)
                    .tracking(1)
                
                Spacer()
                Image(systemName: "chevron.left").opacity(0).padding(10) // balance
            }
            .padding(.horizontal)
            
            Text("Invite friends to form a 3-player team")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, -10)
            
            // Slots List
            VStack(spacing: 16) {
                // Slot 1: You
                HStack(spacing: 12) {
                    Circle()
                        .fill(viewModel.currentClass.themeColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(viewModel.currentClass.themeColor)
                        )
                        .glow(color: viewModel.currentClass.themeColor.opacity(0.35), radius: 5)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You (Leader)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                        Text(viewModel.currentClass.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(viewModel.currentClass.themeColor)
                    }
                    Spacer()
                }
                .padding()
                .background(Theme.cardBackground.opacity(0.85))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(viewModel.currentClass.themeColor.opacity(0.5), lineWidth: 1.5)
                )
                
                // Slot 2
                LobbySlotRow(friendName: viewModel.invitedFriends.first, inviteAction: inviteAction, removeAction: {
                    if let first = viewModel.invitedFriends.first {
                        viewModel.removeFriend(first)
                    }
                })
                
                // Slot 3
                LobbySlotRow(friendName: viewModel.invitedFriends.count > 1 ? viewModel.invitedFriends[1] : nil, inviteAction: inviteAction, removeAction: {
                    if viewModel.invitedFriends.count > 1 {
                        viewModel.removeFriend(viewModel.invitedFriends[1])
                    }
                })
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Search Match button
            Button(action: searchAction) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                    Text("START TEAM BATTLE")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.black)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.primary)
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: Theme.primary.opacity(0.35), radius: 10, y: 5)
            }
            .buttonStyle(TactileButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
    }
}

struct LobbySlotRow: View {
    let friendName: String?
    let inviteAction: () -> Void
    let removeAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if let name = friendName {
                let friendClass: CharacterClass = name == "AquaHealer" ? .healer : .mage
                Circle()
                    .fill(friendClass.themeColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(friendClass.themeColor)
                    )
                    .glow(color: friendClass.themeColor.opacity(0.3), radius: 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                    Text(friendClass.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(friendClass.themeColor)
                }
                
                Spacer()
                
                Button(action: removeAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(Theme.danger.opacity(0.8))
                }
                .buttonStyle(TactileButtonStyle())
            } else {
                Button(action: inviteAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(Theme.textSecondary)
                        Text("INVITE FRIEND")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(TactileButtonStyle())
            }
        }
        .padding()
        .background(Theme.cardBackground.opacity(0.65))
        .cornerRadius(16)
        .overlay(
            Group {
                if friendName == nil {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .miter, miterLimit: 10, dash: [6, 6], dashPhase: 0))
                        .foregroundColor(Theme.border)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.border, lineWidth: 1)
                }
            }
        )
    }
}

// 3. Friend Invitation Modal bottom sheet
struct InviteFriendsSheet: View {
    @ObservedObject var viewModel: BattleVM
    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendsVM = FriendsVM()
    @State private var showTeamLobby = false
    @EnvironmentObject var multiplayerService: MultiplayerService
    
    var body: some View {
        ZStack {
            AnimatedBackgroundView(backgroundType: .tavern)
            Color.black.opacity(0.45).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { 
                        multiplayerService.leaveMatch()
                        dismiss() 
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.bold())
                            .foregroundStyle(Theme.textSecondary)
                            .padding(10)
                            .background(Theme.cardBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(TactileButtonStyle())
                    Spacer()
                    Text("INVITE TO 3V3")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.black)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    // Balance
                    Image(systemName: "xmark").opacity(0).padding(10)
                }
                .padding()
                
                if friendsVM.isLoading {
                    Spacer()
                    ProgressView().tint(Theme.primary)
                    Spacer()
                } else if friendsVM.friends.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.textSecondary.opacity(0.3))
                        Text("No friends yet.")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary.opacity(0.5))
                        Text("Add friends first from the Friends tab.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(friendsVM.friends) { friend in
                                let slotMatch = multiplayerService.teamLobbySlots.first(where: { 
                                    if case .invited(let uid, _) = $0.state, uid == friend.id { return true }
                                    if case .joined(let uid, _, _) = $0.state, uid == friend.id { return true }
                                    return false
                                })
                                let isInvited = slotMatch != nil
                                let hasJoined = {
                                    if let slot = slotMatch, case .joined = slot.state { return true }
                                    return false
                                }()
                                
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(friend.selectedClass.themeColor.opacity(0.15))
                                            .frame(width: 46, height: 46)
                                        Image(systemName: "person.fill")
                                            .font(.title3)
                                            .foregroundStyle(friend.selectedClass.themeColor)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(friend.username)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(Theme.textPrimary)
                                        Text("Lv.\(friend.level) • \(friend.selectedClass.rawValue)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(friend.selectedClass.themeColor)
                                    }
                                    Spacer()
                                    Button {
                                        if !isInvited {
                                            multiplayerService.sendTeamInvite(uid: friend.id)
                                        }
                                    } label: {
                                        Text(hasJoined ? "JOINED ✓" : (isInvited ? "INVITED ✓" : "INVITE"))
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .foregroundStyle(isInvited ? .white : Theme.primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(isInvited ? (hasJoined ? Theme.success : Theme.primary) : Theme.primary.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(isInvited)
                                }
                                .padding(14)
                                .background(isInvited ? (hasJoined ? Theme.success.opacity(0.15) : Theme.primary.opacity(0.08)) : Theme.cardBackground.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isInvited ? (hasJoined ? Theme.success.opacity(0.5) : Theme.primary.opacity(0.5)) : Theme.border, lineWidth: isInvited ? 1.5 : 1))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                
                // Start button
                let activeCount = multiplayerService.teamLobbySlots.filter { 
                    if case .bot = $0.state { return false } else { return true } 
                }.count
                
                Button {
                    dismiss()
                    multiplayerService.startTeamBattleFromLobby()
                } label: {
                    HStack {
                        Image(systemName: "person.3.fill")
                        Text(activeCount <= 1 ? "FIGHT SOLO 🤖" : "BATTLE! (\(activeCount)/3)")
                            .fontWeight(.black)
                    }
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Theme.primary, Theme.mageColor], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Theme.primary.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(TactileButtonStyle())
                .padding()
            }
        }
        .onAppear {
            if multiplayerService.teamLobbyTicketId == nil {
                multiplayerService.initTeamLobby()
            }
        }
    }
}


// 4. Radar matchmaking screen (with .forest background)
struct MatchmakingQueueView: View {
    let cancelAction: () -> Void
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Searching screen uses .arena combat background
            AnimatedBackgroundView(backgroundType: .arena)
                .ignoresSafeArea()
            
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Theme.primary.opacity(0.3), lineWidth: 2)
                        .frame(width: 240, height: 240)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - Double(pulseScale))
                    
                    Circle()
                        .stroke(Theme.primary.opacity(0.5), lineWidth: 2)
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale * 0.7)
                        .opacity(1.8 - Double(pulseScale))
                    
                    Circle()
                        .fill(Theme.cardBackground)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.fill.viewfinder")
                                .font(.largeTitle)
                                .foregroundColor(Theme.primary)
                        )
                }
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        pulseScale = 2.0
                    }
                }
                
                VStack(spacing: 12) {
                    Text("Searching for Opponents...")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .tracking(1)
                    
                    Text("Estimated wait time: ~30s")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 4)
                        
                    Text("Securing low latency server sync...")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                }
                
                Spacer()
                
                Button(action: cancelAction) {
                    Text("CANCEL MATCHMAKING")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.danger)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.danger.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.danger.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(TactileButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 120) // Raised significantly to clear the Tab Bar
            }
        }
    }
}

// 5. Combat Arena panel (Supports both 1v1 and 3v3 layout)
struct FloatingDamage: Identifiable {
    let id = UUID()
    let amount: Int
    let isCritical: Bool
    let isPlayer: Bool
    var position: CGPoint
}

struct CombatArenaView: View {
    let battle: Battle
    @ObservedObject var viewModel: BattleVM
    
    @StateObject private var cameraVM: CameraTrackingVM
    
    @State private var shakeOffset: CGFloat = 0
    @State private var combatLogCount: Int = 0
    @State private var damageNumbers: [FloatingDamage] = []
    @State private var arenaGlow = false
    // Countdown before battle becomes interactive
    @State private var countdownValue: Int = 3
    @State private var showCountdown: Bool = true
    @State private var countdownScale: CGFloat = 1.0
    @State private var countdownOpacity: Double = 1.0
    // Local ticking timer so the ring updates every second even without Firestore snapshots
    @State private var localSecondsRemaining: Int = 60
    @State private var localTimerTask: Timer? = nil
    @State private var showHitOverlay: Bool = false
    
    init(battle: Battle, viewModel: BattleVM) {
        self.battle = battle
        self.viewModel = viewModel
        
        let dmg = Int(Double(FirebaseService.shared.currentCharacter?.combatPower ?? 10) * 0.15)
        let cls = viewModel.currentClass
        
        _cameraVM = StateObject(wrappedValue: CameraTrackingVM(
            selectedClass: cls,
            targetReps: nil,
            bossMaxHP: battle.type == .bossRaid ? BattleEngine.shared.activeBoss?.maxHealth : nil,
            damagePerRep: battle.type == .bossRaid ? dmg : nil,
            isDungeonMode: false,
            onComplete: nil
        ))
    }
    
    private var localPlayer: BattlePlayer? { battle.localTeam.first }
    private var localHPPercent: Double {
        guard let p = localPlayer, p.maxHealth > 0 else { return 1.0 }
        return Double(max(0, p.health)) / Double(p.maxHealth)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {

                    // ╔══════════════════════════════╗
                    // ║     BATTLE HUD (top 50%)     ║
                    // ╚══════════════════════════════╝
                    ZStack {
                        // Dark arena background
                        LinearGradient(
                            colors: [
                                Color.black,
                                Color(red: 0.05, green: 0.04, blue: 0.12),
                                Color(red: 0.08, green: 0.03, blue: 0.08)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )

                        // Arena atmospheric glow (purple/red combat hue)
                        RadialGradient(
                            colors: [Theme.danger.opacity(arenaGlow ? 0.25 : 0.15), Color.clear],
                            center: UnitPoint(x: 0.5, y: 0.1),
                            startRadius: 0, endRadius: 250
                        )

                        VStack(spacing: 0) {
                            // ── Top nav: Battle type + Timer ─────────────────
                            HStack(spacing: 12) {
                                // Battle mode pill
                                Text(battle.type == .bossRaid ? "⚔️ BOSS RAID" : (battle.type == .duel1v1 ? "⚔️ 1V1 DUEL" : "⚔️ TEAM BATTLE"))
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color.black.opacity(0.65))
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.danger.opacity(0.4), lineWidth: 1))

                                Spacer()

                                // Countdown timer ring — driven by local timer, syncs from server on snapshots
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 3.5)
                                        .frame(width: 46, height: 46)
                                    Circle()
                                        .trim(from: 0.0, to: CGFloat(localSecondsRemaining) / 60.0)
                                        .stroke(
                                            localSecondsRemaining < 15 ? Theme.danger : Theme.success,
                                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                                        )
                                        .frame(width: 46, height: 46)
                                        .rotationEffect(.degrees(-90))
                                        .glow(color: (localSecondsRemaining < 15 ? Theme.danger : Theme.success).opacity(0.5), radius: 4)
                                    Text("\(localSecondsRemaining)")
                                        .font(.system(size: 13, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            // Push below Dynamic Island / notch — safe area top + 8pt breathing room
                            .padding(.top, geo.safeAreaInsets.top + 8)

                            Spacer()

                            // ── Central fighters display ──────────────────────
                            if battle.type == .bossRaid {
                                // Boss fight layout
                                if let boss = BattleEngine.shared.activeBoss {
                                    VStack(spacing: 8) {
                                        Text(boss.name)
                                            .font(.system(size: 14, weight: .black, design: .monospaced))
                                            .foregroundStyle(Theme.danger)
                                            .glow(color: Theme.danger.opacity(0.5), radius: 6)

                                        Group {
                                            if boss.name.contains("Gorgon") {
                                                Image("boss_gorgon_behemoth").resizable().scaledToFit()
                                            } else if boss.name.contains("Dark Lord") {
                                                Image("boss_dark_lord").resizable().scaledToFit()
                                            } else if boss.name.contains("Ice Colossus") {
                                                Image("boss_ice_colossus").resizable().scaledToFit()
                                            } else if boss.name.contains("Volcanic") {
                                                Image("boss_volcanic_peak").resizable().scaledToFit()
                                            } else {
                                                Image("boss_gorgon_behemoth").resizable().scaledToFit()
                                            }
                                        }
                                        .frame(height: geo.size.height * 0.20)
                                        .shadow(color: Theme.danger.opacity(0.4), radius: 16)

                                        // Boss HP bar
                                        VStack(spacing: 4) {
                                            HStack {
                                                Image(systemName: "heart.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(Theme.danger)
                                                Text("BOSS HP")
                                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(Theme.danger.opacity(0.8))
                                                Spacer()
                                                Text("\(boss.currentHealth) / \(boss.maxHealth)")
                                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                                    .foregroundStyle(.white)
                                            }
                                            GeometryReader { barGeo in
                                                let bossHPPct = CGFloat(boss.currentHealth) / CGFloat(boss.maxHealth)
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.65))
                                                    RoundedRectangle(cornerRadius: 5)
                                                        .fill(LinearGradient(
                                                            colors: bossHPPct < 0.3
                                                                ? [Color.red, Color.orange, Color.yellow]
                                                                : [Color.red, Theme.danger.opacity(0.7)],
                                                            startPoint: .leading, endPoint: .trailing
                                                        ))
                                                        .frame(width: max(0, bossHPPct * barGeo.size.width))
                                                        .animation(.spring(), value: boss.currentHealth)
                                                        .glow(color: Theme.danger.opacity(0.5), radius: 4)
                                                }
                                            }
                                            .frame(height: 10)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.black.opacity(0.55))
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.danger.opacity(0.3), lineWidth: 1))
                                    }
                                }
                            } else if battle.type == .duel1v1 {
                                // 1v1 Vertical Centered Opponent Fighter Layout
                                if let opponent = battle.opponentTeam.first {
                                    VStack(spacing: 12) {
                                        Spacer()
                                        
                                        // Opponent Info: Name, Class
                                        VStack(spacing: 4) {
                                            Text(opponent.name.uppercased())
                                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                                .foregroundColor(.white)
                                                .glow(color: opponent.characterClass.themeColor.opacity(0.4), radius: 5)
                                            
                                            Text(opponent.characterClass.rawValue.uppercased())
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundColor(opponent.characterClass.themeColor)
                                                .tracking(1)
                                        }
                                        
                                        // Health Bar
                                        let hpProgress = CGFloat(max(0, opponent.health)) / CGFloat(max(1, opponent.maxHealth))
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(Color.black.opacity(0.75))
                                                .frame(width: 220, height: 10)
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(opponent.characterClass.themeColor)
                                                .frame(width: 220 * hpProgress, height: 10)
                                                .glow(color: opponent.characterClass.themeColor.opacity(0.6), radius: 4)
                                        }
                                        .frame(width: 220)
                                        
                                        // Health Text
                                        Text("HP: \(max(0, opponent.health)) / \(opponent.maxHealth)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.85))
                                        
                                        // Large Opponent Avatar with Damage Flashing & Shaking
                                        ZStack {
                                            Circle()
                                                .fill(opponent.characterClass.themeColor.opacity(0.12))
                                                .frame(width: 110, height: 110)
                                                .overlay(Circle().stroke(opponent.characterClass.themeColor, lineWidth: 2))
                                                .glow(color: opponent.characterClass.themeColor.opacity(0.3), radius: 8)
                                            
                                            if let avatar = opponent.avatarName, let uiImage = loadLocalAvatar(named: avatar) {
                                                Image(platformImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 106, height: 106)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: "person.crop.circle.fill")
                                                    .font(.system(size: 90))
                                                    .foregroundColor(opponent.characterClass.themeColor)
                                            }
                                            
                                            if showHitOverlay {
                                                Circle()
                                                    .fill(Color.red.opacity(0.45))
                                                    .frame(width: 110, height: 110)
                                            }
                                        }
                                        .scaleEffect(showHitOverlay ? 1.15 : 1.0)
                                        .offset(x: showHitOverlay ? CGFloat.random(in: -8...8) : 0)
                                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: showHitOverlay)
                                        
                                        Spacer()
                                    }
                                }
                            } else {
                                // 3v3 Team layout
                                HStack(spacing: 8) {
                                    // Local team column
                                    VStack(spacing: 6) {
                                        ForEach(battle.localTeam) { player in
                                            ArenaTeamMemberRow(player: player, isLocal: player.id == FirebaseService.shared.currentCharacter?.id, alignment: .leading)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)

                                    // VS divider
                                    VStack(spacing: 3) {
                                        Rectangle()
                                            .fill(LinearGradient(colors: [.clear, Theme.danger.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
                                            .frame(width: 1.5, height: 60)
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 14, weight: .black))
                                            .foregroundStyle(Color.yellow)
                                            .glow(color: Color.yellow.opacity(0.8), radius: 6)
                                        Rectangle()
                                            .fill(LinearGradient(colors: [.clear, Theme.danger.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
                                            .frame(width: 1.5, height: 60)
                                    }
                                    .frame(width: 24)

                                    // Opponent team column
                                    VStack(spacing: 6) {
                                        ForEach(battle.opponentTeam) { player in
                                            ArenaTeamMemberRow(player: player, isLocal: false, alignment: .trailing)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal, 12)
                            }

                            Spacer(minLength: 8)
                        }

                        // Floating damage numbers in top half
                        ZStack {
                            ForEach(damageNumbers) { dmg in
                                DamageNumberView(damage: dmg)
                            }
                        }
                    }
                    .frame(height: geo.size.height * 0.5)

                    // ── Glowing split divider ──────────────────────────────────
                    ZStack {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Theme.danger.opacity(0.7), cameraVM.selectedClass.themeColor.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(height: 2)
                            .blur(radius: 1)
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Theme.danger, cameraVM.selectedClass.themeColor],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(height: 1.5)
                    }

                    // ╔══════════════════════════════╗
                    // ║    CAMERA FEED (bottom 50%)  ║
                    // ╚══════════════════════════════╝
                    ZStack(alignment: .bottom) {
                        // Live camera feed
                        CameraPreview(session: cameraVM.cameraManager.session)
                            .ignoresSafeArea(edges: .bottom)

                        // Pose skeleton overlay
                        PoseOverlayView(joints: cameraVM.rawJoints, themeColor: cameraVM.selectedClass.themeColor)

                        // Player Dynamic Avatar & Status overlayed on camera
                        if let player = localPlayer {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    ZStack {
                                        if let avatar = FirebaseService.shared.currentCharacter?.avatarName, let uiImage = loadLocalAvatar(named: avatar) {
                                            Image(platformImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.crop.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(cameraVM.selectedClass.themeColor)
                                        }
                                    }
                                    .overlay(Circle().stroke(cameraVM.selectedClass.themeColor, lineWidth: 1.5))
                                    .glow(color: cameraVM.selectedClass.themeColor.opacity(0.4), radius: 4)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(player.name)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("HP: \(max(0, player.health)) / \(player.maxHealth)")
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }
                                
                                // Mini HP Bar
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 90, height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(cameraVM.selectedClass.themeColor)
                                        .frame(width: 90 * CGFloat(localHPPercent), height: 4)
                                }
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .padding(.leading, 12)
                            .padding(.top, 12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }

                        // Dark gradient vignette
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.black.opacity(0.50), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 55)
                            Spacer()
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.90)],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 100)
                        }

                        // Rep counter + feedback (floating center)
                        VStack(spacing: 6) {
                            // Detection + feedback pill
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(cameraVM.isPersonDetected ? Theme.success : Theme.danger)
                                    .frame(width: 8, height: 8)
                                    .glow(color: cameraVM.isPersonDetected ? Theme.success : Theme.danger, radius: 4)
                                Text(cameraVM.feedbackMessage)
                                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black.opacity(0.65)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))

                            // Big rep counter
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(cameraVM.repCount)")
                                    .font(.system(size: 64, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .shadow(color: cameraVM.selectedClass.themeColor.opacity(0.9), radius: 18)
                                Text("REPS")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.45))
                            }

                            Text("EVERY REP = DAMAGE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.38))
                                .tracking(2)
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.top, 8)

                        // ── Player HP bar — anchored to very bottom ───────────
                        VStack(spacing: 5) {
                            HStack {
                                HStack(spacing: 5) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(localHPPercent < 0.25 ? Color.red : cameraVM.selectedClass.themeColor)
                                    Text("YOUR HP")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                                if let p = localPlayer {
                                    Text("\(max(0, p.health)) / \(p.maxHealth)")
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }

                            GeometryReader { barGeo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.7))
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(LinearGradient(
                                            colors: localHPPercent < 0.25
                                                ? [Color.red, Color.orange]
                                                : [cameraVM.selectedClass.themeColor, cameraVM.selectedClass.themeColor.opacity(0.65)],
                                            startPoint: .leading, endPoint: .trailing
                                        ))
                                        .frame(width: max(0, CGFloat(localHPPercent) * barGeo.size.width))
                                        .animation(.spring(response: 0.4), value: localPlayer?.health)
                                        .glow(color: (localHPPercent < 0.25 ? Color.red : cameraVM.selectedClass.themeColor).opacity(0.5), radius: 4)
                                }
                            }
                            .frame(height: 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.0), Color.black.opacity(0.90)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    }
                    .frame(height: geo.size.height * 0.5)
                    .clipped()
                }
                .offset(x: shakeOffset)
            }
        }
        .ignoresSafeArea()
        .overlay(
            ZStack {
                ForEach(damageNumbers) { dmg in
                    DamageNumberView(damage: dmg)
                }
            }
        )
        .onChange(of: battle.combatLog.count) { _, newCount in
            if newCount > combatLogCount {
                combatLogCount = newCount
                if let lastEvent = battle.combatLog.last {
                    if lastEvent.actionType == .skill {
                        triggerScreenShake()
                    }
                    let isPlayerTarget = lastEvent.targetName == FirebaseService.shared.currentCharacter?.username
                    spawnDamageNumber(amount: lastEvent.value, isCritical: lastEvent.isCritical ?? false, isPlayerTarget: isPlayerTarget)
                    
                    if !isPlayerTarget {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            showHitOverlay = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation {
                                showHitOverlay = false
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            combatLogCount = battle.combatLog.count
            cameraVM.cameraManager.checkPermission()
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                arenaGlow = true
            }
            // Seed the local timer from the battle's createdAt timestamp
            let elapsed = Int(Date().timeIntervalSince(battle.createdAt))
            localSecondsRemaining = max(0, 60 - elapsed)
            // Tick every second so the ring animates smoothly without waiting for Firestore snapshots
            localTimerTask?.invalidate()
            localTimerTask = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if localSecondsRemaining > 0 {
                    localSecondsRemaining -= 1
                } else {
                    localTimerTask?.invalidate()
                    localTimerTask = nil
                    MultiplayerService.shared.forceEndBattleTimeout()
                }
            }
            // Start the 3-2-1 countdown
            runCountdown()
        }
        .onChange(of: battle.secondsRemaining) { _, newVal in
            // Sync from server snapshot — but only if the server value is lower (never wind forward)
            if newVal < localSecondsRemaining {
                localSecondsRemaining = newVal
            }
        }
        .onDisappear {
            cameraVM.cameraManager.stopSession()
            localTimerTask?.invalidate()
            localTimerTask = nil
        }
        // ── 3-2-1 Countdown Overlay ───────────────────────────
        .overlay {
            if showCountdown {
                ZStack {
                    Color.black.opacity(0.75)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        Text(countdownValue > 0 ? "\(countdownValue)" : "FIGHT!")
                            .font(.system(size: countdownValue > 0 ? 120 : 72, weight: .black, design: .rounded))
                            .foregroundStyle(
                                countdownValue > 0
                                    ? LinearGradient(colors: [.white, Theme.primary], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Theme.danger, .orange], startPoint: .top, endPoint: .bottom)
                            )
                            .scaleEffect(countdownScale)
                            .opacity(countdownOpacity)
                            .shadow(color: (countdownValue > 0 ? Theme.primary : Theme.danger).opacity(0.8), radius: 20)
                        
                        if countdownValue > 0 {
                            Text("GET READY")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.textSecondary)
                                .tracking(4)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }
    
    private func runCountdown() {
        // Tick function: animates a number in, then fades it out before the next one
        func tick(value: Int) {
            countdownValue = value
            countdownScale = 0.5
            countdownOpacity = 0.0
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                countdownScale = 1.0
                countdownOpacity = 1.0
            }
            
            // Haptic punch on each number
            let impact = UIImpactFeedbackGenerator(style: value > 0 ? .medium : .heavy)
            impact.impactOccurred()
            
            // Fade out before the next tick
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeIn(duration: 0.2)) {
                    countdownOpacity = 0.0
                    countdownScale = 1.4
                }
            }
        }
        
        tick(value: 3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { tick(value: 2) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { tick(value: 1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Show FIGHT!
            countdownValue = 0
            countdownScale = 0.6
            countdownOpacity = 1.0
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                countdownScale = 1.0
            }
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            // Dismiss overlay after a brief hold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showCountdown = false
                }
            }
        }
    }
    
    private func triggerScreenShake() {

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        withAnimation(.linear(duration: 0.05)) { shakeOffset = -10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.linear(duration: 0.05)) { shakeOffset = 10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.linear(duration: 0.05)) { shakeOffset = -5 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.linear(duration: 0.05)) { shakeOffset = 0 }
                }
            }
        }
    }
    
    private func spawnDamageNumber(amount: Int, isCritical: Bool, isPlayerTarget: Bool) {
        let screenWidth = UIScreen.main.bounds.width
        let xPos = isPlayerTarget ? screenWidth * 0.25 : screenWidth * 0.75
        let yPos: CGFloat = isPlayerTarget ? 400 : 250
        
        let damage = FloatingDamage(
            amount: amount,
            isCritical: isCritical,
            isPlayer: !isPlayerTarget,
            position: CGPoint(x: xPos + CGFloat.random(in: -20...20), y: yPos + CGFloat.random(in: -20...20))
        )
        
        damageNumbers.append(damage)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            damageNumbers.removeAll { $0.id == damage.id }
        }
    }
}

// MARK: - Arena fighter card (1v1)
enum CardSide { case left, right }

struct ArenaFighterCard: View {
    let player: BattlePlayer
    let isLocal: Bool
    let side: CardSide

    var body: some View {
        VStack(spacing: 6) {
            // Avatar
            ZStack {
                Circle()
                    .fill(player.characterClass.themeColor.opacity(isLocal ? 0.2 : 0.1))
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(isLocal ? player.characterClass.themeColor : Color.white.opacity(0.15), lineWidth: isLocal ? 2 : 1))
                    .glow(color: isLocal ? player.characterClass.themeColor.opacity(0.5) : .clear, radius: 6)

                Image(systemName: "figure.walk")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(player.characterClass.themeColor)
            }

            Text(player.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(player.characterClass.rawValue.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(player.characterClass.themeColor)

            // HP bar
            VStack(spacing: 3) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.5))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(
                                colors: player.health < 30
                                    ? [Color.red, Color.orange]
                                    : [Theme.success, player.characterClass.themeColor],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: CGFloat(player.health) / CGFloat(player.maxHealth) * g.size.width)
                            .animation(.spring(), value: player.health)
                    }
                }
                .frame(height: 6)

                HStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(Theme.danger)
                    Text("\(player.health)")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("⚡\(player.reps)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(player.characterClass.themeColor)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(isLocal ? 0.65 : 0.45))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            isLocal ? player.characterClass.themeColor.opacity(0.5) : Color.white.opacity(0.1),
            lineWidth: isLocal ? 1.5 : 1
        ))
    }
}

// MARK: - 3v3 team member row
struct ArenaTeamMemberRow: View {
    let player: BattlePlayer
    let isLocal: Bool
    let alignment: HorizontalAlignment

    var body: some View {
        HStack(spacing: 8) {
            if alignment == .trailing {
                Spacer()
            }

            // Class color dot
            Circle()
                .fill(player.characterClass.themeColor)
                .frame(width: 8, height: 8)
                .glow(color: isLocal ? player.characterClass.themeColor.opacity(0.8) : .clear, radius: 3)

            VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 2) {
                Text(player.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                GeometryReader { g in
                    ZStack(alignment: alignment == .leading ? .leading : .trailing) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.black.opacity(0.5))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(player.isDead ? Color.gray : player.characterClass.themeColor)
                            .frame(width: CGFloat(player.health) / CGFloat(player.maxHealth) * g.size.width)
                    }
                }
                .frame(height: 4)

                Text("HP:\(player.health) ⚡\(player.reps)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(isLocal ? player.characterClass.themeColor : .white.opacity(0.4))
            }

            if alignment == .leading {
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(isLocal ? 0.65 : 0.35))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
            isLocal ? player.characterClass.themeColor.opacity(0.4) : Color.white.opacity(0.08),
            lineWidth: 1
        ))
    }
}


struct DamageNumberView: View {
    let damage: FloatingDamage
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Text("-\(damage.amount)")
            .font(.system(size: damage.isCritical ? 36 : 24, weight: .black, design: .monospaced))
            .foregroundColor(damage.isCritical ? Theme.healerColor : Theme.danger)
            .shadow(color: .black, radius: 2)
            .position(x: damage.position.x, y: damage.position.y + yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    yOffset = -100
                }
                withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
                    opacity = 0
                }
            }
    }
}

struct FighterCard: View {
    let player: BattlePlayer
    let isLocal: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(player.name)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            
            Text(player.characterClass.rawValue)
                .font(.caption2)
                .foregroundColor(player.characterClass.themeColor)
                .fontWeight(.semibold)
            
            // Custom avatar or class fallback
            ZStack {
                if let avatar = player.avatarName, let uiImage = loadLocalAvatar(named: avatar) {
                    Image(platformImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .glow(color: player.characterClass.themeColor.opacity(0.4), radius: 6)
                } else {
                    Circle()
                        .fill(player.characterClass.themeColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "figure.walk")
                                .font(.title3)
                                .foregroundColor(player.characterClass.themeColor)
                        )
                }
            }
            
            // Health statistics bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("HP")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textMuted)
                    Spacer()
                    Text("\(player.health)/\(player.maxHealth)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.secondaryCard)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [Theme.success, player.characterClass.themeColor],
                                startPoint: .leading,
                                endPoint: .trailing
                             ))
                            .frame(width: CGFloat(player.health) / CGFloat(player.maxHealth) * geo.size.width)
                            .animation(.spring(), value: player.health)
                    }
                }
                .frame(height: 8)
            }
            
            // Exercise counts HUD
            HStack {
                Text("REPS:")
                    .font(.caption2)
                    .foregroundColor(Theme.textMuted)
                Spacer()
                Text("\(player.reps)")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isLocal ? Theme.primary.opacity(0.5) : Theme.border, lineWidth: 1.5)
        )
        .frame(maxWidth: .infinity)
    }
}

// Compact card for 3v3 list
struct CompactFighterCard: View {
    let player: BattlePlayer
    let isLocal: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(player.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Text(player.characterClass.rawValue.prefix(3).uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(player.characterClass.themeColor)
            }
            
            // HP Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.secondaryCard)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(player.isDead ? Color.clear : (player.health < 30 ? Theme.danger : player.characterClass.themeColor))
                        .frame(width: CGFloat(player.health) / CGFloat(player.maxHealth) * geo.size.width)
                        .animation(.spring(), value: player.health)
                }
            }
            .frame(height: 5)
            
            HStack(spacing: 2) {
                Text("HP: \(player.health)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Text("Reps: \(player.reps)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .padding(8)
        .background(Theme.cardBackground.opacity(0.9))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isLocal ? Theme.primary.opacity(0.5) : (player.isDead ? Theme.danger.opacity(0.4) : Theme.border), lineWidth: 1)
        )
    }
}

struct LogRowView: View {
    let event: CombatEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(">")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Theme.textMuted)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(event.actorName)
                        .fontWeight(.bold)
                        .foregroundColor(event.actorName == FirebaseService.shared.currentCharacter?.username ? FirebaseService.shared.currentCharacter?.selectedClass.themeColor ?? Theme.textPrimary : Theme.danger)
                    
                    if event.isCritical == true {
                        Text(event.detailText)
                            .foregroundColor(Theme.healerColor) // Gold/Yellow color for crits
                            .fontWeight(.black)
                    } else if event.detailText.contains("[BAD FORM]") || event.detailText.contains("[ENRAGED]") || event.detailText.contains("[SKILL:") {
                        Text(event.detailText)
                            .foregroundColor(Theme.danger)
                    } else {
                        Text(event.detailText)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .font(.system(size: 11, design: .monospaced))
            }
        }
        .padding(.horizontal)
    }
}

// 6. Overlaid stats summary card
struct DuelResultOverlay: View {
    let winnerTitle: String
    let closeAction: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text(winnerTitle)
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(winnerTitle == "VICTORY!" ? Theme.success : Theme.danger)
                    .glow(color: winnerTitle == "VICTORY!" ? Theme.success.opacity(0.5) : Theme.danger.opacity(0.5), radius: 10)
                
                VStack(spacing: 12) {
                    Text("REWARDS GAINED")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 24) {
                        RewardBadge(icon: "star.fill", value: "+250 XP", color: Theme.success)
                        RewardBadge(icon: "centsign.circle.fill", value: "+60 Gold", color: Theme.healerColor)
                    }
                }
                .padding()
                .background(Theme.secondaryCard)
                .cornerRadius(12)
                
                Button(action: closeAction) {
                    Text("CONFIRM & CLOSE")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.primary)
                        .cornerRadius(10)
                }
                .buttonStyle(TactileButtonStyle())
                .padding(.horizontal)
            }
            .padding(24)
            .background(Theme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.border, lineWidth: 2)
            )
            .padding(.horizontal, 32)
        }
    }
}

struct BossRaidResultOverlay: View {
    @ObservedObject var engine = BattleEngine.shared
    let winnerTitle: String
    let closeAction: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text(winnerTitle)
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(winnerTitle == "VICTORY!" ? Theme.success : Theme.danger)
                    .glow(color: winnerTitle == "VICTORY!" ? Theme.success.opacity(0.5) : Theme.danger.opacity(0.5), radius: 10)
                
                VStack(spacing: 12) {
                    Text(winnerTitle == "VICTORY!" ? "BOSS DEFEATED" : "YOU DIED")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                        .fontWeight(.semibold)
                    
                    if winnerTitle == "VICTORY!" {
                        // We don't have the boss's exact xp/gold here easily without passing it,
                        // so we can just show a generic "Bounty Claimed" or pass it.
                        // For now just show "Bounty Claimed"
                        HStack(spacing: 24) {
                            RewardBadge(icon: "star.fill", value: "XP BTY", color: Theme.success)
                            RewardBadge(icon: "centsign.circle.fill", value: "GOLD BTY", color: Theme.healerColor)
                        }
                        
                        if let droppedLoot = engine.droppedLoot {
                            Divider()
                                .background(Theme.border)
                                .padding(.vertical, 8)
                            
                            Text("EPIC LOOT SECURED")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(droppedLoot.rarity.color)
                                .fontWeight(.bold)
                                .glow(color: droppedLoot.rarity.color.opacity(0.5), radius: 4)
                            
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Theme.cardBackground)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(droppedLoot.rarity.color, lineWidth: 2)
                                        )
                                        .glow(color: droppedLoot.rarity.color.opacity(0.4), radius: 6)
                                    
                                    ItemIconView(item: droppedLoot, fallbackIcon: "questionmark")
                                        .frame(width: 28, height: 28)
                                        .font(.title2)
                                        .foregroundColor(droppedLoot.rarity.color)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(droppedLoot.name)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.textPrimary)
                                    Text("\(droppedLoot.rarity.rawValue) \(droppedLoot.slot.rawValue)")
                                        .font(.caption2)
                                        .foregroundColor(droppedLoot.rarity.color)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                        }
                    } else {
                        Text("The Boss proved too powerful. Train harder.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Theme.secondaryCard)
                .cornerRadius(12)
                
                Button(action: closeAction) {
                    Text("CONFIRM & CLOSE")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.primary)
                        .cornerRadius(10)
                }
                .buttonStyle(TactileButtonStyle())
                .padding(.horizontal)
            }
            .padding(24)
            .background(Theme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.border, lineWidth: 2)
            )
            .padding(.horizontal, 32)
        }
    }
}

// 7. PvP 1v1 Leaderboards list view (uses .forest background)
struct PvPLeaderboardView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @State private var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            AnimatedBackgroundView(backgroundType: .arena)
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Spacer()
                    .frame(height: 60)
                
                Text("1V1 PVP LEADERBOARDS")
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.black)
                    .foregroundColor(Theme.textPrimary)
                    .tracking(2)
                    .glow(color: Theme.accent.opacity(0.35), radius: 8)
                
                ScrollView {
                    VStack(spacing: 8) {
                        let players = firebaseService.leaderboards["pvp_1v1"] ?? []
                        if isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                                    .scaleEffect(1.3)
                                Text("Loading PvP rankings...")
                                    .font(.caption)
                                    .foregroundColor(Theme.textMuted)
                            }
                            .padding(.top, 60)
                        } else if players.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "trophy")
                                    .font(.system(size: 36))
                                    .foregroundColor(Theme.textMuted.opacity(0.4))
                                Text("No PvP rankings yet")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(Theme.textMuted)
                                Text("Win 1v1 duels to appear here!")
                                    .font(.caption)
                                    .foregroundColor(Theme.textMuted.opacity(0.6))
                                Button(action: {
                                    isLoading = true
                                    FirebaseService.shared.fetchLeaderboards(for: ["pvp_1v1"])
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isLoading = false }
                                }) {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(Theme.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Theme.primary.opacity(0.12))
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.primary.opacity(0.3), lineWidth: 1))
                                }
                                .buttonStyle(TactileButtonStyle())
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(Array(players.enumerated()), id: \.offset) { index, player in
                                let isMe = player.id == FirebaseService.shared.currentCharacter?.id
                                HStack(spacing: 12) {
                                    RankIndicator(rank: index + 1)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 5) {
                                            Text(player.username)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(isMe ? Theme.primary : Theme.textPrimary)
                                            if isMe {
                                                Text("YOU")
                                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Theme.primary)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Text("Lvl \(player.level) • \(player.selectedClass.rawValue)")
                                            .font(.caption2)
                                            .foregroundColor(player.selectedClass.themeColor)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Label("\(player.unwrappedPvPTrophies)", systemImage: "trophy.fill")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(Theme.healerColor)
                                            .fontWeight(.bold)
                                        
                                        Text("\(player.unwrappedPvPWins) Wins")
                                            .font(.system(size: 10, design: .default))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                .padding()
                                .background(isMe ? Theme.primary.opacity(0.15) : Theme.cardBackground.opacity(0.85))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isMe ? Theme.primary.opacity(0.6) : (index < 3 ? Theme.warning.opacity(0.3) : Theme.border), lineWidth: isMe ? 1.5 : 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            isLoading = true
            FirebaseService.shared.fetchLeaderboards(for: ["pvp_1v1"])
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isLoading = false }
        }
    }
}

struct StoryModePromptInlineView: View {
    let selectSolo: () -> Void
    let selectCoop: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("STORY CAMPAIGN MODE")
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.black)
                .foregroundColor(Theme.textPrimary)
                .tracking(2)
                .glow(color: Theme.primary.opacity(0.4), radius: 8)
            
            Text("Choose how you want to conquer the 40 fitness islands")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                Button(action: selectSolo) {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("SOLO ADVENTURE")
                            .fontWeight(.bold)
                    }
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Theme.primary.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(TactileButtonStyle())
                
                Button(action: selectCoop) {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("CO-OP WITH A FRIEND")
                            .fontWeight(.bold)
                    }
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.healerColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Theme.healerColor.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(TactileButtonStyle())
            }
            .padding(.horizontal)
            
            Button(action: {
                onCancel()
            }) {
                Text("CANCEL")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Theme.danger)
                    .fontWeight(.bold)
                    .padding(.top, 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(24)
        .background(Theme.cardBackground.opacity(0.85))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.horizontal, 32)
    }
}

struct StoryInviteFriendsInlineView: View {
    @Binding var invitedFriend: String?
    let onCompleted: () -> Void
    let onCancel: () -> Void
    
    @StateObject private var vm = FriendsVM()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("INVITE STORY COMPANION")
                .font(.system(.headline, design: .monospaced))
                .fontWeight(.black)
                .foregroundColor(Theme.textPrimary)
                .tracking(1.5)
            
            if vm.isLoading {
                ProgressView()
                    .frame(height: 100)
            } else if vm.friends.isEmpty {
                Text("No friends available")
                    .foregroundColor(Theme.textSecondary)
                    .frame(height: 100)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(vm.friends) { friend in
                            let friendClass = friend.selectedClass
                            let isOnline = friend.isOnline
                            
                            HStack {
                                Circle()
                                    .fill(friendClass.themeColor.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(friendClass.themeColor)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.username)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.textPrimary)
                                    Text("\(isOnline ? "Online" : "Offline") • Lvl \(friend.level) \(friendClass.rawValue)")
                                        .font(.system(size: 8))
                                        .foregroundColor(isOnline ? Theme.success : Theme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    invitedFriend = friend.username
                                    onCompleted()
                                }) {
                                    Text("INVITE")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(isOnline ? .white : .gray)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 6)
                                        .background(isOnline ? Theme.primary : Color.gray.opacity(0.3))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(TactileButtonStyle())
                                .disabled(!isOnline)
                            }
                            .padding()
                            .background(Theme.secondaryCard)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.border, lineWidth: 0.5)
                            )
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
            
            Button(action: {
                onCancel()
            }) {
                Text("CANCEL")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Theme.danger)
                    .fontWeight(.bold)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(24)
        .background(Theme.cardBackground.opacity(0.85))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

struct WarpTransitionView: View {
    let onCompletion: () -> Void
    @State private var particles: [WarpParticle] = []
    @State private var timer: Timer? = nil
    @State private var elapsedSeconds: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Starfield / Inward Vortex Star Canvas
            Canvas { context, size in
                context.translateBy(x: size.width / 2, y: size.height / 2)
                for particle in particles {
                    let rad = particle.angle
                    let startX = cos(rad) * particle.distance
                    let startY = sin(rad) * particle.distance
                    
                    // Small glowing stars: slightly larger on the outside, tiny in the deep center
                    let radius = particle.size * (0.45 + (particle.distance * 0.0015))
                    
                    // Fade in at the outer bounds, reach max opacity, and fade out near the center vortex (distance < 20)
                    let opacity = Double(min(1.0, (650.0 - particle.distance) / 100.0)) * Double(max(0.0, (particle.distance - 20.0) / 80.0))
                    
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: startX - radius,
                            y: startY - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            generateParticles()
            animateWarp()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func generateParticles() {
        // Reduced count for a clean, non-cluttered space field
        for _ in 0..<75 {
            particles.append(WarpParticle(
                angle: Double.random(in: 0...(2 * .pi)),
                distance: CGFloat.random(in: 20...650),
                speed: CGFloat.random(in: 0.9...2.3), // Elegant, slower drift speeds
                size: CGFloat.random(in: 0.8...2.2)    // Tiny, delicate stars
            ))
        }
    }
    
    private func animateWarp() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            for i in 0..<particles.count {
                // Sucked inward (decrease distance)
                particles[i].distance -= particles[i].speed
                
                // Spin slowly. Spin speed increases as they get closer to the center to simulate gravity
                let spinSpeed = 0.004 + (18.0 / max(25.0, particles[i].distance)) * 0.012
                particles[i].angle += spinSpeed
                
                if particles[i].distance <= 15 {
                    // Reset back to the outer universe boundaries
                    particles[i].distance = CGFloat.random(in: 550...650)
                    particles[i].angle = Double.random(in: 0...(2 * .pi))
                    particles[i].speed = CGFloat.random(in: 0.9...2.3)
                }
            }
            
            elapsedSeconds += 0.016
            if elapsedSeconds >= 3.2 { // Slower, 3.2s transition duration
                timer?.invalidate()
                onCompletion()
            }
        }
    }
}

struct WarpParticle: Identifiable {
    let id = UUID()
    var angle: Double
    var distance: CGFloat
    var speed: CGFloat
    var size: CGFloat
}

struct StoryMapView: View {
    let isCoop: Bool
    let coopFriend: String?
    let onBack: () -> Void
    let onSelectStage: (Int) -> Void
    
    @ObservedObject var firebaseService = FirebaseService.shared
    
    private var activeStage: Int {
        firebaseService.currentCharacter?.storyStage ?? 1
    }
    
    // Zigzag coordinates generated for 40 stages dynamically
    private func stageCoordinate(for stage: Int) -> CGPoint {
        let xOffset: CGFloat = stage % 2 == 0 ? 250 : 110
        let yPos: CGFloat = CGFloat(41 - stage) * 110 // spacing of 110pt
        return CGPoint(x: xOffset, y: yPos)
    }
    
    private var coordinatesList: [CGPoint] {
        (1...40).map { stageCoordinate(for: $0) }
    }
    
    var body: some View {
        ZStack {
            // Background Layer
            AnimatedBackgroundView(backgroundType: .mountain)
                .ignoresSafeArea()
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            
            // Scrollable Adventure Map
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .top) {
                        // 1. Invisible anchor layer for ScrollViewReader (must be inside ZStack, not overlay)
                        VStack(spacing: 0) {
                            Spacer().frame(height: 55) // offset for the first element
                            ForEach(0..<40, id: \.self) { index in
                                let stage = 40 - index
                                Color.clear
                                    .frame(width: 10, height: 110)
                                    .id(stage)
                            }
                            Spacer().frame(height: 55)
                        }
                        
                        // 2. Winding Road Path connecting coordinates (Zigzag 40 nodes)
                        Path { path in
                            let coords = coordinatesList
                            if !coords.isEmpty {
                                path.move(to: coords[0])
                                for i in 1..<coords.count {
                                    path.addLine(to: coords[i])
                                }
                            }
                        }
                        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [10, 8]))
                        .foregroundColor(Theme.primary.opacity(0.6))
                        
                        // Map decor elements
                        MapDecoratorView(x: 60, y: 3900, icon: "tree.fill")
                        MapDecoratorView(x: 300, y: 3600, icon: "mountain.2.fill")
                        MapDecoratorView(x: 60, y: 3000, icon: "tree.fill")
                        MapDecoratorView(x: 320, y: 2400, icon: "tent.fill")
                        MapDecoratorView(x: 80, y: 1800, icon: "tree.fill")
                        MapDecoratorView(x: 300, y: 1200, icon: "bonfire.fill")
                        MapDecoratorView(x: 60, y: 600, icon: "tree.fill")
                        
                        // 2. Interactive 3D Platform Nodes (40 Levels)
                        ForEach(1...40, id: \.self) { stage in
                            let isUnlocked = stage <= activeStage
                            let isCompleted = stage < activeStage
                            let isBoss = stage % 10 == 0
                            let coord = stageCoordinate(for: stage)
                            
                            StoryStageTile(
                                stage: stage,
                                isUnlocked: isUnlocked,
                                isCompleted: isCompleted,
                                isBoss: isBoss,
                                action: {
                                    onSelectStage(stage)
                                }
                            )
                            // ID removed from here because absolute positioned views confuse ScrollViewReader
                            .position(x: coord.x, y: coord.y)
                        }
                    }
                    .frame(width: 360, height: 4510) // 40 stages * 110 spacing + margins
                    .onAppear {
                        // Scroll to the very beginning (Stage 1) as requested
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeOut(duration: 1.0)) {
                                scrollProxy.scrollTo(1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Map Top Bar
            VStack {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("BACK")
                        }
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("40 fitness islands".uppercased())
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(.white)
                        
                        if isCoop, let name = coopFriend {
                            Text("CO-OP COMPANION: \(name)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(Theme.healerColor)
                        } else {
                            Text("SOLO EXPEDITION")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                Spacer()
            }
        }
    }
}

// 3D Isometric Map Stage Tile
struct StoryStageTile: View {
    let stage: Int
    let isUnlocked: Bool
    let isCompleted: Bool
    let isBoss: Bool
    let action: () -> Void
    
    private var isVolcanic: Bool { stage > 20 }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Bevel Depth Shadow Layer
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isVolcanic
                            ? Color(red: 0.25, green: 0.1, blue: 0.1) // Obsidian deep red depth
                            : Color(red: 0.35, green: 0.25, blue: 0.15) // Forest dirt soil depth
                        )
                        .frame(width: isBoss ? 64 : 50, height: isBoss ? 64 : 50)
                        .offset(y: 6) // Creates 3D look
                    
                    // Main Beveled Platform Face
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: isUnlocked
                                ? (isCompleted
                                    ? (isVolcanic
                                        ? [Color(red: 0.22, green: 0.22, blue: 0.24), Color(red: 0.12, green: 0.12, blue: 0.14)] // volcanic black obsidian
                                        : [Theme.success, Color(red: 0.18, green: 0.65, blue: 0.28)]) // pasture forest grass green
                                    : [Color.yellow, Color.orange]) // active next cell
                                : [Color.gray.opacity(0.6), Color.gray.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: isBoss ? 64 : 50, height: isBoss ? 64 : 50)
                        .overlay(
                            Group {
                                // Volcano lava crack cracks (Stages 21-40)
                                if isVolcanic && isUnlocked {
                                    VolcanicCracksOverlay(isBoss: isBoss)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isUnlocked
                                    ? (isBoss ? Theme.danger : Theme.primary.opacity(0.8))
                                    : Theme.border,
                                    lineWidth: isBoss ? 2.5 : 1.5
                                )
                        )
                        .glow(color: isUnlocked ? (isBoss ? Theme.danger.opacity(0.6) : Theme.primary.opacity(0.35)) : .clear, radius: 8)
                    
                    // Emblems / Indicators inside Platform Face
                    VStack {
                        if isBoss {
                            VStack(spacing: 2) {
                                Image(systemName: "skull.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(isUnlocked ? Theme.danger : .white.opacity(0.7))
                                Text("\(stage)")
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 3)
                            }
                        } else if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(stage)")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Text(isBoss ? "BOSS \(stage)" : "STAGE \(stage)")
                    .font(.system(size: 8, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(isUnlocked ? Theme.textPrimary : Theme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(4)
            }
        }
        .buttonStyle(TactileButtonStyle())
        .disabled(!isUnlocked)
    }
}

// Glowing lava veins for volcanic obsidian tiles
struct VolcanicCracksOverlay: View {
    let isBoss: Bool
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                // Draw jagged lava fissure paths
                path.move(to: CGPoint(x: geo.size.width * 0.15, y: geo.size.height * 0.25))
                path.addLine(to: CGPoint(x: geo.size.width * 0.45, y: geo.size.height * 0.55))
                path.addLine(to: CGPoint(x: geo.size.width * 0.35, y: geo.size.height * 0.85))
                
                path.move(to: CGPoint(x: geo.size.width * 0.85, y: geo.size.height * 0.15))
                path.addLine(to: CGPoint(x: geo.size.width * 0.6, y: geo.size.height * 0.65))
                path.addLine(to: CGPoint(x: geo.size.width * 0.75, y: geo.size.height * 0.85))
            }
            .stroke(Color.orange, lineWidth: 1.5)
            .glow(color: Color.orange.opacity(0.8), radius: 3)
        }
    }
}

// Preparation Countdown Screen
struct StoryStagePrepView: View {
    let stage: Int
    let isCoop: Bool
    let coopFriend: String?
    let onStartWorkout: (CharacterClass, Int, Int) -> Void
    
    @State private var timeRemaining: Int = 25
    @State private var selectedExerciseIndex: Int = 0
    @State private var timer: Timer? = nil
    @State private var pulse: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    private var isBoss: Bool { stage % 10 == 0 }
    
    // Choose all exercises for the stage
    private var eligibleExercises: [CharacterClass] {
        return CharacterClass.allCases
    }
    
    private var bossMaxHP: Int {
        if stage == 10 { return 2500 }
        if stage == 20 { return 5000 }
        if stage == 30 { return 7500 }
        if stage == 40 { return 10000 }
        return stage * 150
    }
    
    private func damagePerRep(for cls: CharacterClass) -> Int {
        switch cls {
        case .archer: return 10 + stage * 2
        case .mage: return 15 + stage * 3
        case .swordsman: return 30 + stage * 4
        case .healer: return 20 + stage * 3
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            AnimatedBackgroundView(backgroundType: .mountain)
            Color.black.opacity(0.4).ignoresSafeArea()
            
            // Subtle animated glow in background
            RadialGradient(
                colors: [(isBoss ? Theme.danger : Theme.primary).opacity(0.15), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: isBoss ? "flame.fill" : "swords.fill")
                                Text(isBoss ? "BOSS PREPARATION" : "PREPARATION ARENA")
                                Image(systemName: isBoss ? "flame.fill" : "swords.fill")
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(isBoss ? Theme.danger : Theme.primary)
                            .tracking(2)
                            
                            Text("STAGE \(stage): \(stageName(for: stage).uppercased())")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .glow(color: (isBoss ? Theme.danger : Theme.primary).opacity(0.3), radius: 8)
                        }
                        .padding(.top, 24)
                        
                        // Countdown Timer Card
                        VStack(spacing: 8) {
                            Text("STARTING WORKOUT IN")
                                .font(.system(size: 10, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textSecondary)
                            
                            Text("\(timeRemaining)")
                                .font(.system(size: 72, weight: .black, design: .monospaced))
                                .foregroundColor(isBoss ? Theme.danger : Theme.accent)
                                .glow(color: (isBoss ? Theme.danger : Theme.accent).opacity(0.6), radius: 15)
                                .scaleEffect(pulse ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulse)
                            
                            Text("SECONDS")
                                .font(.system(size: 10, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Theme.cardBackground.opacity(0.8))
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(LinearGradient(colors: [(isBoss ? Theme.danger : Theme.accent).opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                            }
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                        .padding(.horizontal)
                        
                        // Target HP indicator
                        VStack(spacing: 6) {
                            HStack {
                                Text("STAGE TARGET HP")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(bossMaxHP) HP")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 10)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isBoss ? Theme.danger : Theme.primary)
                                    .frame(height: 10)
                                    .glow(color: (isBoss ? Theme.danger : Theme.primary).opacity(0.5), radius: 6)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Exercise choices
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CHOOSE COMBAT ATTACK")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1)
                                .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(0..<eligibleExercises.count, id: \.self) { idx in
                                    let cls = eligibleExercises[idx]
                                    let isSelected = selectedExerciseIndex == idx
                                    let rawDMG = damagePerRep(for: cls)
                                    let dmg = isCoop ? Int(Double(rawDMG) * 1.25) : rawDMG
                                    let repsNeeded = Int(ceil(Double(bossMaxHP) / Double(dmg)))
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedExerciseIndex = idx
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                ZStack {
                                                    Circle()
                                                        .fill(cls.themeColor.opacity(isSelected ? 0.2 : 0.05))
                                                        .frame(width: 32, height: 32)
                                                    
                                                    Image(systemName: classIcon(for: cls))
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(cls.themeColor)
                                                }
                                                Spacer()
                                                if isSelected {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(cls.themeColor)
                                                        .font(.system(size: 16))
                                                }
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(cls.rawValue.uppercased())
                                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                                    .foregroundColor(isSelected ? .white : Theme.textPrimary)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                                
                                                Text(cls.primaryExercise)
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                            
                                            HStack(alignment: .bottom) {
                                                VStack(alignment: .leading, spacing: 0) {
                                                    Text("+\(dmg) DMG")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(Theme.textMuted)
                                                }
                                                Spacer()
                                                Text("\(repsNeeded) Reps")
                                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                                    .foregroundColor(isSelected ? cls.themeColor : .white.opacity(0.8))
                                            }
                                        }
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(isSelected ? Theme.secondaryCard.opacity(0.8) : Theme.cardBackground.opacity(0.5))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(isSelected ? cls.themeColor : Color.white.opacity(0.05), lineWidth: isSelected ? 2 : 1)
                                        )
                                        .shadow(color: isSelected ? cls.themeColor.opacity(0.2) : .clear, radius: 8, y: 4)
                                        .scaleEffect(isSelected ? 1.02 : 1.0)
                                    }
                                    .buttonStyle(TactileButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            if isCoop {
                                HStack {
                                    Spacer()
                                    Text("🤝 +25% Co-op Damage Buff Active")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(Theme.success)
                                        .padding(.top, 4)
                                    Spacer()
                                }
                            }
                        }
                        
                        Spacer().frame(height: 10)
                    }
                }
                
                // Action buttons fixed at bottom
                VStack(spacing: 12) {
                    let activeClass = eligibleExercises[selectedExerciseIndex]
                    
                    Button(action: {
                        startWorkout()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                            Text("SKIP & START WORKOUT")
                        }
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [activeClass.themeColor, activeClass.themeColor.opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: activeClass.themeColor.opacity(0.4), radius: 12, y: 6)
                    }
                    .buttonStyle(TactileButtonStyle())
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("CANCEL EXPEDITION")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .padding(.top, 16)
                .background(
                    LinearGradient(colors: [Theme.background.opacity(0), Theme.background], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
            }
        }
        .onAppear {
            pulse = true
            startTimeCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimeCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                startWorkout()
            }
        }
    }
    
    private func startWorkout() {
        timer?.invalidate()
        let cls = eligibleExercises[selectedExerciseIndex]
        let dmg = isCoop ? Int(Double(damagePerRep(for: cls)) * 1.25) : damagePerRep(for: cls)
        onStartWorkout(cls, bossMaxHP, dmg)
    }
    
    private func classIcon(for cls: CharacterClass) -> String {
        switch cls {
        case .archer: return "arrow.up.forward.app.fill"
        case .mage: return "bolt.heart.fill"
        case .swordsman: return "hammer.fill"
        case .healer: return "cross.case.fill"
        }
    }
    
    private func stageName(for stage: Int) -> String {
        if stage % 10 == 0 {
            if stage == 10 { return "Gorgon's Behemoth Isle" }
            if stage == 20 { return "Dark Lord's Spire" }
            if stage == 30 { return "Ice Colossus Cave" }
            return "Final Volcanic Peak"
        }
        let descriptors = ["Whispering", "Sunken", "Crimson", "Shadowy", "Frozen", "Volcanic", "Forgotten", "Glimmering", "Haunted", "Emerald"]
        let nouns = ["Isle", "Atoll", "Reef", "Rock", "Cove", "Shoal", "Bay", "Peak", "Haven", "Sanctuary"]
        let desc = descriptors[stage % descriptors.count]
        let noun = nouns[stage % nouns.count]
        return "\(desc) \(noun)"
    }
}

struct StoryWinOverlay: View {
    let stage: Int
    let closeAction: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("STAGE CONQUERED!")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(Theme.success)
                    .glow(color: Theme.success.opacity(0.5), radius: 10)
                
                Text("You have successfully defeated the defender of Stage \(stage) and advanced on the adventure map.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Text("REWARDS EARNED")
                        .font(.system(size: 10, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textMuted)
                    
                    HStack(spacing: 20) {
                        RewardBadge(icon: "star.fill", value: "+\(stage * 50) XP", color: Theme.success)
                        RewardBadge(icon: "centsign.circle.fill", value: "+\(stage * 10) Gold", color: Theme.healerColor)
                    }
                }
                .padding()
                .background(Theme.secondaryCard)
                .cornerRadius(12)
                
                Button(action: closeAction) {
                    Text("CONTINUE ADVENTURE")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.primary)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding(24)
            .background(Theme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .padding(.horizontal, 32)
        }
    }
}

struct MapDecoratorView: View {
    let x: CGFloat
    let y: CGFloat
    let icon: String
    
    var body: some View {
        Image(systemName: icon)
            .font(.title3)
            .foregroundColor(Theme.textMuted.opacity(0.3))
            .position(x: x, y: y)
    }
}

struct MatchmakingClassPickerSheet: View {
    let onSelected: (CharacterClass) -> Void
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss
    @State private var tempClassSelection: CharacterClass = .swordsman
    
    var body: some View {
        ZStack {
            AnimatedBackgroundView(backgroundType: .arena)
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text("PVP MATCHMAKING PREPARATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .tracking(1.5)
                        .padding(.top, 24)
                    
                    Text("CHOOSE COMBAT CLASS")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.black)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Text("Matchmaking will pair you with opponents performing the SAME exercise type to ensure absolute fairness.")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 6)
                
                // 2x2 Grid of classes
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(CharacterClass.allCases) { charClass in
                        let isSelected = tempClassSelection == charClass
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                tempClassSelection = charClass
                            }
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(charClass.themeColor.opacity(isSelected ? 0.25 : 0.08))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: classIcon(for: charClass))
                                        .font(.title3)
                                        .foregroundColor(charClass.themeColor)
                                }
                                .glow(color: isSelected ? charClass.themeColor.opacity(0.3) : .clear, radius: 5)
                                
                                VStack(spacing: 2) {
                                    Text(charClass.rawValue.uppercased())
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.black)
                                        .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                                    
                                    Text(charClass.primaryExercise.uppercased())
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(isSelected ? charClass.themeColor : Theme.textMuted)
                                }
                            }
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? Theme.secondaryCard.opacity(0.85) : Theme.cardBackground.opacity(0.6))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected ? charClass.themeColor : Theme.border, lineWidth: isSelected ? 2 : 1)
                            )
                            .scaleEffect(isSelected ? 1.02 : 0.98)
                        }
                        .buttonStyle(TactileButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                
                // Exercise detail preview
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(tempClassSelection.themeColor)
                    Text("ACTIVE COMPETING EXERCISE: \(tempClassSelection.primaryExercise.uppercased())")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(tempClassSelection.themeColor.opacity(0.08))
                .cornerRadius(10)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Start button
                Button(action: {
                    dismiss()
                    onSelected(tempClassSelection)
                }) {
                    Text("FIND EQUAL-EXERCISE MATCH")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.black)
                        .tracking(1.5)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(tempClassSelection.themeColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .glow(color: tempClassSelection.themeColor.opacity(0.4), radius: 8)
                }
                .buttonStyle(TactileButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            if let userClass = FirebaseService.shared.currentCharacter?.selectedClass {
                tempClassSelection = userClass
            }
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

struct BattleArenaView_Previews: PreviewProvider {
    static var previews: some View {
        BattleArenaView()
    }
}
