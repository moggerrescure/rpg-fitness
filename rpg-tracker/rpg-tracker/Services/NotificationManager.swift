import Foundation
import UserNotifications
import FirebaseFirestore
import Combine

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized: Bool = false
    @Published var inAppNotifications: [InAppNotification] = []
    
    @Published var pendingDeepLink: String? = nil
    
    private var listenerRegistration: ListenerRegistration?
    private let db = Firestore.firestore()
    /// Skip local banners for the initial historical snapshot.
    private var notificationsWarm = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    print("Notifications authorized.")
                } else if let error = error {
                    print("Notifications auth error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - In-App Notifications
    
    func listenForInAppNotifications(userId: String) {
        listenerRegistration?.remove()
        notificationsWarm = false
        
        let query = db.collection("users").document(userId).collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            
        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            guard let snapshot else {
                print("Error fetching notifications: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            self.inAppNotifications = snapshot.documents.compactMap { doc -> InAppNotification? in
                try? doc.data(as: InAppNotification.self)
            }
            self.syncBadgeCount()
            
            if !self.notificationsWarm {
                self.notificationsWarm = true
                return
            }
            for change in snapshot.documentChanges where change.type == .added {
                if let note = try? change.document.data(as: InAppNotification.self), !note.isRead {
                    self.presentLocalInviteBanner(for: note)
                }
            }
        }
    }
    
    /// Local banner so invite taps (team / duel / friend) deep-link when the app was backgrounded.
    private func presentLocalInviteBanner(for note: InAppNotification) {
        guard isAuthorized else { return }
        let type = note.actionData?["type"] ?? ""
        guard type == "duel" || type == "teamInvite" || type == "friendRequest" else { return }
        
        let content = UNMutableNotificationContent()
        content.title = note.title
        content.body = note.message
        content.sound = .default
        var info: [AnyHashable: Any] = note.actionData ?? [:]
        info["type"] = type
        content.userInfo = info
        
        let id = "invite_\(type)_\(note.id ?? UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to present invite banner: \(error)") }
        }
    }
    
    private func syncBadgeCount() {
        let unread = inAppNotifications.filter { !$0.isRead }.count
        UNUserNotificationCenter.current().setBadgeCount(unread) { error in
            if let error = error {
                print("Failed to set badge count: \(error.localizedDescription)")
            }
        }
    }
    
    func markAsRead(_ notification: InAppNotification) {
        guard let id = notification.id else { return }
        let ref = db.collection("users").document(notification.userId).collection("notifications").document(id)
        ref.updateData(["isRead": true])
    }
    
    func markAllAsRead() {
        let unread = inAppNotifications.filter { !$0.isRead }
        for note in unread {
            markAsRead(note)
        }
    }
    
    func deleteNotification(_ notification: InAppNotification) {
        guard let id = notification.id else { return }
        let ref = db.collection("users").document(notification.userId).collection("notifications").document(id)
        ref.delete()
    }
    
    func stopListening() {
        listenerRegistration?.remove()
        notificationsWarm = false
        inAppNotifications = []
    }
    
    // Sends a notification to another user's in-app center
    static func sendInAppNotification(to targetUserId: String, title: String, message: String, type: NotificationType, actionData: [String: String]? = nil) {
        let note = InAppNotification(
            userId: targetUserId,
            title: title,
            message: message,
            type: type,
            isRead: false,
            createdAt: Date(),
            actionData: actionData
        )
        do {
            try Firestore.firestore().collection("users").document(targetUserId).collection("notifications").addDocument(from: note)
        } catch {
            print("Error sending in-app notification: \(error)")
        }
    }
    
    // MARK: - Local Notifications
    
    func scheduleDailyReminder() {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Heroes don't skip leg day!"
        content.body = "Your clan needs you. Complete your daily workout to earn gold and XP!"
        content.sound = .default
        
        // Everyday at 9:00 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder: \(error)")
            }
        }
    }
    
    func scheduleEnergyRestored(inSeconds seconds: TimeInterval) {
        guard isAuthorized, seconds > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Energy Fully Restored! ⚡️"
        content.body = "You are fully rested. Head back to the arena and fight!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        
        let request = UNNotificationRequest(identifier: "energy_restored", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule energy reminder: \(error)")
            }
        }
    }
    
    func scheduleClanWarPhase(title: String, body: String, inSeconds seconds: TimeInterval, identifier: String) {
        guard isAuthorized, seconds > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Remove existing notification for this phase to avoid duplicates
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule clan war notification: \(error)")
            }
        }
    }
    
    func clearClanWarNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "clan_war_start",
            "clan_war_active",
            "clan_war_finished"
        ])
    }
    
    func sendWorldBossNotification(title: String, body: String) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "world_boss_\(UUID().uuidString)", content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send world boss notification: \(error)")
            }
        }
    }
    
    // Allows notifications to show even when app is in foreground
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                          willPresent notification: UNNotification,
                                          withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo
        let actionType = userInfo["type"] as? String
        
        Task { @MainActor in
            if let actionType {
                switch actionType {
                case "duel", "teamInvite":
                    self.pendingDeepLink = "duel"
                case "friendRequest":
                    self.pendingDeepLink = "friends"
                case "clan", "clanWar", "clanwar":
                    self.pendingDeepLink = "clanwar"
                default:
                    break
                }
            } else if identifier == "energy_restored" {
                self.pendingDeepLink = "arena"
            } else if identifier.starts(with: "duel_") || identifier.starts(with: "invite_duel") || identifier.starts(with: "invite_teamInvite") {
                self.pendingDeepLink = "duel"
            } else if identifier.starts(with: "invite_friendRequest") {
                self.pendingDeepLink = "friends"
            } else if identifier.starts(with: "clan_war") {
                self.pendingDeepLink = "clanwar"
            }
        }
        
        completionHandler()
    }
}
