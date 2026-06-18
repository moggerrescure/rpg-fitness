import SwiftUI

struct ClassStat {
    let name: String
    let value: Int
    let color: Color
}

struct ClassSelectionView: View {
    @StateObject private var viewModel = ClassSelectionVM()
    @Environment(\.dismiss) private var dismiss
    var onSelectionComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Animated background representing wilderness
            AnimatedBackgroundView(backgroundType: .general)
            
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("CHOOSE YOUR HERO")
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(Theme.textPrimary)
                            .tracking(2)
                            .glow(color: Theme.primary.opacity(0.3), radius: 8)
                        
                        Text("Your real workouts will power their combat moves")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 24)
                    
                    // Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hero Name")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        TextField("Enter name...", text: $viewModel.username)
                            .padding()
                            .background(Theme.cardBackground.opacity(0.65))
                            .cornerRadius(14)
                            .foregroundColor(Theme.textPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        LinearGradient(
                                            colors: [viewModel.selectedClass.themeColor.opacity(0.6), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .glow(color: viewModel.selectedClass.themeColor.opacity(0.15), radius: 6)
                    }
                    .padding(.horizontal)
                    
                    // Horizontal class selection list
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(CharacterClass.allCases) { charClass in
                                ClassCard(
                                    charClass: charClass,
                                    isSelected: viewModel.selectedClass == charClass,
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            viewModel.selectedClass = charClass
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .frame(height: 190)
                    
                    // Class details panel
                    VStack(alignment: .leading, spacing: 20) {
                        // Class name and exercise tag
                        HStack {
                            Text(viewModel.selectedClass.rawValue.uppercased())
                                .font(.title3)
                                .fontWeight(.black)
                                .foregroundColor(Theme.textPrimary)
                                .tracking(1)
                            
                            Spacer()
                            
                            // Active Exercise Tag
                            HStack(spacing: 6) {
                                Image(systemName: "figure.walk")
                                Text(viewModel.selectedClass.primaryExercise.uppercased())
                                    .fontWeight(.bold)
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedClass.themeColor.opacity(0.15))
                            .foregroundColor(viewModel.selectedClass.themeColor)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(viewModel.selectedClass.themeColor.opacity(0.35), lineWidth: 1)
                            )
                        }
                        
                        Text(viewModel.selectedClass.description)
                            .font(.system(.subheadline, design: .default))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                        
                        Divider()
                            .background(Theme.border)
                        
                        // Class stats progress bars
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CLASS ATTRIBUTES")
                                .font(.system(size: 10, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textMuted)
                                .tracking(1)
                            
                            ForEach(getClassStats(for: viewModel.selectedClass), id: \.name) { stat in
                                HStack(spacing: 12) {
                                    Text(stat.name)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(width: 100, alignment: .leading)
                                    
                                    GeometryReader { barGeo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Theme.secondaryCard)
                                            
                                            Capsule()
                                                .fill(LinearGradient(
                                                    colors: [stat.color, stat.color.opacity(0.75)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ))
                                                .frame(width: CGFloat(stat.value) / 10.0 * barGeo.size.width)
                                                .glow(color: stat.color.opacity(0.3), radius: 3)
                                        }
                                    }
                                    .frame(height: 6)
                                    
                                    Text("\(stat.value * 10)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Theme.textPrimary)
                                        .frame(width: 25, alignment: .trailing)
                                }
                            }
                        }
                        
                        Divider()
                            .background(Theme.border)
                        
                        // Starter Gear preview
                        VStack(alignment: .leading, spacing: 10) {
                            Text("STARTER EQUIPMENT")
                                .font(.system(size: 10, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textMuted)
                                .tracking(1)
                            
                            HStack(spacing: 16) {
                                if let weapon = viewModel.selectedWeapon {
                                    GearPreviewItem(title: "Weapon", name: weapon.name, rarity: weapon.rarity, icon: "shield.fill")
                                }
                                if let armor = viewModel.selectedArmor {
                                    GearPreviewItem(title: "Armor", name: armor.name, rarity: armor.rarity, icon: "tshirt.fill")
                                }
                            }
                        }
                    }
                    .glassmorphicCard()
                    .padding(.horizontal)
                    
                    // Confirm selection button
                    Button(action: {
                        viewModel.confirmSelection { success in
                            if success {
                                onSelectionComplete()
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("CREATE CHARACTER")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.black)
                                    .tracking(1.5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            viewModel.username.isEmpty
                            ? Color.gray.opacity(0.2)
                            : viewModel.selectedClass.themeColor
                        )
                        .foregroundColor(viewModel.username.isEmpty ? Theme.textMuted : .white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(viewModel.username.isEmpty ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .glow(color: viewModel.username.isEmpty ? .clear : viewModel.selectedClass.themeColor.opacity(0.4), radius: 8)
                    }
                    .disabled(viewModel.username.isEmpty || viewModel.isSubmitting)
                    .buttonStyle(TactileButtonStyle())
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
            }
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(title: Text("Error"), message: Text(viewModel.errorMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func getClassStats(for cls: CharacterClass) -> [ClassStat] {
        switch cls {
        case .archer:
            return [
                ClassStat(name: "STRENGTH", value: 5, color: Theme.swordsmanColor),
                ClassStat(name: "DEXTERITY", value: 9, color: Theme.archerColor),
                ClassStat(name: "INTELLIGENCE", value: 4, color: Theme.mageColor),
                ClassStat(name: "VITALITY", value: 6, color: Theme.healerColor)
            ]
        case .mage:
            return [
                ClassStat(name: "STRENGTH", value: 4, color: Theme.swordsmanColor),
                ClassStat(name: "DEXTERITY", value: 6, color: Theme.archerColor),
                ClassStat(name: "INTELLIGENCE", value: 10, color: Theme.mageColor),
                ClassStat(name: "VITALITY", value: 4, color: Theme.healerColor)
            ]
        case .swordsman:
            return [
                ClassStat(name: "STRENGTH", value: 10, color: Theme.swordsmanColor),
                ClassStat(name: "DEXTERITY", value: 4, color: Theme.archerColor),
                ClassStat(name: "INTELLIGENCE", value: 3, color: Theme.mageColor),
                ClassStat(name: "VITALITY", value: 8, color: Theme.healerColor)
            ]
        case .healer:
            return [
                ClassStat(name: "STRENGTH", value: 5, color: Theme.swordsmanColor),
                ClassStat(name: "DEXTERITY", value: 5, color: Theme.archerColor),
                ClassStat(name: "INTELLIGENCE", value: 7, color: Theme.mageColor),
                ClassStat(name: "VITALITY", value: 10, color: Theme.healerColor)
            ]
        }
    }
}

struct ClassCard: View {
    let charClass: CharacterClass
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon / Emblem representation
                ZStack {
                    Circle()
                        .fill(charClass.themeColor.opacity(isSelected ? 0.25 : 0.12))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: classIconName(for: charClass))
                        .font(.title2)
                        .foregroundColor(charClass.themeColor)
                }
                
                Text(charClass.rawValue.uppercased())
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
            }
            .frame(width: 120, height: 160)
            .background(isSelected ? Theme.secondaryCard.opacity(0.9) : Theme.cardBackground.opacity(0.8))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? charClass.themeColor : Theme.border, lineWidth: isSelected ? 2.5 : 1.5)
            )
            .scaleEffect(isSelected ? 1.05 : 0.95)
            .glow(color: isSelected ? charClass.themeColor.opacity(0.4) : .clear, radius: 10)
        }
        .buttonStyle(TactileButtonStyle())
    }
    
    private func classIconName(for cls: CharacterClass) -> String {
        switch cls {
        case .archer: return "arrow.up.forward.app.fill"
        case .mage: return "bolt.heart.fill"
        case .swordsman: return "hammer.fill"
        case .healer: return "cross.case.fill"
        }
    }
}

struct GearPreviewItem: View {
    let title: String
    let name: String
    let rarity: ItemRarity
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(rarity.color)
                .padding(8)
                .background(rarity.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(Theme.textMuted)
                    .textCase(.uppercase)
                
                Text(name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
