import SwiftUI
import HealthKit

/// A rich Health Sync card used inside the Player Profile as a settings tab.
/// Shows HealthKit authorization status, last sync time, step / calorie stats,
/// and offers a manual re-sync button.
struct HealthSyncTabView: View {
    @ObservedObject private var healthService = HealthKitService.shared
    @ObservedObject private var firebaseService = FirebaseService.shared

    @State private var showRewards: Bool = false
    @State private var recentResult: HealthSyncResult? = nil
    @State private var pulseAnimation: Bool = false

    private var lastSyncText: String {
        guard let date = firebaseService.currentCharacter?.lastHealthSyncDate else {
            return "Never synced"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("APPLE HEALTH SYNC")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textSecondary)
                    .tracking(1.2)

                Spacer()

                // Authorization badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(healthService.isAuthorized ? Theme.success : Theme.danger)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulseAnimation && healthService.isAuthorized ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)

                    Text(healthService.isAuthorized ? "CONNECTED" : "NOT AUTHORIZED")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(healthService.isAuthorized ? Theme.success : Theme.danger)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((healthService.isAuthorized ? Theme.success : Theme.danger).opacity(0.12))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((healthService.isAuthorized ? Theme.success : Theme.danger).opacity(0.3), lineWidth: 1)
                )
            }

            // Main sync card
            VStack(spacing: 0) {
                // Status row
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Theme.danger.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: "heart.text.square.fill")
                            .font(.title2)
                            .foregroundColor(Theme.danger)
                            .symbolEffect(.pulse, options: .repeating, isActive: healthService.isSyncing)
                    }
                    .glow(color: Theme.danger.opacity(0.3), radius: 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(healthService.isSyncing ? "Syncing…" : (healthService.isAuthorized ? "Health Connected" : "Connect Apple Health"))
                            .font(.system(.subheadline, design: .default))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)

                        Text(healthService.isAuthorized ? "Last sync: \(lastSyncText)" : "Earn XP, gold & energy from real workouts")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                    }

                    Spacer()

                    // Action button
                    Button(action: performSync) {
                        if healthService.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: healthService.isAuthorized ? "arrow.triangle.2.circlepath" : "link")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(healthService.isAuthorized ? Theme.danger : Theme.primary)
                    .clipShape(Circle())
                    .shadow(color: (healthService.isAuthorized ? Theme.danger : Theme.primary).opacity(0.4), radius: 6)
                    .disabled(healthService.isSyncing)
                    .buttonStyle(TactileButtonStyle())
                }
                .padding(16)

                if healthService.isAuthorized {
                    Divider()
                        .background(Theme.border)
                        .padding(.horizontal, 16)

                    // Reward formula explanation
                    HStack(spacing: 8) {
                        RewardFormulaChip(icon: "figure.walk", label: "10 steps = 1 XP", color: .cyan)
                        RewardFormulaChip(icon: "flame.fill", label: "1 kcal = 5 XP", color: Theme.danger)
                        RewardFormulaChip(icon: "timer", label: "1 min = 10 XP", color: Theme.success)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Theme.cardBackground.opacity(0.85))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.danger.opacity(0.4), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Theme.danger.opacity(0.15), radius: 10, x: 0, y: 4)
        }
        .onAppear { pulseAnimation = true }
        .sheet(isPresented: $showRewards) {
            if let res = recentResult {
                HealthRewardsView(result: res)
            }
        }
    }

    // MARK: - Actions

    private func performSync() {
        Task {
            if !healthService.isAuthorized {
                try? await healthService.requestAuthorization()
            }
            guard healthService.isAuthorized,
                  let char = firebaseService.currentCharacter else { return }

            let result = try? await healthService.syncHealthData(since: char.lastHealthSyncDate)
            if let res = result {
                await MainActor.run {
                    recentResult = res
                    showRewards = true
                    firebaseService.handleHealthSync(result: res)
                }
            }
        }
    }
}

// MARK: - Supporting View

private struct RewardFormulaChip: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 0.8)
        )
    }
}
