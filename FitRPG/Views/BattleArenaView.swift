import SwiftUI

struct BattleArenaView: View {
    @StateObject private var viewModel = BattleVM()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            if viewModel.isSearching {
                MatchmakingQueueView(cancelAction: viewModel.cancelQueue)
            } else if let battle = viewModel.activeBattle {
                CombatArenaView(battle: battle, viewModel: viewModel)
            } else {
                QueueSelectorView(startAction: viewModel.startQueue)
            }
        }
        .sheet(isPresented: $viewModel.showCameraTracker) {
            CameraTrackingView(selectedClass: viewModel.currentClass)
        }
        .overlay(
            Group {
                if viewModel.duelFinished {
                    DuelResultOverlay(winnerTitle: viewModel.winnerName, closeAction: viewModel.endMatch)
                }
            }
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 1. Selector view before queuing
struct QueueSelectorView: View {
    let startAction: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                Spacer()
                Text("PVP ARENA")
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                // Balanced spacer
                Image(systemName: "chevron.left").opacity(0)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            Spacer()
            
            // Central illustration / Badge
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .glow(color: Theme.accent.opacity(0.4), radius: 15)
                
                Image(systemName: "sword.and.shield.flightpath")
                    .font(.system(size: 64))
                    .foregroundColor(Theme.accent)
            }
            
            VStack(spacing: 8) {
                Text("REAL-TIME DUEL")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                
                Text("Match with online players and perform your class exercises in a 60-second race to defeat each other.")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            Button(action: startAction) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("FIND MATCH")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.accent)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Theme.accent.opacity(0.4), radius: 10, y: 5)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}

// 2. Radar-pulse queue screen
struct MatchmakingQueueView: View {
    let cancelAction: () -> Void
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            ZStack {
                // Pulse waves
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
                Text("Searching for Opponent...")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
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

// 3. Combat Arena Arena
struct CombatArenaView: View {
    let battle: Battle
    @ObservedObject var viewModel: BattleVM
    
    var body: some View {
        VStack(spacing: 16) {
            // Timer & Status Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DUEL IN PROGRESS")
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
            
            // Fighter Grid
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
            .background(Theme.cardBackground)
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
            
            // Class symbol / icon
            ZStack {
                Circle()
                    .fill(player.characterClass.themeColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "figure.walk")
                    .font(.title3)
                    .foregroundColor(player.characterClass.themeColor)
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
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(event.detailText)
                        .foregroundColor(Theme.textSecondary)
                }
                .font(.system(size: 11, design: .monospaced))
            }
        }
        .padding(.horizontal)
    }
}

// 4. Overlaid stats summary card
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
                        RewardBadge(icon: "star.fill", color: Theme.success, label: "+150 XP")
                        RewardBadge(icon: "centsign.circle.fill", color: Theme.healerColor, label: "+40 Gold")
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

struct RewardBadge: View {
    let icon: String
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
        }
    }
}
struct BattleArenaView_Previews: PreviewProvider {
    static var previews: some View {
        BattleArenaView()
    }
}
