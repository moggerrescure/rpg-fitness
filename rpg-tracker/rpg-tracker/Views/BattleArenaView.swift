import SwiftUI

enum BattleArenaSheetType: Identifiable, Equatable {
    case generalCameraTracker
    case storyStagePrep(stage: Int)
    case storyCameraTracker(exerciseClass: CharacterClass, bossMaxHP: Int, damagePerRep: Int)
    case pvpInviteFriends
    
    var id: String {
        switch self {
        case .generalCameraTracker:
            return "generalCameraTracker"
        case .storyStagePrep(let stage):
            return "storyStagePrep_\(stage)"
        case .storyCameraTracker(let cls, let hp, let dmg):
            return "storyCameraTracker_\(cls.rawValue)_\(hp)_\(dmg)"
        case .pvpInviteFriends:
            return "pvpInviteFriends"
        }
    }
    
    static func == (lhs: BattleArenaSheetType, rhs: BattleArenaSheetType) -> Bool {
        lhs.id == rhs.id
    }
}

enum StorySetupStep: Equatable {
    case selectMode       // solo / coop prompt
    case inviteFriend     // invite companion inline
    case warpAnimation    // github-like warp animation
    case activeMap        // actual map view
}

struct BattleArenaView: View {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var viewModel = BattleVM()
    @State private var selectedTab: Int = 0 // 0: Arena, 1: 1v1 Leaderboards
    @State private var isInLobby: Bool = false
    @State private var showInviteSheet: Bool = false
    @State private var showMatchmakingClassPicker: Bool = false
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
                    Theme.background
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
                    } else if isInLobby {
                        TeamLobbyView(viewModel: viewModel, backAction: {
                            isInLobby = false
                            viewModel.selectedPvPType = .duel1v1
                        }, inviteAction: {
                            showInviteSheet = true
                        }, searchAction: {
                            showMatchmakingClassPicker = true
                        })
                    } else if storySetupStep == .selectMode {
                        ZStack {
                            AnimatedBackgroundView(backgroundType: .mountain)
                            Color.black.opacity(0.5)
                                .ignoresSafeArea()
                            
                            StoryModePromptInlineView(
                                selectSolo: {
                                    isStoryCoop = false
                                    storyCoopFriend = nil
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        storySetupStep = .warpAnimation
                                    }
                                },
                                selectCoop: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        storySetupStep = .inviteFriend
                                    }
                                },
                                onCancel: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        storySetupStep = nil
                                    }
                                }
                            )
                        }
                    } else if storySetupStep == .inviteFriend {
                        ZStack {
                            AnimatedBackgroundView(backgroundType: .mountain)
                            Color.black.opacity(0.5)
                                .ignoresSafeArea()
                            
                            StoryInviteFriendsInlineView(
                                invitedFriend: $storyCoopFriend,
                                onCompleted: {
                                    isStoryCoop = true
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        storySetupStep = .warpAnimation
                                    }
                                },
                                onCancel: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        storySetupStep = .selectMode
                                    }
                                }
                            )
                        }
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
                                    withAnimation {
                                        storySetupStep = .selectMode
                                    }
                                },
                                selectBossRaid: {
                                    viewModel.selectedPvPType = .bossRaid
                                    if let char = FirebaseService.shared.currentCharacter {
                                        if let wb = FirebaseService.shared.activeWorldBoss, wb.isActive {
                                            let template = Boss.templates.first { $0.id == wb.bossTemplateId } ?? Boss.templates.last!
                                            var activeTemplate = template
                                            activeTemplate.maxHealth = wb.maxHealth
                                            activeTemplate.currentHealth = wb.currentHealth
                                            activeTemplate.isGlobalWorldBoss = true
                                            BattleEngine.shared.startBossRaid(bossTemplate: activeTemplate, player: char)
                                        } else {
                                            let randomBoss = Boss.templates.randomElement()!
                                            BattleEngine.shared.startBossRaid(bossTemplate: randomBoss, player: char)
                                        }
                                    }
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
        .sheet(item: $activeSheet) { sheet in
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
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            activeSheet = .storyCameraTracker(exerciseClass: exerciseClass, bossMaxHP: bossHP, damagePerRep: repDMG)
                        }
                    }
                )
            case .storyCameraTracker(let exerciseClass, let bossMaxHP, let damagePerRep):
                CameraTrackingView(
                    selectedClass: exerciseClass,
                    bossMaxHP: bossMaxHP,
                    damagePerRep: damagePerRep,
                    onComplete: { repsCompleted in
                        activeSheet = nil
                        handleStoryStageWin()
                    }
                )
            case .pvpInviteFriends:
                InviteFriendsSheet(viewModel: viewModel)
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
        .onChange(of: viewModel.showCameraTracker) { newValue in
            if newValue {
                activeSheet = .generalCameraTracker
            } else if activeSheet == .generalCameraTracker {
                activeSheet = nil
            }
        }
        .onChange(of: showInviteSheet) { newValue in
            if newValue {
                activeSheet = .pvpInviteFriends
            } else if activeSheet == .pvpInviteFriends {
                activeSheet = nil
            }
        }
        .onChange(of: activeSheet) { newValue in
            if newValue == nil {
                if showInviteSheet {
                    showInviteSheet = false
                    if viewModel.selectedPvPType == .team3v3 {
                        // Immediately search for opponent once the invite sheet is dismissed
                        viewModel.startQueue()
                    }
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
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
        .onAppear {
            if let type = initialPvPType {
                viewModel.selectedPvPType = type
                if type == .bossRaid {
                    if let char = FirebaseService.shared.currentCharacter {
                        if let wb = FirebaseService.shared.activeWorldBoss, wb.isActive {
                            let template = Boss.templates.first { $0.id == wb.bossTemplateId } ?? Boss.templates.last!
                            var activeTemplate = template
                            activeTemplate.maxHealth = wb.maxHealth
                            activeTemplate.currentHealth = wb.currentHealth
                            activeTemplate.isGlobalWorldBoss = true
                            BattleEngine.shared.startBossRaid(bossTemplate: activeTemplate, player: char)
                        }
                    }
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


// 1. PvP Mode selector (Cards selection screen)
struct PvPModeSelectorView: View {
    let select1v1: () -> Void
    let select3v3: () -> Void
    let selectStory: () -> Void
    let selectBossRaid: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)
            
            VStack(spacing: 8) {
                Text("GAME ADVENTURE MODES")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.black)
                    .foregroundColor(Theme.textPrimary)
                    .tracking(2)
                    .glow(color: Theme.accent.opacity(0.35), radius: 8)
                
                Text("Select battle arena or journey fit campaign")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.top, 20)
            
            Spacer()
            
            VStack(spacing: 16) {
                // Story Campaign Card
                Button(action: selectStory) {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Theme.healerColor.opacity(0.15))
                                .frame(width: 54, height: 54)
                            
                            Image(systemName: "map.fill")
                                .font(.title3)
                                .foregroundColor(Theme.healerColor)
                        }
                        .glow(color: Theme.healerColor.opacity(0.35), radius: 6)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STORY CAMPAIGN (CO-OP / SOLO)")
                                .font(.system(.subheadline, design: .default))
                                .fontWeight(.black)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Journey through 20 islands. Face epic bosses at stages 10 & 20. Team up or go solo.")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.cardBackground.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(LinearGradient(
                                colors: [Theme.healerColor.opacity(0.35), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.5)
                    )
                    .shadow(color: Theme.healerColor.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(TactileButtonStyle())
                
                // 1v1 Duel Card
                Button(action: select1v1) {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Theme.danger.opacity(0.15))
                                .frame(width: 54, height: 54)
                            
                            Image(systemName: "sword.and.shield.flightpath")
                                .font(.title3)
                                .foregroundColor(Theme.danger)
                        }
                        .glow(color: Theme.danger.opacity(0.35), radius: 6)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1V1 SPEED DUEL")
                                .font(.system(.subheadline, design: .default))
                                .fontWeight(.black)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Fast automated match. Push your limits in a 60-second exercise race.")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.cardBackground.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(LinearGradient(
                                colors: [Theme.danger.opacity(0.35), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.5)
                    )
                    .shadow(color: Theme.danger.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(TactileButtonStyle())
                
                // 3v3 Co-op Card
                Button(action: select3v3) {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Theme.primary.opacity(0.15))
                                .frame(width: 54, height: 54)
                            
                            Image(systemName: "person.3.fill")
                                .font(.title3)
                                .foregroundColor(Theme.primary)
                        }
                        .glow(color: Theme.primary.opacity(0.35), radius: 6)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("3V3 CO-OP BATTLE")
                                .font(.system(.subheadline, design: .default))
                                .fontWeight(.black)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Invite up to 2 friends. Coordinate exercises to execute team attacks and heals.")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.cardBackground.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(LinearGradient(
                                colors: [Theme.primary.opacity(0.35), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.5)
                    )
                    .shadow(color: Theme.primary.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(TactileButtonStyle())
                
                // Solo Boss Raid Card
                Button(action: selectBossRaid) {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Theme.warning.opacity(0.15))
                                .frame(width: 54, height: 54)
                            
                            Image(systemName: "flame.fill")
                                .font(.title3)
                                .foregroundColor(Theme.warning)
                        }
                        .glow(color: Theme.warning.opacity(0.35), radius: 6)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SOLO BOSS RAID")
                                .font(.system(.subheadline, design: .default))
                                .fontWeight(.black)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Face off against a massive boss. Your workout reps deal direct damage to the beast.")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.cardBackground.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(LinearGradient(
                                colors: [Theme.warning.opacity(0.35), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.5)
                    )
                    .shadow(color: Theme.warning.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(TactileButtonStyle())
            }
            .padding(.horizontal)
            
            Spacer()
                .frame(height: 100) // Bottom tab space
        }
    }
}

