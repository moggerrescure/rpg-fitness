import SwiftUI

struct PlayerProfileView: View {
    let character: Character
    @Environment(\.dismiss) private var dismiss
    
    // Dynamic attributes based on repetition count stats
    var strength: Int {
        10 + Int(Double(character.stats.totalPullups) * 0.5) + Int(Double(character.stats.totalPushups) * 0.3)
    }
    
    var dexterity: Int {
        10 + Int(Double(character.stats.totalSquats) * 0.6)
    }
    
    var vitality: Int {
        10 + Int(Double(character.stats.totalDips) * 0.8)
    }
    
    var intelligence: Int {
        10 + (character.level * 2)
    }
    
    var body: some View {
        ZStack {
            // Animated background representing wilderness
            AnimatedBackgroundView()
            
            // Subtle darken filter overlay to ensure card readability
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Top close button
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Profile main card
                    VStack(spacing: 16) {
                        // Avatar frame
                        ZStack {
                            Circle()
                                .fill(character.selectedClass.themeColor.opacity(0.2))
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Circle()
                                        .stroke(character.selectedClass.themeColor, lineWidth: 2)
                                )
                                .glow(color: character.selectedClass.themeColor.opacity(0.5), radius: 10)
                            
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 70))
                                .foregroundColor(character.selectedClass.themeColor)
                        }
                        
                        VStack(spacing: 4) {
                            Text(character.username)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text(character.selectedClass.rawValue.uppercased())
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(character.selectedClass.themeColor)
                                .tracking(1.5)
                        }
                        
                        // Level tag
                        Text("LEVEL \(character.level)")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(character.selectedClass.themeColor)
                            .cornerRadius(20)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .glassmorphicCard()
                    .padding(.horizontal)
                    
                    // RPG Stats Panel
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CHARACTER ATTRIBUTES")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            AttributeCard(name: "Strength (STR)", value: strength, icon: "figure.strength.strength", color: Theme.swordsmanColor)
                            AttributeCard(name: "Dexterity (DEX)", value: dexterity, icon: "figure.run", color: Theme.archerColor)
                            AttributeCard(name: "Vitality (VIT)", value: vitality, icon: "heart.fill", color: Theme.healerColor)
                            AttributeCard(name: "Intelligence (INT)", value: intelligence, icon: "sparkles", color: Theme.mageColor)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Workout history details card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("WORKOUT METRICS")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1)
                        
                        VStack(spacing: 12) {
                            RepHistoryRow(name: "Squats (Archer)", count: character.stats.totalSquats, color: Theme.archerColor)
                            RepHistoryRow(name: "Push-ups (Mage)", count: character.stats.totalPushups, color: Theme.mageColor)
                            RepHistoryRow(name: "Pull-ups (Swordsman)", count: character.stats.totalPullups, color: Theme.swordsmanColor)
                            RepHistoryRow(name: "Dips (Healer)", count: character.stats.totalDips, color: Theme.healerColor)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Achievements
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ACHIEVEMENTS")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                AchievementBadge(title: "First Rep", desc: "Start journey", icon: "bolt.fill", unlocked: true)
                                AchievementBadge(title: "Squat Adept", desc: "50 squats", icon: "figure.walk", unlocked: character.stats.totalSquats >= 50)
                                AchievementBadge(title: "Push Master", desc: "100 pushups", icon: "crown.fill", unlocked: character.stats.totalPushups >= 100)
                                AchievementBadge(title: "Gladiator", desc: "First PvP win", icon: "suit.spade.fill", unlocked: true)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct AttributeCard: View {
    let name: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                
                Text("\(value)")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.black)
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

struct RepHistoryRow: View {
    let name: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 8, height: 8)
            
            Text(name)
                .font(.caption)
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            Text("\(count) Reps")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Theme.textSecondary)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(10)
    }
}

struct AchievementBadge: View {
    let title: String
    let desc: String
    let icon: String
    let unlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(unlocked ? Theme.healerColor.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 54, height: 54)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(unlocked ? Theme.healerColor : Theme.textMuted)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(unlocked ? Theme.textPrimary : Theme.textMuted)
                
                Text(desc)
                    .font(.system(size: 8))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .opacity(unlocked ? 1.0 : 0.6)
    }
}
