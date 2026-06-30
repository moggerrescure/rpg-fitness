import SwiftUI

struct CameraTrackingView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @StateObject private var viewModel: CameraTrackingVM
    @Environment(\.dismiss) private var dismiss
    @State private var isWorkoutStarted: Bool
    @State private var workoutCompletionRewards: (xp: Int, gold: Int)? = nil
    
    @State private var combatEffects: [CombatSpellEffect] = []
    @State private var screenShake: Bool = false
    @State private var activeDebuff: CharacterClass? = nil
    @State private var debuffTask: Task<Void, Never>? = nil
    @State private var showHitOverlay: Bool = false
    
    let bossName: String?
    let bossImage: String?
    
    init(selectedClass: CharacterClass, targetReps: Int? = nil, bossMaxHP: Int? = nil, damagePerRep: Int? = nil, bossName: String? = nil, bossImage: String? = nil, onComplete: ((Int) -> Void)? = nil) {
        self.bossName = bossName
        self.bossImage = bossImage
        let hasFirebaseBattle = FirebaseService.shared.activeBattle != nil
        let hasEngineBattle = BattleEngine.shared.activeBattle != nil
        let isEngineBoss = BattleEngine.shared.activeBoss != nil
        let engineBossHP = BattleEngine.shared.activeBoss?.maxHealth
        
        let hasBoss = (bossMaxHP ?? 0) > 0 || isEngineBoss
        self._isWorkoutStarted = State(initialValue: hasFirebaseBattle || hasEngineBattle || hasBoss)
        
        let finalBossHP = bossMaxHP ?? engineBossHP
        let finalDamage = damagePerRep ?? (isEngineBoss ? Int(Double(FirebaseService.shared.currentCharacter?.combatPower ?? 10) * 0.15) : nil)
        
        _viewModel = StateObject(wrappedValue: CameraTrackingVM(selectedClass: selectedClass, targetReps: targetReps, bossMaxHP: finalBossHP, damagePerRep: finalDamage, bossName: bossName, bossImage: bossImage, onComplete: onComplete))
    }
    
    var body: some View {
        ZStack {
            // Camera feed backdrop (training ruins animated background)
            AnimatedBackgroundView(backgroundType: .trainingRuins)
                .ignoresSafeArea()
            
            if !isWorkoutStarted {
                // Pre-Workout Camp View
                VStack(spacing: 24) {
                    // Close button
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    VStack(spacing: 24) {
                        // Title
                        Text("\(viewModel.selectedClass.rawValue.uppercased()) CAMP")
                            .font(.system(.title, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .tracking(2.5)
                            .glow(color: viewModel.selectedClass.themeColor.opacity(0.5), radius: 10)
                        
                        // Class emblem representation
                        ZStack {
                            Circle()
                                .fill(viewModel.selectedClass.themeColor.opacity(0.15))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Circle()
                                        .stroke(viewModel.selectedClass.themeColor, lineWidth: 2)
                                )
                                .glow(color: viewModel.selectedClass.themeColor.opacity(0.4), radius: 12)
                            
                            Image(systemName: classEmblem(for: viewModel.selectedClass))
                                .font(.system(size: 56))
                                .foregroundColor(viewModel.selectedClass.themeColor)
                        }
                        .padding(.vertical, 10)
                        
                        // Instructions card
                        VStack(spacing: 12) {
                            Text("TRAINING EXERCISE")
                                .font(.system(size: 10, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1.5)
                            
                            Text(viewModel.selectedClass.primaryExercise.uppercased())
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(Theme.textPrimary)
                            
                            if let target = viewModel.targetReps {
                                HStack(spacing: 6) {
                                    Image(systemName: "target")
                                    Text("OBJECTIVE: \(target) REPS")
                                }
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.healerColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Theme.healerColor.opacity(0.12))
                                .cornerRadius(12)
                                .padding(.top, 4)
                            } else {
                                Text("PRACTICE MODE • UNLIMITED")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Theme.textMuted)
                            }
                            
                            Text(viewModel.selectedClass.description)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                        .padding(20)
                        .background(Theme.cardBackground.opacity(0.85))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // START TRAINING CTA
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isWorkoutStarted = true
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                Text("START TRAINING")
                                    .fontWeight(.black)
                                    .tracking(1.5)
                            }
                            .font(.system(.subheadline, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.selectedClass.themeColor)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                            .glow(color: viewModel.selectedClass.themeColor.opacity(0.4), radius: 8)
                        }
                        .buttonStyle(TactileButtonStyle())
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                }
            } else {
                // Active Workout view (uses camera)
                GeometryReader { geo in
                    let isBattle = (viewModel.bossMaxHP > 0) || (FirebaseService.shared.activeBattle != nil) || (BattleEngine.shared.activeBattle != nil)
                    
                    if isBattle {
                        let battle = MultiplayerService.shared.activeBattle ?? BattleEngine.shared.activeBattle
                        VStack(spacing: 0) {
                            // Top Half: Opponent Combat Area
                            ZStack {
                                // Dynamic background
                                AnimatedBackgroundView(backgroundType: .arena)
                                    .brightness(-0.15)
                                
                                // Boss / Opponent representation
                                VStack(spacing: 12) {
                                    Spacer()
                                    
                                    if let battle = battle, let opponent = battle.opponentTeam.first {
                                        // Opponent Info: Name, Class, level
                                        VStack(spacing: 4) {
                                            Text(opponent.name.uppercased())
                                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                                .foregroundColor(.white)
                                                .glow(color: opponent.characterClass.themeColor.opacity(0.4), radius: 5)
                                            Text(opponent.characterClass.rawValue.uppercased())
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundColor(opponent.characterClass.themeColor)
                                                .tracking(1)
                                        }
                                        
                                        // Health Bar
                                        let hpProgress = CGFloat(opponent.health) / CGFloat(opponent.maxHealth)
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.black.opacity(0.75))
                                                .frame(width: 200, height: 10)
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(opponent.characterClass.themeColor)
                                                .frame(width: 200 * hpProgress, height: 10)
                                                .glow(color: opponent.characterClass.themeColor.opacity(0.6), radius: 4)
                                        }
                                        .frame(width: 200)
                                        
                                        // Health Text
                                        Text("HP: \(opponent.health) / \(opponent.maxHealth)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.85))
                                        
                                        // Opponent Avatar (Large and gorgeous)
                                        ZStack {
                                            Circle()
                                                .fill(opponent.characterClass.themeColor.opacity(0.12))
                                                .frame(width: 100, height: 100)
                                                .overlay(Circle().stroke(opponent.characterClass.themeColor, lineWidth: 2))
                                                .glow(color: opponent.characterClass.themeColor.opacity(0.3), radius: 8)
                                            
                                            if let avatar = opponent.avatarName, let uiImage = loadLocalAvatar(named: avatar) {
                                                Image(platformImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 96, height: 96)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: "person.crop.circle.fill")
                                                    .font(.system(size: 80))
                                                    .foregroundColor(opponent.characterClass.themeColor)
                                            }
                                            
                                            // Red Damage Overlay & Shake
                                            if showHitOverlay {
                                                Circle()
                                                    .fill(Color.red.opacity(0.4))
                                                    .frame(width: 100, height: 100)
                                            }
                                        }
                                        .scaleEffect(showHitOverlay ? 1.15 : 1.0)
                                        .offset(x: showHitOverlay ? CGFloat.random(in: -8...8) : 0)
                                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: showHitOverlay)
                                    } else if viewModel.bossMaxHP > 0 {
                                        // World Boss info
                                        VStack(spacing: 4) {
                                            Text(bossName?.uppercased() ?? "WORLD BOSS")
                                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                                .foregroundColor(Theme.danger)
                                                .glow(color: Theme.danger.opacity(0.4), radius: 5)
                                        }
                                        
                                        // Boss Health Bar
                                        let hpProgress = CGFloat(viewModel.bossCurrentHP) / CGFloat(max(1, viewModel.bossMaxHP))
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.black.opacity(0.75))
                                                .frame(width: 200, height: 10)
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Theme.danger)
                                                .frame(width: 200 * hpProgress, height: 10)
                                                .glow(color: Theme.danger.opacity(0.6), radius: 4)
                                        }
                                        .frame(width: 200)
                                        
                                        // Health Text
                                        Text("HP: \(viewModel.bossCurrentHP) / \(viewModel.bossMaxHP)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.85))
                                        
                                        // Boss Avatar
                                        ZStack {
                                            Circle()
                                                .fill(Theme.danger.opacity(0.12))
                                                .frame(width: 100, height: 100)
                                                .overlay(Circle().stroke(Theme.danger, lineWidth: 2))
                                                .glow(color: Theme.danger.opacity(0.3), radius: 8)
                                            
                                            if let bImg = bossImage {
                                                Image(bImg)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 96, height: 96)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: "shield.fill")
                                                    .font(.system(size: 80))
                                                    .foregroundColor(Theme.danger)
                                            }
                                            
                                            BossDebuffOverlay(debuff: activeDebuff)
                                                .frame(width: 100, height: 100)
                                            
                                            if showHitOverlay {
                                                Circle()
                                                    .fill(Color.red.opacity(0.45))
                                                    .frame(width: 100, height: 100)
                                            }
                                        }
                                        .scaleEffect(showHitOverlay ? 1.15 : 1.0)
                                        .offset(x: showHitOverlay ? CGFloat.random(in: -8...8) : 0)
                                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: showHitOverlay)
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Flying spells overhead
                                ForEach(combatEffects) { effect in
                                    SpellEffectView(effect: effect)
                                }
                                
                                // Back Button & Timer
                                VStack {
                                    HStack {
                                        Button(action: {
                                            withAnimation { isWorkoutStarted = false }
                                        }) {
                                            Image(systemName: "arrow.left")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .frame(width: 44, height: 44)
                                                .background(Color.black.opacity(0.4))
                                                .clipShape(Circle())
                                        }
                                        Spacer()
                                        
                                        // Timer overlay if battle is present
                                        if let battle = battle {
                                            Text("\(battle.secondsRemaining)s")
                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.black.opacity(0.5))
                                                .cornerRadius(10)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 10)
                                    
                                    Spacer()
                                }
                            }
                            .frame(height: geo.size.height * 0.45)
                            .offset(x: screenShake ? CGFloat.random(in: -7...7) : 0, y: screenShake ? CGFloat.random(in: -5...5) : 0)
                            
                            // Golden separator line
                            Rectangle()
                                .fill(LinearGradient(colors: [Theme.healerColor, Theme.healerColor.opacity(0.3), Theme.healerColor], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 3)
                                .shadow(color: Theme.healerColor.opacity(0.6), radius: 4)
                            
                            // Bottom Half: User Camera
                            ZStack(alignment: .bottom) {
                                CameraPreview(session: viewModel.cameraManager.session)
                                    .frame(height: geo.size.height * 0.55)
                                    .clipped()
                                
                                PoseOverlayView(joints: viewModel.rawJoints, themeColor: viewModel.selectedClass.themeColor)
                                    .frame(height: geo.size.height * 0.55)
                                
                                VStack {
                                    Spacer()
                                    
                                    liveFeedbackPrompt
                                        .padding(.bottom, 6)
                                    
                                    repsDisplay
                                        .padding(.bottom, 16)
                                }
                            }
                            .frame(height: geo.size.height * 0.55)
                        }
                    } else {
                        // Normal Training Layout
                        ZStack {
                            CameraPreview(session: viewModel.cameraManager.session)
                                .ignoresSafeArea()
                                
                            PoseOverlayView(joints: viewModel.rawJoints, themeColor: viewModel.selectedClass.themeColor)
                            
                            VStack(spacing: 0) {
                                // Top 20% - Status and Reps
                                VStack(spacing: 16) {
                                    // Back button and Live Rewards
                                    HStack {
                                        Button(action: {
                                            withAnimation { isWorkoutStarted = false }
                                        }) {
                                            Image(systemName: "arrow.left")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .frame(width: 44, height: 44)
                                                .background(Color.black.opacity(0.4))
                                                .clipShape(Circle())
                                        }
                                        
                                        Spacer()
                                        
                                        // Live Rewards Preview
                                        if viewModel.repCount > 0 {
                                            HStack(spacing: 14) {
                                                // XP
                                                HStack(spacing: 4) {
                                                    Image(systemName: "star.fill")
                                                        .foregroundColor(Color.yellow)
                                                        .font(.system(size: 12))
                                                    Text("+\(10 + viewModel.repCount * 6)")
                                                        .foregroundColor(.white)
                                                        .fontWeight(.black)
                                                }
                                                
                                                // Gold
                                                HStack(spacing: 4) {
                                                    Image(systemName: "centsign.circle.fill")
                                                        .foregroundColor(Theme.warning)
                                                        .font(.system(size: 12))
                                                    Text("+\(3 + Int(Double(viewModel.repCount) * 1.5))")
                                                        .foregroundColor(.white)
                                                        .fontWeight(.black)
                                                }
                                            }
                                            .font(.system(size: 14, design: .monospaced))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.black.opacity(0.5))
                                            .cornerRadius(20)
                                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.15), lineWidth: 1))
                                            .transition(.opacity)
                                            .animation(.easeInOut, value: viewModel.repCount)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 10)
                                    
                                    // Exercise Name and Big Number
                                    HStack(alignment: .center) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("CURRENT EXERCISE")
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundColor(Theme.textSecondary)
                                                
                                            Text(viewModel.selectedClass.primaryExercise.uppercased())
                                                .font(.system(size: 32, weight: .black, design: .monospaced))
                                                .foregroundColor(viewModel.selectedClass.themeColor)
                                                .shadow(color: viewModel.selectedClass.themeColor.opacity(0.5), radius: 5)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(viewModel.repCount)")
                                            .font(.system(size: 80, weight: .black, design: .monospaced))
                                            .foregroundColor(.white)
                                            .shadow(color: viewModel.selectedClass.themeColor.opacity(0.8), radius: 15)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 20)
                                }
                                .background(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.9), Color.black.opacity(0.7), .clear],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                    .ignoresSafeArea(edges: .top)
                                )
                                
                                Spacer()
                                
                                // Bottom HUD
                                VStack(spacing: 16) {
                                    liveFeedbackPrompt
                                    finishWorkoutCTA
                                    guidanceStateInfo
                                }
                                .padding(.bottom, 30)
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [.clear, Color.black.opacity(0.8)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                    .ignoresSafeArea(edges: .bottom)
                                )
                            }
                        }
                    }
                }
            }
            // Workout Completion / Rewards Overlay (visual match to StageWinOverlay)
            if let rewards = workoutCompletionRewards {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                    
                    // Golden sun rays background overlay
                    GeometryReader { sunGeo in
                        ZStack {
                            ForEach(0..<4) { idx in
                                Path { path in
                                    path.move(to: CGPoint(x: sunGeo.size.width * 0.5, y: sunGeo.size.height * 0.5))
                                    path.addLine(to: CGPoint(x: sunGeo.size.width * (0.2 + CGFloat(idx) * 0.2), y: 0))
                                    path.addLine(to: CGPoint(x: sunGeo.size.width * (0.35 + CGFloat(idx) * 0.2), y: 0))
                                    path.closeSubpath()
                                }
                                .fill(Theme.warning.opacity(0.04))
                            }
                            ForEach(0..<4) { idx in
                                Path { path in
                                    path.move(to: CGPoint(x: sunGeo.size.width * 0.5, y: sunGeo.size.height * 0.5))
                                    path.addLine(to: CGPoint(x: sunGeo.size.width * (0.2 + CGFloat(idx) * 0.2), y: sunGeo.size.height))
                                    path.addLine(to: CGPoint(x: sunGeo.size.width * (0.35 + CGFloat(idx) * 0.2), y: sunGeo.size.height))
                                    path.closeSubpath()
                                }
                                .fill(Theme.warning.opacity(0.04))
                            }
                        }
                    }
                    .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("TRAINING COMPLETED!")
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundColor(Theme.success)
                                .glow(color: Theme.success.opacity(0.5), radius: 10)
                            
                            Text("You performed \(viewModel.repCount) repetitions of \(viewModel.selectedClass.primaryExercise.uppercased()) in the training camp.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        VStack(spacing: 16) {
                            Text("REWARDS EARNED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                                .tracking(1)
                            
                            HStack(spacing: 16) {
                                // XP Reward Card
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.success.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: "star.fill")
                                            .font(.title3)
                                            .foregroundColor(Theme.success)
                                    }
                                    .glow(color: Theme.success.opacity(0.35), radius: 5)
                                    
                                    Text("+\(rewards.xp) XP")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .fontWeight(.black)
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text("Class XP")
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.secondaryCard.opacity(0.6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.success.opacity(0.2), lineWidth: 1)
                                )
                                
                                // Gold Reward Card
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.warning.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: "centsign.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(Theme.warning)
                                    }
                                    .glow(color: Theme.warning.opacity(0.35), radius: 5)
                                    
                                    Text("+\(rewards.gold) GOLD")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .fontWeight(.black)
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text("Currency")
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.secondaryCard.opacity(0.6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.warning.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            workoutCompletionRewards = nil
                            dismiss()
                        }) {
                            Text("RETURN TO HUB")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Theme.primary)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .glow(color: Theme.primary.opacity(0.4), radius: 8)
                        }
                        .buttonStyle(TactileButtonStyle())
                        .padding(.horizontal)
                    }
                    .padding(24)
                    .background(Theme.cardBackground.opacity(0.92))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.warning.opacity(0.5), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .glow(color: Theme.warning.opacity(0.15), radius: 15)
                    .padding(.horizontal, 28)
                }
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .hideNavigationBar()
        .onAppear {
            if FirebaseService.shared.activeBattle != nil || viewModel.bossMaxHP > 0 {
                isWorkoutStarted = true
            }
            viewModel.cameraManager.checkPermission()
        }
        .onDisappear {
            viewModel.cameraManager.stopSession()
        }
        .onChange(of: viewModel.repCount) { oldVal, newVal in
            guard newVal > oldVal else { return }
            withAnimation(.spring(response: 0.15, dampingFraction: 0.45)) {
                screenShake = true
                showHitOverlay = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                screenShake = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation {
                    showHitOverlay = false
                }
            }
            
            // Trigger status debuff on boss based on current class
            debuffTask?.cancel()
            activeDebuff = viewModel.selectedClass
            debuffTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
                if !Task.isCancelled {
                    await MainActor.run {
                        activeDebuff = nil
                    }
                }
            }
            
            let newEffect = CombatSpellEffect(
                type: viewModel.selectedClass,
                startPoint: CGPoint(x: CGFloat.random(in: 80...300), y: 620),
                endPoint: CGPoint(x: 180, y: 140)
            )
            withAnimation {
                combatEffects.append(newEffect)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                combatEffects.removeAll(where: { $0.id == newEffect.id })
            }
        }
    }
    
    private func classEmblem(for cls: CharacterClass) -> String {
        switch cls {
        case .archer: return "arrow.up.forward.app.fill"
        case .mage: return "bolt.heart.fill"
        case .swordsman: return "hammer.fill"
        case .healer: return "cross.case.fill"
        }
    }

    // MARK: - Extracted HUD Components
    
    private var topControlsBar: some View {
        HStack {
            Button(action: {
                if FirebaseService.shared.activeBattle != nil || BattleEngine.shared.activeBattle != nil || viewModel.bossMaxHP > 0 {
                    dismiss()
                } else {
                    withAnimation {
                        isWorkoutStarted = false
                    }
                }
            }) {
                Image(systemName: "arrow.left")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Exercise indicator
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(viewModel.selectedClass.themeColor)
                Text(viewModel.selectedClass.primaryExercise.uppercased())
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.4))
            .cornerRadius(20)
            
            Spacer()
            
            Color.clear.frame(width: 44) // Balance the back button
        }
        .padding(.horizontal)
    }
    
    private var bossInfoSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                if let bossImage = bossImage {
                    ZStack {
                        Image(bossImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .shadow(color: Theme.danger.opacity(0.5), radius: 6)
                        
                        BossDebuffOverlay(debuff: activeDebuff)
                            .frame(width: 56, height: 56)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    if let bossName = bossName {
                        Text(bossName.uppercased())
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.danger)
                    }
                    
                    Text("\(viewModel.bossCurrentHP) / \(viewModel.bossMaxHP) HP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
            }
            
            // HP bar
            GeometryReader { barGeo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.6))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            colors: viewModel.hpBarBurn ? [.red, .orange, .yellow] : [Color.red, Color.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: CGFloat(viewModel.bossCurrentHP) / CGFloat(max(1, viewModel.bossMaxHP)) * barGeo.size.width)
                        .glow(color: viewModel.hpBarBurn ? .orange.opacity(0.8) : .red.opacity(0.4), radius: viewModel.hpBarBurn ? 6 : 3)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.danger.opacity(0.3), lineWidth: 1)
        )
        .offset(x: viewModel.hpBarShake ? CGFloat.random(in: -5...5) : 0, y: viewModel.hpBarShake ? CGFloat.random(in: -5...5) : 0)
        .padding(.horizontal, 14)
    }
    
    @ViewBuilder
    private var pvpMatchupSection: some View {
        if let battle = MultiplayerService.shared.activeBattle ?? BattleEngine.shared.activeBattle {
            VStack(spacing: 8) {
                // 1. Matchup header
                HStack(alignment: .top, spacing: 12) {
                    // Player side
                    if let player = battle.localTeam.first {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                if let avatar = player.avatarName, let uiImage = loadLocalAvatar(named: avatar) {
                                    Image(platformImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                }
                                VStack(alignment: .leading) {
                                    Text(player.name)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(player.characterClass.rawValue.uppercased())
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundColor(player.characterClass.themeColor)
                                }
                            }
                            // Health bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.black.opacity(0.6))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(player.characterClass.themeColor)
                                        .frame(width: CGFloat(player.health) / CGFloat(player.maxHealth) * geo.size.width)
                                }
                            }
                            .frame(height: 5)
                            Text("HP: \(player.health)/\(player.maxHealth)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // VS & Timer
                    VStack(spacing: 2) {
                        Text("VS")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.warning)
                        
                        Text("\(battle.secondsRemaining)s")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                    
                    // Opponent side
                    if let opponent = battle.opponentTeam.first {
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 6) {
                                VStack(alignment: .trailing) {
                                    Text(opponent.name)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(opponent.characterClass.rawValue.uppercased())
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundColor(opponent.characterClass.themeColor)
                                }
                                if let avatar = opponent.avatarName, let uiImage = loadLocalAvatar(named: avatar) {
                                    Image(platformImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                }
                            }
                            // Health bar
                            GeometryReader { geo in
                                ZStack(alignment: .trailing) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.black.opacity(0.6))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(opponent.characterClass.themeColor)
                                        .frame(width: CGFloat(opponent.health) / CGFloat(opponent.maxHealth) * geo.size.width)
                                }
                            }
                            .frame(height: 5)
                            Text("HP: \(opponent.health)/\(opponent.maxHealth)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                
                // 3v3 party members list (compact status indicators)
                if battle.type == .team3v3 {
                    HStack(spacing: 8) {
                        // Team allies health summary
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(battle.localTeam.dropFirst()) { ally in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(ally.characterClass.themeColor)
                                        .frame(width: 5, height: 5)
                                    Text(ally.name)
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(ally.health) HP")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(ally.health == 0 ? .red : .white.opacity(0.8))
                                }
                            }
                        }
                        .padding(5)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(6)
                        .frame(maxWidth: .infinity)
                        
                        // Opponents health summary
                        VStack(alignment: .trailing, spacing: 3) {
                            ForEach(battle.opponentTeam.dropFirst()) { opp in
                                HStack(spacing: 4) {
                                    Text(opp.name)
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Circle()
                                        .fill(opp.characterClass.themeColor)
                                        .frame(width: 5, height: 5)
                                    Text("\(opp.health) HP")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(opp.health == 0 ? .red : .white.opacity(0.8))
                                }
                            }
                        }
                        .padding(5)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(6)
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // 2. Real-time scrolling combat log
                VStack(alignment: .leading, spacing: 2) {
                    Text("PVP COMBAT EVENTS")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 4)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(battle.combatLog) { log in
                                HStack(alignment: .top, spacing: 3) {
                                    Text(">")
                                        .font(.system(size: 7, design: .monospaced))
                                        .foregroundColor(.gray)
                                    Text(log.actorName)
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text(log.detailText)
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                }
                .frame(height: 55)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.45))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal)
        }
    }
    
    private var liveFeedbackPrompt: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(viewModel.isPersonDetected ? Theme.success : Theme.danger)
                .frame(width: 10, height: 10)
                .glow(color: viewModel.isPersonDetected ? Theme.success : Theme.danger)
            
            Text(viewModel.feedbackMessage)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(viewModel.isCorrectForm ? Color.black.opacity(0.6) : Theme.danger.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(viewModel.isCorrectForm ? Theme.border : Theme.danger, lineWidth: 1)
        )
    }
    
    private var repsDisplay: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(viewModel.repCount)")
                    .font(.system(size: 96, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: viewModel.selectedClass.themeColor.opacity(0.6), radius: 15)
                
                if let target = viewModel.targetReps {
                    Text("/ \(target)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Text("REPS COMPLETED")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Theme.textSecondary)
                .tracking(3)
        }
    }
    
    @ViewBuilder
    private var finishWorkoutCTA: some View {
        if viewModel.bossMaxHP == 0 && FirebaseService.shared.activeBattle == nil {
            Button(action: {
                let earned = FirebaseService.shared.awardWorkoutRewards(reps: viewModel.repCount)
                withAnimation {
                    workoutCompletionRewards = earned
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("FINISH WORKOUT")
                        .fontWeight(.black)
                        .tracking(1)
                }
                .font(.system(.subheadline, design: .monospaced))
                .padding(.vertical, 14)
                .padding(.horizontal, 32)
                .background(Theme.success)
                .foregroundColor(.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .glow(color: Theme.success.opacity(0.4), radius: 8)
            }
            .buttonStyle(TactileButtonStyle())
            .padding(.bottom, 20)
        }
    }
    
    private var guidanceStateInfo: some View {
        VStack(spacing: 8) {
            Text("Ensure whole body is visible")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Text("Avoid shadows & backlit environments")
                .font(.caption2)
                .foregroundColor(Theme.textMuted)
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
        .padding(.bottom, 30)
    }


}

// Simulated skeletal line drawer
struct SimulatedCameraFeed: View {
    var body: some View {
        ZStack {
            // Training ruins animated background
            AnimatedBackgroundView(backgroundType: .trainingRuins)
                .ignoresSafeArea()
            
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Ambient glow backdrops
            RadialGradient(
                colors: [Theme.accent.opacity(0.15), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            // Grid lines overlay
            GeometryReader { geo in
                Path { path in
                    let gridSpacing: CGFloat = 40
                    for x in stride(from: 0, to: geo.size.width, by: gridSpacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: 0, to: geo.size.height, by: gridSpacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Theme.border.opacity(0.3), lineWidth: 0.5)
            }
        }
    }
}

// Custom button style toggle setup
struct ButtonToggleStyle: ToggleStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack {
                Image(systemName: configuration.isOn ? "cpu.fill" : "camera.fill")
                Text(configuration.isOn ? "SIM" : "LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isOn ? color : Color.black.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Spell Combat Animation Models & Shapes

struct CombatSpellEffect: Identifiable {
    let id = UUID()
    let type: CharacterClass
    let startPoint: CGPoint
    let endPoint: CGPoint
}

struct SpellEffectView: View {
    let effect: CombatSpellEffect
    @State private var currentProgress: CGFloat = 0.0
    @State private var showSparks: Bool = false
    
    var body: some View {
        ZStack {
            if !showSparks {
                ZStack {
                    if effect.type == .archer {
                        ArrowProjectileShape()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: 14, height: 40)
                            .glow(color: Color.green.opacity(0.8), radius: 6)
                    } else if effect.type == .swordsman {
                        SlashEffectShape()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 80, height: 80)
                            .glow(color: Color.blue.opacity(0.6), radius: 8)
                    } else if effect.type == .mage {
                        ZStack {
                            ForEach(0..<3) { idx in
                                Circle()
                                    .fill(Color.orange.opacity(0.3 - Double(idx) * 0.1))
                                    .frame(width: 24 - CGFloat(idx * 4), height: 24 - CGFloat(idx * 4))
                                    .offset(y: CGFloat(idx * 12))
                            }
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.red, .orange, .clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 18
                                    )
                                )
                                .frame(width: 36, height: 36)
                        }
                        .glow(color: Color.red.opacity(0.8), radius: 10)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(Color.yellow)
                            .glow(color: Color.yellow.opacity(0.8), radius: 10)
                    }
                }
                .position(
                    x: lerp(start: effect.startPoint.x, end: effect.endPoint.x, t: currentProgress),
                    y: lerp(start: effect.startPoint.y, end: effect.endPoint.y, t: currentProgress)
                )
                .opacity(currentProgress > 0.85 ? (1.0 - (currentProgress - 0.85) / 0.15) : 1.0)
            } else {
                ZStack {
                    ForEach(0..<6) { idx in
                        let angle = Double(idx) * (2.0 * .pi / 6.0)
                        let distance: CGFloat = 45.0
                        Circle()
                            .fill(effect.type == .archer ? Color.green : (effect.type == .swordsman ? Color.white : (effect.type == .mage ? Color.orange : Color.yellow)))
                            .frame(width: 6, height: 6)
                            .glow(color: (effect.type == .archer ? Color.green : Color.orange).opacity(0.6), radius: 4)
                            .position(
                                x: effect.endPoint.x + cos(angle) * distance * currentProgress,
                                y: effect.endPoint.y + sin(angle) * distance * currentProgress
                            )
                    }
                }
                .opacity(1.0 - Double(currentProgress))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                currentProgress = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSparks = true
                currentProgress = 0.0
                withAnimation(.easeOut(duration: 0.35)) {
                    currentProgress = 1.0
                }
            }
        }
    }
    
    private func lerp(start: CGFloat, end: CGFloat, t: CGFloat) -> CGFloat {
        start + (end - start) * t
    }
}

struct ArrowProjectileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY + 10))
        return path
    }
}

