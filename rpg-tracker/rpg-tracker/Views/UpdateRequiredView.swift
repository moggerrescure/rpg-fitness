import SwiftUI

struct UpdateRequiredView: View {
    @ObservedObject var versionManager = VersionManager.shared
    @ObservedObject private var remoteConfig = RemoteConfigManager.shared
    @Environment(\.openURL) var openURL

    private var appStoreURL: URL? {
        let remoteURL = remoteConfig.updateURLString
        if !remoteURL.isEmpty, let url = URL(string: remoteURL) {
            return url
        }
        return AppStoreConfig.appStoreURL(remoteConfig: remoteConfig)
    }

    var isHardUpdate: Bool {
        versionManager.updateRequirement == .hardUpdate
    }

    private var titleText: String {
        let t = remoteConfig.updateTitle
        if isHardUpdate && t == "Update Available" {
            return "Update Required"
        }
        return t
    }

    private var messageText: String {
        let m = remoteConfig.updateMessage
        if isHardUpdate && m.contains("improvements and fixes") {
            return "A critical update is required to continue. Please update FitRPG from the App Store."
        }
        return m
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.4), Color.clear]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(y: -100)
                .allowsHitTesting(false)

            VStack(spacing: 30) {
                Image(systemName: isHardUpdate ? "exclamationmark.arrow.triangle.2.circlepath" : "arrow.down.app.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 0)
                    .padding(.top, 50)

                Text(titleText)
                    .font(.custom("Palatino-Bold", size: 32))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .purple.opacity(0.5), radius: 5, x: 0, y: 2)
                    .padding(.horizontal, 24)

                Text(messageText)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)

                Spacer()

                if let appStoreURL {
                    Button {
                        openURL(appStoreURL)
                    } label: {
                        Text(isHardUpdate ? "Update Now" : "Update")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.yellow, .orange]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 40)
                } else {
                    Text("App Store link is not configured. Set Remote Config `fitrpg_update_url` or `fitrpg_ios_app_store_id`.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if !isHardUpdate {
                    Button {
                        withAnimation {
                            versionManager.hasDismissedSoftUpdate = true
                        }
                    } label: {
                        Text("Later")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.vertical, 12)
                    }
                    .padding(.bottom, 20)
                } else {
                    Spacer().frame(height: 50)
                }
            }
            .padding(.bottom, 30)
        }
        .interactiveDismissDisabled(isHardUpdate)
    }
}

#Preview {
    UpdateRequiredView()
}