// 2. 3v3 Party/Lobby screen
struct TeamLobbyView: View {
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
    
    var body: some View {
        VStack(spacing: 20) {
            Text("INVITE FRIENDS")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
                .padding(.top, 20)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.friendsList, id: \.self) { friend in
                        let friendClass: CharacterClass = friend == "AquaHealer" ? .healer : (friend == "FireMage" ? .mage : (friend == "WindArcher" ? .archer : .swordsman))
                        HStack {
                            Circle()
                                .fill(friendClass.themeColor.opacity(0.15))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(friendClass.themeColor)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.textPrimary)
                                Text("Online • \(friendClass.rawValue)")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.invitedFriends.contains(friend) {
                                Text("INVITED")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.success)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.success.opacity(0.15))
                                    .cornerRadius(8)
                            } else {
                                Button(action: {
                                    viewModel.inviteFriend(friend)
                                    if viewModel.invitedFriends.count >= 2 {
                                        dismiss()
                                    }
                                }) {
                                    Text("INVITE")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 6)
                                        .background(Theme.primary)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.invitedFriends.count >= 2)
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            Button(action: { dismiss() }) {
                Text("DONE")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.secondaryCard)
                    .foregroundColor(Theme.textPrimary)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Theme.background.ignoresSafeArea())
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
                .padding(.horizontal)
                .padding(.bottom, 32)
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
    
    @State private var shakeOffset: CGFloat = 0
    @State private var combatLogCount: Int = 0
    @State private var damageNumbers: [FloatingDamage] = []
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 44)
            
            // Timer & Status Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(battle.type == .duel1v1 ? "1V1 DUEL IN PROGRESS" : "3V3 TEAM MATCH IN PROGRESS")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                        .fontWeight(.bold)
                    Text(battle.id)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                // Active timer
                ZStack {
                    Circle()
                        .stroke(Theme.border, lineWidth: 4)
                        .frame(width: 48, height: 48)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(battle.secondsRemaining) / 60.0)
                        .stroke(battle.secondsRemaining < 15 ? Theme.danger : Theme.success, lineWidth: 4)
                        .frame(width: 48, height: 48)
                        .rotationEffect(Angle(degrees: -90))
                    
                    Text("\(battle.secondsRemaining)s")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Fighters Grid Layout
            if battle.type == .bossRaid {
                VStack(spacing: 16) {
                    if let boss = BattleEngine.shared.activeBoss {
                        VStack(spacing: 8) {
                            Text(boss.name)
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(Theme.danger)
                            
                            // Big Boss HP Bar
                            GeometryReader { geo in
                                let isEnraged = Double(boss.currentHealth) < Double(boss.maxHealth) * 0.5
                                
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.5))
                                    
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isEnraged ? Color.red : Theme.danger)
                                        .frame(width: max(0, geo.size.width * CGFloat(boss.currentHealth) / CGFloat(boss.maxHealth)))
                                        .animation(.spring(), value: boss.currentHealth)
                                        .shadow(color: isEnraged ? Color.red : Color.clear, radius: isEnraged ? 8 : 0)
                                }
                            }
                            .frame(height: 24)
                            .overlay(
                                Text("\(boss.currentHealth) / \(boss.maxHealth) HP")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                            .padding(.horizontal, 32)
                        }
                    }
                    
                    Text("VS")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textMuted)
                    
                    if let p1 = battle.localTeam.first {
                        FighterCard(player: p1, isLocal: true)
                    }
                }
            } else if battle.type == .duel1v1 {
                // 1v1 Layout
                HStack(spacing: 12) {
                    if let p1 = battle.localTeam.first {
                        FighterCard(player: p1, isLocal: true)
                    }
                    
                    Text("VS")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textMuted)
                    
                    if let p2 = battle.opponentTeam.first {
                        FighterCard(player: p2, isLocal: false)
                    }
                }
                .padding(.horizontal)
            } else {
                // 3v3 Team Layout (Side-by-side columns of compact cards)
                HStack(spacing: 8) {
                    // Local Team (Left Column)
                    VStack(spacing: 8) {
                        ForEach(battle.localTeam) { player in
                            CompactFighterCard(player: player, isLocal: player.id == FirebaseService.shared.currentCharacter?.id)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text("VS")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 4)
                    
                    // Opponent Team (Right Column)
                    VStack(spacing: 8) {
                        ForEach(battle.opponentTeam) { player in
                            CompactFighterCard(player: player, isLocal: false)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 8)
            }
            
            // Combat Log Panel
            VStack(alignment: .leading, spacing: 10) {
                Text("COMBAT TELEMETRY LOG")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal)
                    .padding(.top, 12)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if battle.combatLog.isEmpty {
                            Text("> Combat initialized. Perform exercises to attack!")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(battle.combatLog) { event in
                                LogRowView(event: event)
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.cardBackground.opacity(0.85))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .padding(.horizontal)
            
            // Activate Tracking Button
            Button(action: { viewModel.showCameraTracker = true }) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                    Text("ACTIVATE WORKOUT CAMERA")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.currentClass.themeColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: viewModel.currentClass.themeColor.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .overlay(
            ZStack {
                ForEach(damageNumbers) { dmg in
                    DamageNumberView(damage: dmg)
                }
            }
        )
        .offset(x: shakeOffset)
        .onChange(of: battle.combatLog.count) { newCount in
            if newCount > combatLogCount {
                combatLogCount = newCount
                if let lastEvent = battle.combatLog.last {
                    if lastEvent.actionType == .skill {
                        triggerScreenShake()
                    }
                    
                    let isPlayerTarget = lastEvent.targetName == FirebaseService.shared.currentCharacter?.username
                    spawnDamageNumber(amount: lastEvent.value, isCritical: lastEvent.isCritical ?? false, isPlayerTarget: isPlayerTarget)
                }
            }
        }
        .onAppear {
            combatLogCount = battle.combatLog.count
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
        let yPos: CGFloat = isPlayerTarget ? 400 : 250 // Rough estimates
        
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
                                    
                                    Image(systemName: droppedLoot.getIconName())
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
                        if players.isEmpty {
                            Text("Searching rank updates...")
                                .font(.caption)
                                .foregroundColor(Theme.textMuted)
                                .padding(.top, 40)
                        } else {
                            ForEach(Array(players.enumerated()), id: \.offset) { index, player in
                                HStack(spacing: 12) {
                                    RankIndicator(rank: index + 1)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(player.username)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.textPrimary)
                                        Text("Lvl \(player.level) • \(player.selectedClass.rawValue)")
                                            .font(.caption2)
                                            .foregroundColor(player.selectedClass.themeColor)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Label("\(player.pvpTrophies)", systemImage: "trophy.fill")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(Theme.healerColor)
                                            .fontWeight(.bold)
                                        
                                        Text("\(player.pvpWins) Wins")
                                            .font(.system(size: 10, design: .default))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                .padding()
                                .background(Theme.cardBackground.opacity(0.85))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 60)
                }
            }
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
            }
            .padding(.horizontal)
            
            Button("CANCEL") {
                onCancel()
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(Theme.danger)
            .fontWeight(.bold)
            .padding(.top, 8)
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
    
    let friends = ["AquaHealer", "FireMage", "WindArcher", "KnightDave"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("INVITE STORY COMPANION")
                .font(.system(.headline, design: .monospaced))
                .fontWeight(.black)
                .foregroundColor(Theme.textPrimary)
                .tracking(1.5)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(friends, id: \.self) { friend in
                        let friendClass: CharacterClass = friend == "AquaHealer" ? .healer : (friend == "FireMage" ? .mage : (friend == "WindArcher" ? .archer : .swordsman))
                        HStack {
                            Circle()
                                .fill(friendClass.themeColor.opacity(0.15))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(friendClass.themeColor)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.textPrimary)
                                Text("Online • Lvl 12 \(friendClass.rawValue)")
                                    .font(.system(size: 8))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                invitedFriend = friend
                                onCompleted()
                            }) {
                                Text("INVITE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(Theme.primary)
                                    .cornerRadius(8)
                            }
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
            
            Button("CANCEL") {
                onCancel()
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(Theme.danger)
            .fontWeight(.bold)
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
                    ZStack {
                        // 1. Winding Road Path connecting coordinates (Zigzag 40 nodes)
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
                            .position(x: coord.x, y: coord.y)
                            .id(stage)
                        }
                    }
                    .frame(width: 360, height: 4510) // 40 stages * 110 spacing + margins
                    .padding(.top, 100)
                    .padding(.bottom, 100)
                    .onAppear {
                        // Scroll to active stage on load
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 1.2)) {
                                scrollProxy.scrollTo(activeStage, anchor: .center)
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
                                ? (isVolcanic
                                    ? [Color(red: 0.22, green: 0.22, blue: 0.24), Color(red: 0.12, green: 0.12, blue: 0.14)] // volcanic black obsidian
                                    : [Theme.success, Color(red: 0.18, green: 0.65, blue: 0.28)] // pasture forest grass green
                                  )
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
                            Image(systemName: "skull.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(isUnlocked ? Theme.danger : .white.opacity(0.7))
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
                
                Text(isBoss ? "BOSS" : "STAGE \(stage)")
                    .font(.system(size: 8, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(isUnlocked ? Theme.textPrimary : Theme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(4)
            }
        }
        .buttonStyle(PlainButtonStyle())
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
    @Environment(\.dismiss) private var dismiss
    
    private var isBoss: Bool { stage % 10 == 0 }
    
    // Choose two eligible exercises for the stage
    private var eligibleExercises: [CharacterClass] {
        switch stage % 3 {
        case 0: return [.archer, .mage]      // Squats & Push-ups
        case 1: return [.mage, .swordsman]   // Push-ups & Pull-ups
        default: return [.swordsman, .healer] // Pull-ups & Dips
        }
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
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 6) {
                Text(isBoss ? "🔥 BOSS PREPARATION 🔥" : "PREPARATION ARENA")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.black)
                    .foregroundColor(isBoss ? Theme.danger : Theme.primary)
                    .tracking(2)
                
                Text("STAGE \(stage): \(stageName(for: stage).uppercased())")
                    .font(.title3)
                    .fontWeight(.black)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.top, 24)
            
            // Countdown Timer Card
            VStack(spacing: 8) {
                Text("STARTING WORKOUT IN")
                    .font(.system(size: 10, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textSecondary)
                
                Text("\(timeRemaining)")
                    .font(.system(size: 64, weight: .black, design: .monospaced))
                    .foregroundColor(isBoss ? Theme.danger : Theme.healerColor)
                    .glow(color: (isBoss ? Theme.danger : Theme.healerColor).opacity(0.4), radius: 10)
                
                Text("SECONDS")
                    .font(.system(size: 10, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassmorphicCard()
            .padding(.horizontal)
            
            // Target HP indicator
            VStack(spacing: 4) {
                HStack {
                    Text("STAGE TARGET HP")
                        .font(.system(size: 9, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(bossMaxHP) HP")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 4)
                
                // Show HP Bar preview
                RoundedRectangle(cornerRadius: 6)
                    .fill(isBoss ? Theme.danger : Theme.primary)
                    .frame(height: 8)
                    .glow(color: (isBoss ? Theme.danger : Theme.primary).opacity(0.3), radius: 4)
            }
            .padding(.horizontal)
            
            // Exercise choices
            VStack(alignment: .leading, spacing: 10) {
                Text("CHOOSE YOUR COMBAT ATTACK:")
                    .font(.system(size: 10, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 4)
                
                ForEach(0..<eligibleExercises.count, id: \.self) { idx in
                    let cls = eligibleExercises[idx]
                    let isSelected = selectedExerciseIndex == idx
                    let rawDMG = damagePerRep(for: cls)
                    let dmg = isCoop ? Int(Double(rawDMG) * 1.25) : rawDMG // 25% co-op damage buff!
                    let repsNeeded = Int(ceil(Double(bossMaxHP) / Double(dmg)))
                    
                    Button(action: {
                        selectedExerciseIndex = idx
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(cls.themeColor.opacity(isSelected ? 0.25 : 0.08))
                                    .frame(width: 38, height: 38)
                                
                                Image(systemName: classIcon(for: cls))
                                    .foregroundColor(cls.themeColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cls.rawValue.uppercased())
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.textPrimary)
                                Text("\(cls.primaryExercise) (+\(dmg) DMG/Rep)")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(repsNeeded) Reps")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.black)
                                    .foregroundColor(cls.themeColor)
                                
                                if isCoop {
                                    Text("+25% Co-op Buff")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(Theme.success)
                                }
                            }
                        }
                        .padding()
                        .background(isSelected ? Theme.secondaryCard.opacity(0.85) : Theme.cardBackground.opacity(0.6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? cls.themeColor : Theme.border, lineWidth: isSelected ? 2 : 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 10) {
                Button(action: {
                    startWorkout()
                }) {
                    Text("SKIP & START WORKOUT")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .tracking(1.5)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(eligibleExercises[selectedExerciseIndex].themeColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: eligibleExercises[selectedExerciseIndex].themeColor.opacity(0.35), radius: 8, y: 4)
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("CANCEL EXPEDITION")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.danger)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
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
            Theme.background
                .ignoresSafeArea()
            
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
                        .buttonStyle(PlainButtonStyle())
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
