import SwiftUI

struct UpdateRequiredView: View {
    @ObservedObject var versionManager = VersionManager.shared
    @Environment(\.openURL) var openURL
    
    // Replace with your actual App Store link when available
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id0000000000")!
    
    var isHardUpdate: Bool {
        versionManager.updateRequirement == .hardUpdate
    }
    
    var body: some View {
        ZStack {
            // Dark Fantasy Background
            Color.black.ignoresSafeArea()
            
            // Subtle glowing orb effect in the background
            Circle()
                .fill(
                    RadialGradient(gradient: Gradient(colors: [Color.purple.opacity(0.4), Color.clear]), center: .center, startRadius: 50, endRadius: 250)
                )
                .frame(width: 500, height: 500)
                .offset(y: -100)
            
            VStack(spacing: 30) {
                // Header Icon
                Image(systemName: "arrow.down.app.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 0)
                    .padding(.top, 50)
                
                // Title
                Text("New Realm Available")
                    .font(.custom("Palatino-Bold", size: 32))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .purple.opacity(0.5), radius: 5, x: 0, y: 2)
                
                // Subtitle
                Text(isHardUpdate ?
                     "A critical magical update is required to continue your journey. The old magic is fading!" :
                     "A new version is available with new quests and bug fixes. We recommend updating your grimoire.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
                
                Spacer()
                
                // Primary Action Button
                Button(action: {
                    openURL(appStoreURL)
                }) {
                    Text("Ascend Now")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [.yellow, .orange]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(12)
                        .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 40)
                
                // Secondary Action Button (Only for Soft Update)
                if !isHardUpdate {
                    Button(action: {
                        withAnimation {
                            versionManager.hasDismissedSoftUpdate = true
                        }
                    }) {
                        Text("Delay Ritual")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.vertical, 12)
                    }
                    .padding(.bottom, 20)
                } else {
                    // For layout spacing parity
                    Spacer().frame(height: 50)
                }
            }
            .padding(.bottom, 30)
        }
    }
}

#Preview {
    UpdateRequiredView()
}
