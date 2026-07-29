import Foundation
import FirebaseAuth
import FirebaseFirestore

/// UGC block list (Guideline 1.2). Local cache + Firestore `users/{uid}/blocked/{targetUid}`.
/// UIDs hidden from friends search/list; duel/message entry points refuse blocked peers.
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
        if let me = Auth.auth().currentUser?.uid, me == uid { return }
        var next = blockedUIDs
        next.insert(uid)
        persistLocal(next)
        writeRemoteBlock(uid)
    }

    static func unblock(_ uid: String) {
        var next = blockedUIDs
        next.remove(uid)
        persistLocal(next)
        removeRemoteBlock(uid)
    }

    /// Load server list on login, union with device cache, push local-only entries up.
    static func syncWithServer(ownerUid: String) async {
        guard !ownerUid.isEmpty else { return }
        let ref = Firestore.firestore()
            .collection("users").document(ownerUid)
            .collection("blocked")
        do {
            let snap = try await ref.getDocuments()
            let remote = Set(snap.documents.map(\.documentID).filter { !$0.isEmpty && $0 != ownerUid })
            let local = blockedUIDs.filter { $0 != ownerUid }
            let merged = remote.union(local)
            persistLocal(merged)

            let missingOnServer = merged.subtracting(remote)
            for target in missingOnServer {
                try await ref.document(target).setData([
                    "blockedAt": FieldValue.serverTimestamp()
                ], merge: true)
            }
        } catch {
            print("BlockedUsersStore sync failed: \(error)")
        }
    }

    private static func persistLocal(_ uids: Set<String>) {
        UserDefaults.standard.set(Array(uids), forKey: key)
    }

    private static func writeRemoteBlock(_ uid: String) {
        guard let owner = Auth.auth().currentUser?.uid, owner != uid else { return }
        Firestore.firestore()
            .collection("users").document(owner)
            .collection("blocked").document(uid)
            .setData(["blockedAt": FieldValue.serverTimestamp()], merge: true)
    }

    private static func removeRemoteBlock(_ uid: String) {
        guard let owner = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("users").document(owner)
            .collection("blocked").document(uid)
            .delete()
    }
}
