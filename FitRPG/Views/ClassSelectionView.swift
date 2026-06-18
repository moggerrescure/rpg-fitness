import SwiftUI

struct ClassSelectionView: View {
    @StateObject private var viewModel = ClassSelectionVM()
    @Environment(\.dismiss) private var dismiss
    var onSelectionComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Deep background
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("CHOOSE YOUR HERO")
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                        .tracking(2)
                    
                    Text("Your real workouts will power their combat moves")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hero Name")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textSecondary)
                        .textCase(.uppercase)
                    
                    TextField("Enter name...", text: $viewModel.username)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(Theme.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border, lineWidth: 1.5)
                        )
                }
                .padding(.horizontal)
                
                // Horizontal class selection list
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(CharacterClass.allCases) { charClass in
                            ClassCard(
                                charClass: charClass,
                                isSelected: viewModel.selectedClass == charClass,
                                action: { viewModel.selectedClass = charClass }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 180)
                
                // Class details panel
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(viewModel.selectedClass.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                        
                        Spacer()
                        
                        // Active Exercise Tag
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                            Text(viewModel.selectedClass.primaryExercise)
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.selectedClass.themeColor.opacity(0.15))
                        .foregroundColor(viewModel.selectedClass.themeColor)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(viewModel.selectedClass.themeColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Text(viewModel.selectedClass.description)
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                        .background(Theme.border)
                    
                    // Starter Gear preview
                    HStack(spacing: 16) {
                        if let weapon = viewModel.selectedWeapon {
                            GearPreviewItem(title: "Weapon", name: weapon.name, rarity: weapon.rarity, icon: "shield.fill")
                        }
                        if let armor = viewModel.selectedArmor {
                            GearPreviewItem(title: "Armor", name: armor.name, rarity: armor.rarity, icon: "tshirt.fill")
                        }
                    }
                }
                .glassmorphicCard()
                .padding(.horizontal)
                
                Spacer()
                
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
                                .fontWeight(.bold)
                                .tracking(1.5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        viewModel.username.isEmpty
                        ? Color.gray.opacity(0.3)
                        : viewModel.selectedClass.themeColor
                    )
                    .foregroundColor(viewModel.username.isEmpty ? Theme.textMuted : .white)
                    .cornerRadius(12)
                    .shadow(color: viewModel.username.isEmpty ? .clear : viewModel.selectedClass.themeColor.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .disabled(viewModel.username.isEmpty || viewModel.isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(title: Text("Error"), message: Text(viewModel.errorMessage), dismissButton: .default(Text("OK")))
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
                        .fill(charClass.themeColor.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: classIconName(for: charClass))
                        .font(.title)
                        .foregroundColor(charClass.themeColor)
                }
                
                Text(charClass.rawValue)
                    .font(.headline)
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
            }
            .frame(width: 120, height: 160)
            .background(isSelected ? Theme.secondaryCard : Theme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? charClass.themeColor : Theme.border, lineWidth: 2)
            )
            .glow(color: isSelected ? charClass.themeColor.opacity(0.3) : .clear, radius: 10)
        }
        .buttonStyle(PlainButtonStyle())
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

struct ClassSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ClassSelectionView(onSelectionComplete: {})
    }
}
