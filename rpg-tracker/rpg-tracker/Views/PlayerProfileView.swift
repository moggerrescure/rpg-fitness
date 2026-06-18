import SwiftUI

struct PlayerProfileView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var profileToastMessage: String? = nil
    @State private var showArmoryShop = false
    
    init(character: Character) {
        // Direct observation of FirebaseService handles reactivity; signature kept for compatibility.
    }
    
    private var character: Character {
        firebaseService.currentCharacter ?? Character(id: "local", username: "FitnessHero", selectedClass: .archer)
    }
    
    var equippedArmor: EquipmentItem? {
        guard let armorId = character.equippedArmorId else { return nil }
        return EquipmentItem.findArmor(by: armorId)
    }
    
    var defense: Int {
        equippedArmor?.defense ?? 0
    }
    
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
            AnimatedBackgroundView(backgroundType: .castle)
            
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
                            // Radial glow halo
                            RadialGradient(
                                colors: [character.selectedClass.themeColor.opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                            .frame(width: 140, height: 140)
                            
                            Circle()
                                .fill(character.selectedClass.themeColor.opacity(0.15))
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [character.selectedClass.themeColor, character.selectedClass.themeColor.opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2.5
                                        )
                                )
                                .glow(color: character.selectedClass.themeColor.opacity(0.4), radius: 8)
                            
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
                    
                    // Equipped Gear Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EQUIPPED GEAR")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1.2)
                        
                        HStack(spacing: 16) {
                            // Armor Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((equippedArmor?.rarity.color ?? Color.gray).opacity(0.12))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke((equippedArmor?.rarity.color ?? Color.gray).opacity(0.3), lineWidth: 1.2)
                                    )
                                
                                Image(systemName: "shield.fill")
                                    .font(.title3)
                                    .foregroundColor(equippedArmor?.rarity.color ?? Color.gray)
                            }
                            .glow(color: (equippedArmor?.rarity.color ?? Color.clear).opacity(0.35), radius: 6)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if let armor = equippedArmor {
                                    HStack(spacing: 6) {
                                        Text(armor.name)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Text(armor.rarity.rawValue.uppercased())
                                            .font(.system(size: 8, design: .monospaced))
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(armor.rarity.color.opacity(0.2))
                                            .foregroundColor(armor.rarity.color)
                                            .cornerRadius(4)
                                    }
                                    
                                    Text("+\(armor.defense) DEFENSE • Reduces battle damage")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(Theme.success)
                                } else {
                                    Text("NO ARMOR EQUIPPED")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    Text("Defense stats are minimized")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textMuted)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showArmoryShop = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "cart.fill")
                                    Text("SHOP")
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.warning)
                                .cornerRadius(8)
                                .shadow(color: Theme.warning.opacity(0.3), radius: 4)
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground.opacity(0.85))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.border, lineWidth: 0.8)
                        )
                    }
                    .padding(.horizontal)
                    
                    // 2x2 Class Grid Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HERO CLASS PROGRESSION (2X2 GRID)")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1.2)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(CharacterClass.allCases) { charClass in
                                let isSelected = character.selectedClass == charClass
                                let prog = character.progressions[charClass.rawValue]
                                let lvl = prog?.level ?? 1
                                let reps = prog?.totalReps ?? 0
                                
                                Button(action: {
                                    guard var char = firebaseService.currentCharacter else { return }
                                    if char.selectedClass != charClass {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            char.selectedClass = charClass
                                            firebaseService.syncCharacter(char)
                                            profileToastMessage = "Class changed to \(charClass.rawValue)!"
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            if profileToastMessage == "Class changed to \(charClass.rawValue)!" {
                                                withAnimation {
                                                    profileToastMessage = nil
                                                }
                                            }
                                        }
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
                                            
                                            Text("LVL \(lvl) • \(reps) REPS")
                                                .font(.system(size: 9, design: .monospaced))
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
                    }
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
                            AttributeCard(name: "Defense (DEF)", value: defense, icon: "shield.fill", color: Theme.success)
                            AttributeCard(name: "Power (PWR)", value: character.combatPower, icon: "bolt.fill", color: Theme.warning)
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
            
            // Floating Toast notification for profile screen class switches
            if let msg = profileToastMessage {
                VStack {
                    FloatingToastView(message: msg)
                        .padding(.top, 50)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .sheet(isPresented: $showArmoryShop) {
            ArmoryShopView()
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

struct AttributeCard: View {
    let name: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .glow(color: color.opacity(0.2), radius: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                
                Text("\(value)")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.black)
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground.opacity(0.7))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
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
                    .fill(unlocked ? Theme.warning.opacity(0.12) : Color.black.opacity(0.2))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle()
                            .stroke(
                                unlocked
                                ? LinearGradient(colors: [Theme.warning, Theme.warning.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.2), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: unlocked ? 2 : 1
                            )
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(unlocked ? Theme.warning : Theme.textMuted)
                    .glow(color: unlocked ? Theme.warning.opacity(0.4) : .clear, radius: 5)
            }
            
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .default))
                    .foregroundColor(unlocked ? Theme.textPrimary : Theme.textMuted)
                    .lineLimit(1)
                
                Text(desc)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
            }
        }
        .frame(width: 90, height: 110)
        .background(unlocked ? Theme.cardBackground.opacity(0.8) : Theme.cardBackground.opacity(0.4))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(unlocked ? Theme.warning.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .shadow(color: unlocked ? Theme.warning.opacity(0.08) : Color.clear, radius: 6, x: 0, y: 3)
    }
}
