import SwiftUI

struct NotificationCenterView: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
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
                    }
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding(.leading, 8)
                }
                .padding()
                .background(Theme.cardBackground)
                
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
                        
                        // DEBUG BUTTON
                        Button(action: {
                            if let uid = FirebaseService.shared.currentCharacter?.id {
                                NotificationManager.sendInAppNotification(to: uid, title: "Test Reward!", message: "You received 100 gold from an anonymous admirer.", type: .reward)
                            }
                        }) {
                            Text("Send Test Notification")
                                .font(.caption)
                                .foregroundColor(Theme.textMuted)
                        }
                        .padding(.bottom, 24)
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
    
    var body: some View {
        Button(action: {
            if !notification.isRead {
                NotificationManager.shared.markAsRead(notification)
            }
            if let type = notification.actionData?["type"] {
                if type == "duel" {
                    NotificationManager.shared.pendingDeepLink = "duel"
                }
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(colorForType(notification.type).opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: notification.type.iconName)
                        .font(.title3)
                        .foregroundColor(colorForType(notification.type))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(notification.isRead ? Theme.textSecondary : Theme.textPrimary)
                        
                        Spacer()
                        
                        if !notification.isRead {
                            Circle()
                                .fill(Theme.danger)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.leading)
                    
                    Text(timeAgoDisplay(notification.createdAt))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textMuted.opacity(0.7))
                        .padding(.top, 2)
                }
            }
            .padding()
            .background(
                ZStack {
                    if !notification.isRead {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.secondaryCard)
                            .shadow(color: colorForType(notification.type).opacity(0.3), radius: 8, x: 0, y: 0)
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.cardBackground.opacity(0.6))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(notification.isRead ? Theme.border : colorForType(notification.type).opacity(0.6), lineWidth: notification.isRead ? 1 : 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
