import Foundation

/// Local UGC block list (Guideline 1.2). UIDs hidden from friends search/list;
/// duel/message entry points should refuse blocked peers.
enum BlockedUsersStore {
    private static let key = "fitrpg_blocked_uids"

    static var blockedUIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func isBlocked(_ uid: String) -> Bool {
        blockedUIDs.contains(uid)
    }

    static func block(_ uid: String) {
        guard !uid.isEmpty else { return }
        var next = blockedUIDs
        next.insert(uid)
        UserDefaults.standard.set(Array(next), forKey: key)
    }

    static func unblock(_ uid: String) {
        var next = blockedUIDs
        next.remove(uid)
        UserDefaults.standard.set(Array(next), forKey: key)
    }
}
