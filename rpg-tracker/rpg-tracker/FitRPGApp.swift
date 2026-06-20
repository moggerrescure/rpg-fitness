import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

import GoogleSignIn

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
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

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isAnonymous && authManager.currentUser == nil {
                    ProgressView("Connecting to servers...")
                } else {
                    MainHubView()
                        .environmentObject(authManager)
                        .environmentObject(firebaseService)
                }
                
                if versionManager.updateRequirement == .hardUpdate || 
                  (versionManager.updateRequirement == .softUpdate && !versionManager.hasDismissedSoftUpdate) {
                    UpdateRequiredView()
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .task {
                await RemoteConfigManager.shared.fetchCloudValues()
                await versionManager.checkVersion()
                
                // Initialize Notifications
                NotificationManager.shared.requestAuthorization()
                NotificationManager.shared.scheduleDailyReminder()
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
