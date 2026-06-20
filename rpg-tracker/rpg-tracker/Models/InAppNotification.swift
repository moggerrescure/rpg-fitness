import Foundation
import FirebaseFirestore

enum NotificationType: String, Codable {
    case duel = "DUEL"
    case clan = "CLAN"
    case system = "SYSTEM"
    case reward = "REWARD"
    
    var iconName: String {
        switch self {
        case .duel: return "swords"
        case .clan: return "shield.fill"
        case .system: return "info.circle.fill"
        case .reward: return "gift.fill"
        }
    }
}

struct InAppNotification: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var title: String
    var message: String
    var type: NotificationType
    var isRead: Bool
    var createdAt: Date
    var actionData: [String: String]? // For deep links, e.g., ["duelId": "123"]
    
    init(id: String? = nil, userId: String, title: String, message: String, type: NotificationType, isRead: Bool = false, createdAt: Date = Date(), actionData: [String: String]? = nil) {
        self.id = id
        self.userId = userId
        self.title = title
        self.message = message
        self.type = type
        self.isRead = isRead
        self.createdAt = createdAt
        self.actionData = actionData
    }
}
