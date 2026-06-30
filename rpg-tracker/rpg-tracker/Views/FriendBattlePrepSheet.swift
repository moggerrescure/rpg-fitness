import SwiftUI

struct FriendBattlePrepSheet: View {
    let friendName: String
    @Binding var playerClass: CharacterClass
    @Binding var friendClass: CharacterClass
    var onStart: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Epic DND combat arena background
            AnimatedBackgroundView(backgroundType: .arena)
            
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Subtle ambient glows behind sections
            VStack {
                HStack {
                    Circle()
                        .fill(playerClass.themeColor.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 50)
                    Spacer()
                    Circle()
                        .fill(friendClass.themeColor.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 50)
                }
                Spacer()
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        Text("1V1 DUEL CHALLENGE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(2)
                        
                        Text("PREPARE COMBATANTS")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(Theme.textPrimary)
                            .tracking(1)
                    }
                    .padding(.top, 20)
                    
                    // Matchup VS Banner
                    HStack(spacing: 8) {
                        // Player Card
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(playerClass.themeColor.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                    .glow(color: playerClass.themeColor.opacity(0.35), radius: 6)
                                
                                Image(systemName: classIcon(for: playerClass))
                                    .font(.title3)
                                    .foregroundColor(playerClass.themeColor)
                            }
                            
                            Text("YOU")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                            
                            Text(playerClass.rawValue.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(playerClass.themeColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 4)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(playerClass.themeColor.opacity(0.25), lineWidth: 1)
                        )
                        
                        // VS Badge
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(Theme.border, lineWidth: 1.5))
                            
                            Text("VS")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(Theme.warning)
                                .glow(color: Theme.warning.opacity(0.5), radius: 4)
                        }
                        
                        // Opponent Card
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(friendClass.themeColor.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                    .glow(color: friendClass.themeColor.opacity(0.35), radius: 6)
                                
                                Image(systemName: classIcon(for: friendClass))
                                    .font(.title3)
                                    .foregroundColor(friendClass.themeColor)
                            }
                            
                            Text(friendName.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                            
                            Text(friendClass.rawValue.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(friendClass.themeColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 4)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(friendClass.themeColor.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    // Selector 1: Player Class in 2x2 Grid
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SELECT YOUR FIGHTING CLASS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1.5)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(CharacterClass.allCases) { charClass in
                                let isSelected = playerClass == charClass
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        playerClass = charClass
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: classIcon(for: charClass))
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(charClass.themeColor)
                                            .frame(width: 20)
                                        
                                        Text(charClass.rawValue.uppercased())
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .background(
                                        ZStack {
                                            if isSelected {
                                                charClass.themeColor.opacity(0.12)
                                            }
                                        }
                                        .background(.thinMaterial)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? charClass.themeColor : Theme.border, lineWidth: isSelected ? 2 : 1)
                                    )
                                    .glow(color: isSelected ? charClass.themeColor.opacity(0.3) : .clear, radius: 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        
                        // Active exercise preview
                        HStack(spacing: 8) {
                            Image(systemName: "figure.walk")
                                .foregroundColor(playerClass.themeColor)
                            Text("REQUIRES EXERCISE: \(playerClass.primaryExercise.uppercased())")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(playerClass.themeColor.opacity(0.08))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Selector 2: Friend Class in 2x2 Grid
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SELECT ALLY CHALLENGE CLASS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1.5)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(CharacterClass.allCases) { charClass in
                                let isSelected = friendClass == charClass
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        friendClass = charClass
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: classIcon(for: charClass))
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(charClass.themeColor)
                                            .frame(width: 20)
                                        
                                        Text(charClass.rawValue.uppercased())
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .background(
                                        ZStack {
                                            if isSelected {
                                                charClass.themeColor.opacity(0.12)
                                            }
                                        }
                                        .background(.thinMaterial)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? charClass.themeColor : Theme.border, lineWidth: isSelected ? 2 : 1)
                                    )
                                    .glow(color: isSelected ? charClass.themeColor.opacity(0.3) : .clear, radius: 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        
                        // Active exercise preview for ally
                        HStack(spacing: 8) {
                            Image(systemName: "figure.walk")
                                .foregroundColor(friendClass.themeColor)
                            Text("ALLY SKILL EXERCISE: \(friendClass.primaryExercise.uppercased())")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(friendClass.themeColor.opacity(0.08))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Description Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RULES OF THE ARENA")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .tracking(1)
                        
                        Text("1. Complete repetitions of your exercise to deal skill damage.\n2. The opponent will strike back automatically.\n3. First fighter to run out of health is defeated.")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 8) {
                        Button(action: {
                            dismiss()
                            onStart()
                        }) {
                            Text("LAUNCH DUEL")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.black)
                                .tracking(1.5)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(playerClass.themeColor)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .glow(color: playerClass.themeColor.opacity(0.4), radius: 8)
                        }
                        .buttonStyle(TactileButtonStyle())
                        
                        Button(action: { dismiss() }) {
                            Text("CANCEL CHALLENGE")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(TactileButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
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
