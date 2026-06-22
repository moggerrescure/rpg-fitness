import SwiftUI

struct TrainingSelectionView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @State private var selectedClassForTraining: CharacterClass? = nil

    var body: some View {
        ZStack {
            AnimatedBackgroundView(backgroundType: .trainingRuins)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TRAINING GROUNDS")
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .tracking(2)
                            .glow(color: Theme.textSecondary.opacity(0.5), radius: 8)
                        
                        Text("Select an exercise to begin")
                            .font(.system(.subheadline, design: .default))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(CharacterClass.allCases) { charClass in
                            ExerciseCard(
                                charClass: charClass,
                                isPrimary: firebaseService.currentCharacter?.selectedClass == charClass
                            ) {
                                selectedClassForTraining = charClass
                            }
                        }
                        
                        // Extra bottom padding for the global navigation bar
                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .fullScreenCover(item: $selectedClassForTraining) { charClass in
            CameraTrackingView(selectedClass: charClass)
        }
    }
}

struct ExerciseCard: View {
    let charClass: CharacterClass
    let isPrimary: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(charClass.themeColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: classEmblem(for: charClass))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(charClass.themeColor)
                        .glow(color: charClass.themeColor.opacity(0.4), radius: 8)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(charClass.primaryExercise.uppercased())
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(1)
                        
                        if isPrimary {
                            Spacer()
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(charClass.themeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(charClass.themeColor.opacity(0.15))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(charClass.themeColor.opacity(0.5), lineWidth: 1))
                        }
                    }
                    
                    Text("\(charClass.rawValue) Class • Physical Training")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(charClass.description)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [charClass.themeColor.opacity(isPrimary ? 0.6 : 0.3), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPrimary ? 2 : 1
                    )
            )
            .shadow(color: charClass.themeColor.opacity(isPrimary ? 0.2 : 0.05), radius: 10, y: 5)
        }
        .buttonStyle(TactileButtonStyle())
    }
    
    private func classEmblem(for cls: CharacterClass) -> String {
        switch cls {
        case .archer: return "arrow.up.forward.app.fill"
        case .mage: return "bolt.heart.fill"
        case .swordsman: return "hammer.fill"
        case .healer: return "cross.case.fill"
        }
    }
}
