import SwiftUI

struct WorldBossDashboardView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @Binding var currentTab: Int
    @State private var showingBattleArena = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WORLD BOSS")
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: Theme.danger.opacity(0.8), radius: 10)
                            
                            Text("Cooperative Server Event")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        
                        Image(systemName: "flame.fill")
                            .font(.title)
                            .foregroundColor(Theme.danger)
                            .glow(color: Theme.danger.opacity(0.5), radius: 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    if let boss = firebaseService.activeWorldBoss {
                        if boss.isActive {
                            activeBossView(boss: boss)
                        } else {
                            defeatedBossView(boss: boss)
                        }
                    } else {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(Theme.danger)
                            Text("Summoning World Boss...")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(height: 300)
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .fullScreenCover(isPresented: $showingBattleArena) {
            BattleArenaView(initialPvPType: .bossRaid)
        }
    }
    
    @ViewBuilder
    private func activeBossView(boss: WorldBoss) -> some View {
        let template = Boss.templates.first { $0.id == boss.bossTemplateId } ?? Boss.templates.last!
        
        VStack(spacing: 24) {
            // Boss Avatar
            ZStack {
                Circle()
                    .fill(Theme.danger.opacity(0.1))
                    .frame(width: 180, height: 180)
                    .blur(radius: 20)
                
                Image(template.avatarName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.danger, lineWidth: 4))
                    .shadow(color: Theme.danger, radius: 15)
            }
            
            VStack(spacing: 8) {
                Text(template.name.uppercased())
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Health Bar
            VStack(spacing: 8) {
                HStack {
                    Text("GLOBAL HEALTH")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(boss.currentHealth) / \(boss.maxHealth)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                GeometryReader { geo in
                    let progress = max(0.0, min(1.0, CGFloat(boss.currentHealth) / CGFloat(boss.maxHealth)))
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.cardBackground)
                            .frame(height: 20)
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(gradient: Gradient(colors: [Theme.danger, Color.orange]), startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress, height: 20)
                            .animation(.spring(response: 0.5), value: progress)
                    }
                }
                .frame(height: 20)
            }
            .padding(.horizontal, 24)
            
            Button(action: {
                // Cost 15 energy
                if firebaseService.consumeEnergy(amount: 15) {
                    showingBattleArena = true
                }
            }) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("ATTACK BOSS (15 ENERGY)")
                        .fontWeight(.black)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient(gradient: Gradient(colors: [Theme.danger, Theme.danger.opacity(0.8)]), startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: Theme.danger.opacity(0.5), radius: 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Leaderboard
            leaderboardView(boss: boss)
        }
    }
    
    @ViewBuilder
    private func defeatedBossView(boss: WorldBoss) -> some View {
        let template = Boss.templates.first { $0.id == boss.bossTemplateId } ?? Boss.templates.last!
        
        VStack(spacing: 24) {
            Image(systemName: "skull.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 40)
            
            Text("\(template.name) SLAIN!")
                .font(.title)
                .fontWeight(.black)
                .foregroundColor(Theme.accent)
            
            Text("The global threat has been eliminated. A new boss will arrive soon.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            leaderboardView(boss: boss)
        }
    }
    
    @ViewBuilder
    private func leaderboardView(boss: WorldBoss) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TOP DAMAGE DEALERS")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 24)
            
            let sortedAttackers = boss.topAttackers.sorted { $0.value > $1.value }.prefix(10)
            
            if sortedAttackers.isEmpty {
                Text("No attacks yet. Be the first!")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(sortedAttackers.enumerated()), id: \.element.key) { index, attacker in
                        HStack {
                            Text("#\(index + 1)")
                                .font(.headline)
                                .fontWeight(.black)
                                .foregroundColor(index == 0 ? Theme.healerColor : Theme.textSecondary)
                                .frame(width: 40, alignment: .leading)
                            
                            // Try to find the name in leaderboards, or just show ID
                            let allChars = firebaseService.leaderboards.values.flatMap { $0 }
                            let name = allChars.first(where: { $0.id == attacker.key })?.username ?? "Hero_\(attacker.key.prefix(4))"
                            
                            Text(name)
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(attacker.value) DMG")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.danger)
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .padding(.top, 16)
    }
}