struct SlashEffectShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - Boss Status Effect Debuff Overlay

struct BossDebuffOverlay: View {
    let debuff: CharacterClass?
    
    var body: some View {
        ZStack {
            if let debuff = debuff {
                switch debuff {
                case .mage:
                    // Burning fire: orange embers floating up
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            for i in 0..<8 {
                                let xPercent = sin(t * 3.0 + Double(i)) * 0.15 + 0.5
                                let yPercent = 1.0 - (t * 0.4 + Double(i) * 0.15).truncatingRemainder(dividingBy: 1.0)
                                let currentSize = CGFloat(4 + (i % 3) * 2)
                                
                                let rect = CGRect(
                                    x: xPercent * size.width - currentSize/2,
                                    y: yPercent * size.height,
                                    width: currentSize,
                                    height: currentSize
                                )
                                context.drawLayer { ctx in
                                    ctx.opacity = 0.8
                                    ctx.addFilter(.shadow(color: .orange, radius: 4, x: 0, y: 0))
                                    var path = Path()
                                    path.addEllipse(in: rect)
                                    ctx.fill(path, with: .color(.orange))
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                    
                case .archer:
                    // Poison: green bubbles floating up
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            for i in 0..<6 {
                                let xPercent = cos(t * 2.0 + Double(i)) * 0.2 + 0.5
                                let yPercent = 1.0 - (t * 0.3 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1.0)
                                let currentSize = CGFloat(5 + (i % 4) * 2)
                                
                                let rect = CGRect(
                                    x: xPercent * size.width - currentSize/2,
                                    y: yPercent * size.height,
                                    width: currentSize,
                                    height: currentSize
                                )
                                context.drawLayer { ctx in
                                    ctx.opacity = 0.7
                                    var path = Path()
                                    path.addEllipse(in: rect)
                                    ctx.stroke(path, with: .color(.green), lineWidth: 1)
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                    
                case .healer:
                    // Holy stun: spinning gold star halo overhead
                    TimelineView(.animation) { timeline in
                        ZStack {
                            ForEach(0..<4) { i in
                                let angle = Double(i) * (.pi / 2.0) + timeline.date.timeIntervalSinceReferenceDate * 3.0
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.yellow)
                                    .glow(color: .yellow.opacity(0.7), radius: 3)
                                    .offset(x: cos(angle) * 16, y: -28 + sin(angle) * 5)
                            }
                        }
                    }
                    .transition(.opacity)
                    
                case .swordsman:
                    // Bleeding: red cross slash marks
                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: 10, y: 10))
                            path.addLine(to: CGPoint(x: 40, y: 40))
                            path.move(to: CGPoint(x: 40, y: 10))
                            path.addLine(to: CGPoint(x: 10, y: 40))
                        }
                        .stroke(Color.red, lineWidth: 2)
                        .glow(color: .red.opacity(0.8), radius: 5)
                        .frame(width: 50, height: 50)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}
