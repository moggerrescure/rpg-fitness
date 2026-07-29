import SwiftUI

struct TeamLobbyView: View {
    @EnvironmentObject var multiplayerService: MultiplayerService
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss
    
    var onBattleStarted: () -> Void
    
    @State private var countdown: Int = 20
    @State private var countdownTimer: Timer?
    @State private var showingStartPulse = false
    
    private var myChar: Character? { firebaseService.currentCharacter }
    
    var body: some View {
        ZStack {
            // Background
            AnimatedBackgroundView(backgroundType: .arena)
            Color.black.opacity(0.55).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text("3V3 TEAM LOBBY")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.warning.opacity(0.8))
                        .tracking(3)
                    Text("WAITING FOR YOUR SQUAD")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.black)
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.top, 60)
                .padding(.bottom, 36)
                
                // Team Slots
                VStack(spacing: 16) {
                    ForEach(multiplayerService.teamLobbySlots) { slot in
                        TeamSlotCard(slot: slot)
                    }
                    
                    // Empty placeholder slots
                    let filledCount = multiplayerService.teamLobbySlots.count
                    ForEach(filledCount..<3, id: \.self) { _ in
                        BotSlotCard(countdown: countdown)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Bot countdown info
                VStack(spacing: 6) {
                    Text("Empty slots fill with bots in")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(countdown)s")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(countdown <= 5 ? Theme.warning : Theme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring, value: countdown)
                }
                .padding(.bottom, 24)
                
                // Buttons
                VStack(spacing: 12) {
                    Button {
                        startBattle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.fill")
                            Text("START BATTLE NOW")
                                .fontWeight(.black)
                        }
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Theme.warning, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .scaleEffect(showingStartPulse ? 1.03 : 1.0)
                        .shadow(color: Theme.warning.opacity(0.4), radius: showingStartPulse ? 16 : 6)
                    }
                    .buttonStyle(TactileButtonStyle())
                    
                    Button {
                        cancelLobby()
                    } label: {
                        Text("Cancel Lobby")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(TactileButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear { startCountdown() }
        .onDisappear { countdownTimer?.invalidate() }
        .onChange(of: multiplayerService.activeBattle) { _, battle in
            if battle != nil {
                countdownTimer?.invalidate()
                dismiss()
                onBattleStarted()
            }
        }
    }
    
    private func startCountdown() {
        countdown = 10
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if self.countdown > 0 {
                    withAnimation { self.countdown -= 1 }
                } else {
                    self.countdownTimer?.invalidate()
                    self.startBattle()
                }
            }
        }
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            showingStartPulse = true
        }
    }
    
    private func startBattle() {
        countdownTimer?.invalidate()
        multiplayerService.startTeamBattleFromLobby()
    }
    
    private func cancelLobby() {
        countdownTimer?.invalidate()
        multiplayerService.leaveMatch()
        dismiss()
    }
}

// MARK: - Team Slot Card
struct TeamSlotCard: View {
    let slot: TeamSlot
    
    var body: some View {
        HStack(spacing: 14) {
            portrait
            
            VStack(alignment: .leading, spacing: 3) {
                Text(slot.displayName)
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)
                Text(statusLabel)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(statusColor)
            }
            
            Spacer()
            
            // Class badge for joined members / bots
            if case .joined(_, _, let cls) = slot.state {
                classBadge(cls)
            }
            if case .bot(_, let cls, _) = slot.state {
                classBadge(cls)
            }
            
            if case .me = slot.state {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.4), lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var portrait: some View {
        switch slot.state {
        case .me:
            BattlePortraitView(
                avatarName: FirebaseService.shared.currentCharacter?.avatarName,
                characterClass: FirebaseService.shared.currentCharacter?.selectedClass ?? .swordsman,
                size: 48,
                lineWidth: 1.5,
                showGlow: true
            )
        case .joined(_, _, let cls):
            BattlePortraitView(
                avatarName: cls.defaultAvatarName,
                characterClass: cls,
                size: 48,
                lineWidth: 1.5,
                showGlow: false
            )
        case .bot(_, let cls, let avatar):
            BattlePortraitView(
                avatarName: avatar,
                characterClass: cls,
                size: 48,
                lineWidth: 1.5,
                showGlow: true
            )
        case .invited:
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "clock.fill")
                    .font(.title3.bold())
                    .foregroundStyle(statusColor)
            }
        }
    }

    private func classBadge(_ cls: CharacterClass) -> some View {
        Text(cls.rawValue.uppercased())
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(cls.themeColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var statusColor: Color {
        switch slot.state {
        case .me: return .green
        case .invited: return Theme.warning
        case .joined: return .green
        case .bot: return Theme.primary
        }
    }
    
    private var statusLabel: String {
        switch slot.state {
        case .me: return "YOU • READY"
        case .invited(_, let name): return "WAITING FOR \(name.uppercased())…"
        case .joined(_, _, let cls): return "JOINED • \(cls.rawValue.uppercased())"
        case .bot(_, let cls, _): return "BOT ALLY • \(cls.rawValue.uppercased())"
        }
    }
}

// MARK: - Bot Slot Card (empty slot)
struct BotSlotCard: View {
    let countdown: Int
    
    private var preview: BotRoster.Identity {
        BotRoster.makeAlly(index: countdown % 4, preferredClass: countdown % 2 == 0 ? .healer : .mage)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            BattlePortraitView(
                avatarName: preview.avatarName,
                characterClass: preview.characterClass,
                size: 48,
                lineWidth: 1.5,
                showGlow: false
            )
            .opacity(0.55)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(preview.name)
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textSecondary.opacity(0.75))
                Text("BOT IN \(countdown)S • \(preview.characterClass.rawValue.uppercased())")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary.opacity(0.5))
                    .contentTransition(.numericText())
            }
            
            Spacer()
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border.opacity(0.3), lineWidth: 1)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
    }
}
