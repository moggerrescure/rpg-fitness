import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseAppCheck

import GoogleSignIn

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #endif
        
        FirebaseApp.configure()
        
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // Captured APNs token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            print("FCM Token Received: \(token)")
            // Safe to call directly if firebase service is initialized
            FirebaseService.shared.updateFCMToken(token)
        }
    }
}
#endif

@main
struct FitRPGApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var versionManager = VersionManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !networkMonitor.isConnected {
                    // No internet — show blocking screen
                    NoInternetView()
                        .transition(.opacity)
                        .zIndex(1000)
                } else if authManager.currentUser == nil {
                    // Waiting for Firebase anonymous auth
                    ZStack {
                        Color(red: 0.04, green: 0.04, blue: 0.10).ignoresSafeArea()
                        VStack(spacing: 20) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 56, weight: .ultraLight))
                                .foregroundStyle(
                                    LinearGradient(colors: [Color(red: 0.5, green: 0.8, blue: 1.0), Color(red: 0.3, green: 0.5, blue: 0.9)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .shadow(color: .blue.opacity(0.5), radius: 20)
                            ProgressView()
                                .tint(.white.opacity(0.6))
                            Text("Connecting to servers...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(Color(white: 0.45))
                                .tracking(1)
                        }
                    }
                    .transition(.opacity)
                } else {
                    MainHubView()
                        .environmentObject(authManager)
                        .environmentObject(firebaseService)
                        .transition(.opacity)
                }

                if versionManager.updateRequirement == .hardUpdate ||
                  (versionManager.updateRequirement == .softUpdate && !versionManager.hasDismissedSoftUpdate) {
                    UpdateRequiredView()
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: networkMonitor.isConnected)
            .animation(.easeInOut(duration: 0.35), value: authManager.currentUser == nil)
            .task {
                await RemoteConfigManager.shared.fetchCloudValues()
                await versionManager.checkVersion()

                // Initialize Notifications
                NotificationManager.shared.requestAuthorization()
                NotificationManager.shared.scheduleDailyReminder()

                // Request HealthKit authorization automatically on launch
                let healthService = HealthKitService.shared
                if healthService.isAvailable && !healthService.isAuthorized {
                    try? await healthService.requestAuthorization()
                }
                // Auto-sync health data if authorized and user has a character
                if healthService.isAuthorized,
                   let char = firebaseService.currentCharacter {
                    let result = try? await healthService.syncHealthData(since: char.lastHealthSyncDate)
                    if let result = result {
                        firebaseService.handleHealthSync(result: result)
                    }
                }
            }
            .onOpenURL { url in
                if url.scheme == "rpgfitness", url.host == "friend" {
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let uid = components.queryItems?.first(where: { $0.name == "uid" })?.value {
                        Task {
                            await firebaseService.sendFriendRequest(to: uid)
                        }
                    }
                }
            }
        }
    }
}
