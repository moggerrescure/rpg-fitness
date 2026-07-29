import SwiftUI

struct NotificationCenterView: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AnimatedBackgroundView(backgroundType: .general)
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("NOTIFICATIONS")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    if !notificationManager.inAppNotifications.filter({ !$0.isRead }).isEmpty {
                        Button(action: {
                            notificationManager.markAllAsRead()
                        }) {
                            Text("Mark All Read")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.primary.opacity(0.15))
                                .cornerRadius(12)
                        }
                        .buttonStyle(TactileButtonStyle())
                    }
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Theme.textMuted)
                    }
                    .buttonStyle(TactileButtonStyle())
                    .padding(.leading, 8)
                }
                .padding()
                .background(.thinMaterial)
                
                // List
                if notificationManager.inAppNotifications.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textMuted.opacity(0.5))
                            .padding(.bottom, 16)
                        Text("It's quiet... too quiet.")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()

                        #if DEBUG
                        Button(action: {
                            if let uid = FirebaseService.shared.currentCharacter?.id {
                                NotificationManager.sendInAppNotification(to: uid, title: "Test Reward!", message: "You received 100 gold from an anonymous admirer.", type: .reward)
                            }
                        }) {
                            Text("Send Test Notification")
                                .font(.caption)
                                .foregroundColor(Theme.textMuted)
                        }
                        .buttonStyle(TactileButtonStyle())
                        .padding(.bottom, 24)
                        #endif
                    }
                } else {
                    List {
                        ForEach(notificationManager.inAppNotifications) { note in
                            NotificationCard(notification: note)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            NotificationManager.shared.deleteNotification(note)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }
}

struct NotificationCard: View {
    let notification: InAppNotification

    private var accent: Color { colorForType(notification.type) }
    private var isActionable: Bool {
        guard let type = notification.actionData?["type"] else { return false }
        return type == "duel" || type == "teamInvite" || type == "friendRequest"
    }
    private var ctaLabel: String {
        switch notification.actionData?["type"] {
        case "teamInvite": return "Tap to join"
        case "duel": return "Tap to accept"
        case "friendRequest": return "View request"
        default: return ""
        }
    }
    private var iconName: String {
        notification.type.iconName(actionData: notification.actionData)
    }
    
    var body: some View {
        Button(action: {
            if !notification.isRead {
                NotificationManager.shared.markAsRead(notification)
            }
            if let type = notification.actionData?["type"] {
                if type == "duel" || type == "teamInvite" {
                    NotificationManager.shared.pendingDeepLink = "duel"
                } else if type == "friendRequest" {
                    NotificationManager.shared.pendingDeepLink = "friends"
                }
            }
        }) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.35), accent.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accent)
                        .accessibilityHidden(true)
                }
                .overlay(
                    Circle()
                        .stroke(accent.opacity(notification.isRead ? 0.25 : 0.65), lineWidth: notification.isRead ? 1 : 1.5)
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(notification.title)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(notification.isRead ? Theme.textSecondary : Theme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 4)
                        
                        if !notification.isRead {
                            Circle()
                                .fill(Theme.danger)
                                .frame(width: 8, height: 8)
                                .accessibilityLabel("Unread")
                        }
                    }
                    
                    Text(displayMessage)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 10) {
                        Text(timeAgoDisplay(notification.createdAt))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                        
                        Spacer(minLength: 0)
                        
                        if isActionable {
                            HStack(spacing: 4) {
                                Text(ctaLabel)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(accent.opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 1))
                        }
                    }
                }
            }
            .padding(14)
            .background(
                ZStack {
                    Theme.cardBackground.opacity(notification.isRead ? 0.72 : 0.92)
                    if !notification.isRead {
                        accent.opacity(0.08)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        notification.isRead ? Theme.border : accent.opacity(0.55),
                        lineWidth: notification.isRead ? 1 : 1.5
                    )
            )
            .shadow(color: notification.isRead ? .clear : accent.opacity(0.18), radius: 8, y: 2)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityHint(isActionable ? ctaLabel : "")
    }

    /// Strip redundant "Tap to join" from body when CTA chip is shown.
    private var displayMessage: String {
        var msg = notification.message
        if isActionable {
            for suffix in [" Tap to join.", " Tap to join", " Tap to accept.", " Tap to accept"] {
                if msg.hasSuffix(suffix) {
                    msg = String(msg.dropLast(suffix.count))
                    break
                }
            }
        }
        return msg
    }
    
    private func colorForType(_ type: NotificationType) -> Color {
        switch type {
        case .duel: return Theme.danger
        case .clan: return Theme.primary
        case .reward: return Theme.warning
        case .system: return Theme.healerColor
        }
    }
    
    private func timeAgoDisplay(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
