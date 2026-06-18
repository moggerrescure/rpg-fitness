import SwiftUI

struct CameraTrackingView: View {
    @StateObject private var viewModel: CameraTrackingVM
    @Environment(\.dismiss) private var dismiss
    @State private var isWorkoutStarted: Bool
    @State private var workoutCompletionRewards: (xp: Int, gold: Int)? = nil
    
    init(selectedClass: CharacterClass, targetReps: Int? = nil, bossMaxHP: Int? = nil, damagePerRep: Int? = nil, onComplete: ((Int) -> Void)? = nil) {
        let hasActiveBattle = FirebaseService.shared.activeBattle != nil
        let hasBoss = (bossMaxHP ?? 0) > 0
        self._isWorkoutStarted = State(initialValue: hasActiveBattle || hasBoss)
        
        _viewModel = StateObject(wrappedValue: CameraTrackingVM(selectedClass: selectedClass, targetReps: targetReps, bossMaxHP: bossMaxHP, damagePerRep: damagePerRep, onComplete: onComplete))
    }
    
    var body: some View {
        ZStack {
            // Camera feed backdrop (village animated background)
            AnimatedBackgroundView(backgroundType: .village)
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
                                    .fontWeight(.bold)
                                    .tracking(1.5)
                            }
                            .font(.system(.subheadline, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.selectedClass.themeColor)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: viewModel.selectedClass.themeColor.opacity(0.4), radius: 10, y: 5)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                }
            } else {
                // Active Workout view (uses camera or skeleton simulator)
                ZStack {
                    if !viewModel.isSimulatorMode {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                    }
                    
                    // Neon space grid background when simulating
                    if viewModel.isSimulatorMode {
                        SimulatedCameraFeed(points: viewModel.skeletonPoints, lines: viewModel.skeletonLines)
                    } else {
                        // Real camera placeholder
                        VStack {
                            Spacer()
                            Image(systemName: "camera.fill")
                                .font(.system(size: 64))
                                .foregroundColor(Theme.textMuted)
                            Text("Camera Feed Active")
                                .font(.headline)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.top, 8)
                            Text("Align your entire body in frame")
                                .font(.caption)
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                        }
                        
                        // Draw real skeleton keypoints overlay if detected
                        GeometryReader { geo in
                            ZStack {
                                ForEach(viewModel.skeletonLines) { line in
                                    Path { path in
                                        path.move(to: CGPoint(x: line.start.x * geo.size.width, y: line.start.y * geo.size.height))
                                        path.addLine(to: CGPoint(x: line.end.x * geo.size.width, y: line.end.y * geo.size.height))
                                    }
                                    .stroke(viewModel.selectedClass.themeColor, lineWidth: 4)
                                    .glow(color: viewModel.selectedClass.themeColor.opacity(0.8), radius: 6)
                                }
                                
                                ForEach(viewModel.skeletonPoints) { pt in
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 8)
                                        .position(x: pt.point.x * geo.size.width, y: pt.point.y * geo.size.height)
                                        .shadow(color: viewModel.selectedClass.themeColor, radius: 4)
                                }
                            }
                        }
                    }
                    
                    // HUD Overlay Controls
                    VStack {
                        // Top controls bar
                        HStack {
                            Button(action: {
                                if FirebaseService.shared.activeBattle != nil || viewModel.bossMaxHP > 0 {
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
                            
                            // Mode Toggle (Simulator vs Camera)
                            Toggle("Sim", isOn: $viewModel.isSimulatorMode)
                                .toggleStyle(ButtonToggleStyle(color: viewModel.selectedClass.themeColor))
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Top-anchored Boss HP Bar with shake and burn effects
                        if viewModel.bossMaxHP > 0 {
                            VStack(spacing: 4) {
                                HStack {
                                    Text("LEVEL BOSS HEALTH BAR")
                                        .font(.system(size: 9, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(viewModel.hpBarBurn ? .orange : Theme.textSecondary)
                                    
                                    Spacer()
                                    
                                    Text("\(viewModel.bossCurrentHP) / \(viewModel.bossMaxHP) HP")
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.black)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 4)
                                
                                GeometryReader { barGeo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.black.opacity(0.6))
                                            .frame(height: 10)
                                        
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient(
                                                colors: viewModel.hpBarBurn ? [.red, .orange, .yellow] : [Color.red, Color.orange],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(width: CGFloat(viewModel.bossCurrentHP) / CGFloat(viewModel.bossMaxHP) * barGeo.size.width, height: 10)
                                            .glow(color: viewModel.hpBarBurn ? .orange.opacity(0.8) : .red.opacity(0.4), radius: viewModel.hpBarBurn ? 6 : 3)
                                    }
                                }
                                .frame(height: 10)
                                
                                // Speed Cadence Combo badges dropping under the HP Bar
                                if let badge = viewModel.floatingComboBadge {
                                    Text(badge)
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.black)
                                        .foregroundColor(.yellow)
                                        .glow(color: .orange.opacity(0.5), radius: 5)
                                        .transition(.scale.combined(with: .opacity))
                                        .padding(.top, 4)
                                }
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.hpBarBurn ? Color.orange.opacity(0.5) : Theme.border, lineWidth: 1)
                            )
                            .offset(x: viewModel.hpBarShake ? CGFloat.random(in: -5...5) : 0, y: viewModel.hpBarShake ? CGFloat.random(in: -5...5) : 0)
                            .padding(.horizontal)
                            .padding(.top, 6)
                        }
                        
                        // Live Feedback Prompt
                        HStack(spacing: 12) {
                            Circle()
                                .fill(viewModel.isPersonDetected || viewModel.isSimulatorMode ? Theme.success : Theme.danger)
                                .frame(width: 10, height: 10)
                                .glow(color: viewModel.isPersonDetected || viewModel.isSimulatorMode ? Theme.success : Theme.danger)
                            
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
                        .padding(.top, 16)
                        
                        Spacer()
                        
                        // Huge reps display
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
                        
                        Spacer()
                        
                        // Finish Workout CTA (only in general solo training)
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
                                        .fontWeight(.bold)
                                }
                                .font(.system(.subheadline, design: .monospaced))
                                .padding(.vertical, 14)
                                .padding(.horizontal, 32)
                                .background(Theme.success)
                                .foregroundColor(.white)
                                .cornerRadius(24)
                                .shadow(color: Theme.success.opacity(0.4), radius: 8, y: 4)
                            }
                            .padding(.bottom, 20)
                        }
                        
                        // Bottom control actions
                        if viewModel.isSimulatorMode {
                            Button(action: {
                                viewModel.simulateRep()
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("SIMULATE REPETITION")
                                        .fontWeight(.bold)
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 32)
                                .background(viewModel.selectedClass.themeColor)
                                .foregroundColor(.white)
                                .cornerRadius(30)
                                .shadow(color: viewModel.selectedClass.themeColor.opacity(0.5), radius: 10, y: 5)
                            }
                            .padding(.bottom, 30)
                        } else {
                            // Guidance state info for physical setup
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
                }
            }
            
            // Workout Completion / Rewards Overlay (visual match to StageWinOverlay)
            if let rewards = workoutCompletionRewards {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        Text("TRAINING COMPLETED!")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.success)
                            .glow(color: Theme.success.opacity(0.5), radius: 10)
                        
                        Text("You performed \(viewModel.repCount) repetitions of \(viewModel.selectedClass.primaryExercise.uppercased()) in the training camp.")
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
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(Theme.success)
                                    Text(" Star XP (+\(rewards.xp))")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "centsign.circle.fill")
                                        .foregroundColor(Theme.healerColor)
                                    Text(" Gold Coins (+\(rewards.gold))")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.textPrimary)
                                }
                            }
                        }
                        .padding()
                        .background(Theme.secondaryCard)
                        .cornerRadius(12)
                        
                        Button(action: {
                            workoutCompletionRewards = nil
                            dismiss()
                        }) {
                            Text("RETURN TO HUB")
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
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .hideNavigationBar()
        .onAppear {
            if FirebaseService.shared.activeBattle != nil || viewModel.bossMaxHP > 0 {
                isWorkoutStarted = true
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
}

// Simulated skeletal line drawer
struct SimulatedCameraFeed: View {
    let points: [JointPoint]
    let lines: [BoneLine]
    
    var body: some View {
        ZStack {
            // Village animated background
            AnimatedBackgroundView(backgroundType: .village)
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
            
            // Render simulated avatar bones
            GeometryReader { geo in
                ZStack {
                    ForEach(lines) { line in
                        Path { path in
                            path.move(to: CGPoint(x: line.start.x * geo.size.width, y: line.start.y * geo.size.height))
                            path.addLine(to: CGPoint(x: line.end.x * geo.size.width, y: line.end.y * geo.size.height))
                        }
                        .stroke(Theme.primary, lineWidth: 5)
                        .glow(color: Theme.primary.opacity(0.6), radius: 8)
                    }
                    
                    ForEach(points) { pt in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .position(x: pt.point.x * geo.size.width, y: pt.point.y * geo.size.height)
                            .shadow(color: Theme.primary, radius: 6)
                    }
                }
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
