import SwiftUI

struct HealthSyncCard: View {
    @ObservedObject var healthService = HealthKitService.shared
    @ObservedObject var firebaseService = FirebaseService.shared
    
    @State private var showRewards: Bool = false
    @State private var recentResult: HealthSyncResult? = nil
    
    var body: some View {
        Button(action: {
            Task {
                if !healthService.isAuthorized {
                    try? await healthService.requestAuthorization()
                }
                if healthService.isAuthorized {
                    if let char = firebaseService.currentCharacter {
                        let result = try? await healthService.syncHealthData(since: char.lastHealthSyncDate)
                        if let res = result {
                            await MainActor.run {
                                self.recentResult = res
                                self.showRewards = true
                                firebaseService.handleHealthSync(result: res)
                            }
                        }
                    }
                }
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.danger.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "heart.text.square.fill")
                        .font(.title)
                        .foregroundColor(Theme.danger)
                        .symbolEffect(.pulse, options: .repeating, isActive: healthService.isSyncing)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync Apple Health")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                    
                    if let lastSync = firebaseService.currentCharacter?.lastHealthSyncDate {
                        Text("Last sync: \(timeAgoDisplay(lastSync))")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                    } else {
                        Text("Tap to connect Apple Health")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.textMuted)
            }
            .padding()
            .background(Theme.cardBackground.opacity(0.8))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.danger.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Theme.danger.opacity(0.3), radius: 10, x: 0, y: 0)
        }
        .buttonStyle(TactileButtonStyle())
        .sheet(isPresented: $showRewards) {
            if let res = recentResult {
                HealthRewardsView(result: res)
            }
        }
    }
    
    private func timeAgoDisplay(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct HealthRewardsView: View {
    let result: HealthSyncResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("HEALTH SYNC COMPLETE")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(Theme.danger)
                    .padding(.top, 40)
                    .multilineTextAlignment(.center)
                
                if result.steps == 0 && result.activeCalories == 0 && result.workoutMinutes == 0 {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.textMuted)
                        .padding(.vertical, 30)
                    
                    Text("No new activities found since last sync. Time to get moving!")
                        .font(.headline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    // Stats
                    HStack(spacing: 12) {
                        statBox(title: "STEPS", value: "\(result.steps)", icon: "figure.walk", color: .cyan)
                        statBox(title: "CALORIES", value: "\(result.activeCalories)", icon: "flame.fill", color: Theme.danger)
                        statBox(title: "MINUTES", value: "\(result.workoutMinutes)", icon: "timer", color: .green)
                    }
                    .padding(.horizontal, 16)
                    
                    // Rewards
                    VStack(spacing: 12) {
                        Text("REWARDS GAINED")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.top, 20)
                        
                        HStack(spacing: 12) {
                            RewardBadge(icon: "star.fill", value: "+\(result.xpGained) XP", color: Theme.warning)
                            RewardBadge(icon: "bolt.fill", value: "+\(result.energyGained) NRG", color: Theme.primary)
                            RewardBadge(icon: "dollarsign.circle.fill", value: "+\(result.goldGained) G", color: .yellow)
                        }
                        
                        if result.damageDealt > 0 {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.red)
                                Text("Dealt \(result.damageDealt) DMG to World Boss!")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.5), lineWidth: 1))
                            .padding(.top, 8)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("AWESOME!")
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.danger)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            Text(title)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.secondaryCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct RewardBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}
