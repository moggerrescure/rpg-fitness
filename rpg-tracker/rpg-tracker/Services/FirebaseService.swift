import Foundation
import Combine
import FirebaseFunctions
import FirebaseFirestore
import FirebaseAuth
import WidgetKit

class FirebaseService: ObservableObject {
    @Published var currentCharacter: Character?
    @Published var activeBattle: Battle?
    @Published var userClan: Clan?
    @Published var leaderboards: [String: [Character]] = [:]
    @Published var friends: [String] = []
    @Published var activeWorldBoss: WorldBoss?
    /// Distinguishes first load vs confirmed empty vs listener error.
    @Published var worldBossStatus: WorldBossLoadStatus = .loading
    /// Surfaced to UI toasts for clan/war CF failures (no silent print-only fails).
    @Published var lastActionError: String? = nil

    enum WorldBossLoadStatus: Equatable {
        case loading
        case ready
        case empty
        case error(String)
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var battleTimer: Timer?
    private var energyRegenTimer: Timer?
    
    /// One energy point every 5 minutes, up to maxEnergy.
    private static let energyRegenInterval: TimeInterval = 300
    
    static let shared = FirebaseService()
    
    init() {
        // Load persisted friends list if it exists
        if let savedFriends = UserDefaults.standard.stringArray(forKey: "saved_friends") {
            self.friends = savedFriends
        }

        fetchLeaderboards()
        listenToWorldBoss()

        AuthManager.shared.$currentUser
            .compactMap { $0 }
            .sink { [weak self] user in
                self?.startListeningToCharacter(uid: user.uid)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - World Boss listener
    private var worldBossListener: ListenerRegistration?
    
    private func listenToWorldBoss() {
        worldBossListener?.remove()
        worldBossStatus = .loading
        worldBossListener = Firestore.firestore().collection("world_bosses")
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.activeWorldBoss = nil
                        self.worldBossStatus = .error(error.localizedDescription)
                    }
                    return
                }
                if let doc = snapshot?.documents.first,
                   let boss = try? doc.data(as: WorldBoss.self) {
                    DispatchQueue.main.async {
                        self.activeWorldBoss = boss
                        self.worldBossStatus = .ready
                    }
                } else {
                    // No active world boss — wait for server cron; do not fabricate client-side
                    DispatchQueue.main.async {
                        self.activeWorldBoss = nil
                        self.worldBossStatus = .empty
                    }
                }
            }
    }

    func retryWorldBossListener() {
        listenToWorldBoss()
    }
    
    private var characterListener: ListenerRegistration?
    private var clanListener: ListenerRegistration?
    private var currentListenedClanId: String?
    
    func startListeningToCharacter(uid: String) {
        characterListener?.remove()
        characterListener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else { return }

                if snapshot.exists {
                    do {
                        let char = try snapshot.data(as: Character.self)
                        DispatchQueue.main.async {
                            self.currentCharacter = char
                            self.applyEnergyRegenIfNeeded()
                            self.startEnergyRegenTimerIfNeeded()
                            
                            // Migration: ensure all required fields exist in Firestore
                            let rawData = snapshot.data() ?? [:]
                            let needsMigration = char.pvpTrophies == nil
                                || char.currentLevel != char.level
                                || char.classTrophies == nil
                                || rawData["usernameLower"] == nil
                            if needsMigration {
                                var updated = char
                                // Ensure pvpTrophies exists
                                if updated.pvpTrophies == nil {
                                    updated.pvpTrophies = 0
                                }
                                // Keep currentLevel in sync for server-side leaderboard sort
                                updated.currentLevel = updated.level
                                // Initialize per-class trophies if missing
                                if updated.classTrophies == nil {
                                    var dict = Dictionary(
                                        uniqueKeysWithValues: CharacterClass.allCases.map { ($0.rawValue, 0) }
                                    )
                                    // Carry over existing pvpTrophies to the current class
                                    dict[updated.selectedClass.rawValue] = updated.pvpTrophies ?? 0
                                    updated.classTrophies = dict
                                }
                                self.syncCharacter(updated)
                            }
                            
                            // Manage Clan Listener
                            if let clanId = char.clanId {
                                if self.currentListenedClanId != clanId {
                                    self.startListeningToClan(clanId: clanId)
                                }
                            } else {
                                self.clanListener?.remove()
                                self.currentListenedClanId = nil
                                self.userClan = nil
                            }
                        }
                    } catch {
                        print("Error decoding character from Firestore: \(error)")
                    }
                } else {
                    // New user — no character in Firestore yet.
                    // Set to nil so MainHubView shows ClassSelectionView for class setup.
                    DispatchQueue.main.async {
                        self.currentCharacter = nil
                        self.clanListener?.remove()
                        self.currentListenedClanId = nil
                        self.userClan = nil
                    }
                }
            }
    }
    
    private func startListeningToClan(clanId: String) {
        clanListener?.remove()
        currentListenedClanId = clanId
        
        clanListener = Firestore.firestore().collection("clans").document(clanId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else { return }
                
                if snapshot.exists {
                    do {
                        let clan = try snapshot.data(as: Clan.self)
                        DispatchQueue.main.async {
                            // Check if user is still in the clan (self-healing if kicked/left offline)
                            if let char = self.currentCharacter, !clan.members.contains(where: { $0.id == char.id }) {
                                // User was kicked or clan was bugged
                                self.clanListener?.remove()
                                self.currentListenedClanId = nil
                                self.userClan = nil
                                
                                var updatedChar = char
                                updatedChar.clanId = nil
                                self.syncCharacter(updatedChar)
                            } else {
                                self.userClan = clan
                            }
                        }
                    } catch {
                        print("Error decoding clan from Firestore: \(error)")
                    }
                } else {
                    // Clan was disbanded or deleted
                    DispatchQueue.main.async {
                        self.clanListener?.remove()
                        self.currentListenedClanId = nil
                        self.userClan = nil
                        
                        if let char = self.currentCharacter {
                            var updatedChar = char
                            updatedChar.clanId = nil
                            self.syncCharacter(updatedChar)
                        }
                    }
                }
            }
    }
    
    // MARK: - Disk Saving Helpers
    func saveCharacterToDisk() {
        guard let char = currentCharacter else { return }
        if let data = try? JSONEncoder().encode(char) {
            UserDefaults.standard.set(data, forKey: "saved_character")
        }
    }
    
    func saveFriendsToDisk() {
        UserDefaults.standard.set(friends, forKey: "saved_friends")
    }
    
    // MARK: - Friends Management
    func addFriend(name: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return false }
        guard !friends.contains(cleanName) else { return false }
        friends.append(cleanName)
        saveFriendsToDisk()
        return true
    }
    
    func removeFriend(name: String) {
        friends.removeAll { $0 == name }
        saveFriendsToDisk()
    }
    
    // MARK: - Character & Clan Sync
    /// Client-safe profile sync. Economy / energy / stats / equip / clanId are CF-only.
    private static let clientWritableUserKeys: Set<String> = [
        "id", "username", "usernameLower", "selectedClass",
        "avatarName", "currentLevel", "lastActive", "lastHealthSyncDate", "fcmToken",
        "gold", "clanId", "stats" // gold decrease-only; clanId for join/leave; stats = rep counters
    ]

    func syncCharacter(_ character: Character) {
        var updated = character
        updated.currentLevel = updated.level
        self.currentCharacter = updated
        writeWidgetSnapshot(from: updated)

        guard var data = try? Firestore.Encoder().encode(updated) as? [String: Any] else { return }
        data["usernameLower"] = updated.username.lowercased()
        data = data.filter { Self.clientWritableUserKeys.contains($0.key) }
        // Merge so we never wipe sibling-app or server-owned economy fields.
        Firestore.firestore().collection("users").document(updated.id).setData(data, merge: true)
    }

    private func writeWidgetSnapshot(from character: Character) {
        WidgetSharedData.write(
            level: character.level,
            xp: character.xp,
            nextLevelXp: character.xpForNextLevel,
            gold: character.gold,
            username: character.username,
            className: character.selectedClass.rawValue.uppercased()
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func syncClan(_ clan: Clan) {
        do {
            var clanCopy = clan
            clanCopy.syncMemberIds()
            let ref = Firestore.firestore().collection("clans").document(clanCopy.id)
            ref.getDocument { snap, _ in
                do {
                    var data = (try Firestore.Encoder().encode(clanCopy)) as? [String: Any] ?? [:]
                    data.removeValue(forKey: "activeWar")
                    if snap?.exists == true {
                        // Existing clan: never overwrite trophies (CF-owned)
                        data.removeValue(forKey: "trophies")
                        ref.setData(data, merge: true)
                    } else {
                        // Create: starter trophies required by rules
                        data["trophies"] = 1000
                        ref.setData(data, merge: false)
                    }
                } catch {
                    DispatchQueue.main.async { self.lastActionError = "Failed to sync clan." }
                    print("Failed to sync clan: \(error)")
                }
            }
        } catch {
            DispatchQueue.main.async { self.lastActionError = "Failed to sync clan." }
            print("Failed to sync clan: \(error)")
        }
    }
    
    /// Optimistic local update + server award. Online PvP must use `resolvePvPBattle(battleId:)`.
    func awardBattleRewards(xp: Int, gold: Int, isPvP: Bool = false, isPvPWinner: Bool? = nil, reason: String = "activity") {
        // Offline/local PvP must not mint economy or trophies (use online resolvePvPBattle).
        if isPvP {
            print("Skipping server mint for local/offline PvP — use resolvePvPBattle for ranked rewards.")
            return
        }
        guard var char = currentCharacter else { return }
        _ = char.addXP(xp)
        char.gold += gold
        self.currentCharacter = char
        writeWidgetSnapshot(from: char)

        Task {
            do {
                _ = try await Functions.functions().httpsCallable("awardActivityRewards").call([
                    "xp": xp,
                    "gold": gold,
                    "reason": reason
                ])
                if gold > 0 {
                    DailyQuestProgressStore.record(.goldEarned, amount: gold)
                }
            } catch {
                await MainActor.run {
                    self.lastActionError = "Couldn't save rewards. Check your connection."
                }
                print("awardActivityRewards failed: \(error)")
            }
        }

        if let clan = userClan {
            let ref = Firestore.firestore().collection("clans").document(clan.id)
            ref.updateData([
                "totalReps": FieldValue.increment(Int64(10))
            ])
            var updatedClan = clan
            if let index = updatedClan.members.firstIndex(where: { $0.id == char.id }) {
                updatedClan.members[index].repsContributed += 10
                updatedClan.totalReps += 10
                self.userClan = updatedClan
            }
        }
    }

    func resolvePvPBattle(battleId: String) {
        Task {
            do {
                let result = try await Functions.functions().httpsCallable("resolvePvPBattle").call([
                    "battleId": battleId
                ])
                if let data = result.data as? [String: Any],
                   let outcome = data["outcome"] as? String,
                   outcome == "win" {
                    DailyQuestProgressStore.record(.pvpMatch)
                }
            } catch {
                await MainActor.run {
                    self.lastActionError = "Couldn't settle PvP rewards."
                }
                print("resolvePvPBattle failed: \(error)")
            }
        }
    }
    
    func awardWorkoutRewards(reps: Int) -> (xp: Int, gold: Int) {
        guard var char = currentCharacter else { return (0, 0) }

        let used = CameraTrackingVM.freeTrainingRepsUsedToday()
        let remaining = max(0, CameraTrackingVM.freeTrainingDailyCapPublic - used)
        let cappedReps = min(reps, remaining, 50)
        if cappedReps <= 0 {
            lastActionError = "Daily practice limit reached (50 reps)."
            return (0, 0)
        }
        let baseXP = cappedReps > 0 ? 10 : 0
        let baseGold = cappedReps > 0 ? 3 : 0
        let xpReward = baseXP + (cappedReps * 6)
        let goldReward = baseGold + Int(Double(cappedReps) * 1.5)
        
        _ = char.addXP(xpReward)
        char.gold += goldReward
        
        switch char.selectedClass {
        case .archer: char.stats.totalSquats += cappedReps
        case .mage: char.stats.totalPushups += cappedReps
        case .swordsman: char.stats.totalPullups += cappedReps
        case .healer: char.stats.totalDips += cappedReps
        }
        
        self.currentCharacter = char
        writeWidgetSnapshot(from: char)
        syncCharacter(char) // stats only — gold/xp via CF below
        
        if xpReward > 0 || goldReward > 0 {
            Task {
                do {
                    _ = try await Functions.functions().httpsCallable("awardActivityRewards").call([
                        "xp": xpReward,
                        "gold": goldReward,
                        "reason": "workout"
                    ])
                } catch {
                    await MainActor.run {
                        self.lastActionError = "Couldn't save workout rewards."
                    }
                    print("awardWorkoutRewards CF failed: \(error)")
                }
            }
        }
        
        if cappedReps > 0 {
            DailyQuestProgressStore.recordExercise(for: char.selectedClass, amount: cappedReps)
        }
        
        if cappedReps > 0, let clan = userClan {
            let ref = Firestore.firestore().collection("clans").document(clan.id)
            ref.updateData([
                "totalReps": FieldValue.increment(Int64(cappedReps))
            ])
            
            var updatedClan = clan
            if let index = updatedClan.members.firstIndex(where: { $0.id == char.id }) {
                updatedClan.members[index].repsContributed += cappedReps
                updatedClan.totalReps += cappedReps
                self.userClan = updatedClan
            }
        }
        
        return (xpReward, goldReward)
    }
    
    // MARK: - Matchmaking & Real-Time PvP
    // MARK: - Game Loop
    // Real combat execution is now handled by MultiplayerService and BattleEngine
    

    // MARK: - Server Integrations
    func resolvePvEBattle(won: Bool, bossLootChance: Double, xp: Int, gold: Int, completion: @escaping (String?) -> Void) {
        let functions = Functions.functions()
        functions.httpsCallable("resolvePvEBattle").call([
            "won": won,
            "bossLootChance": bossLootChance,
            "xp": xp,
            "gold": gold
        ]) { result, error in
            if let error = error {
                print("Error resolving PvE battle on server: \(error)")
                completion(nil)
                return
            }
            if let data = result?.data as? [String: Any],
               let droppedItemId = data["droppedItemId"] as? String {
                completion(droppedItemId)
            } else {
                completion(nil)
            }
        }
    }
    
    func attackWorldBoss(damage: Int) {
        guard damage > 0 else { return }
        let functions = Functions.functions()
        Task {
            do {
                _ = try await functions.httpsCallable("attackWorldBoss").call(["damage": min(damage, 50000)])
            } catch {
                await MainActor.run {
                    self.lastActionError = "World Boss attack failed. Energy may not have been charged."
                }
                print("Error attacking world boss: \(error)")
            }
        }
    }
    // MARK: - Clan Operations
    func createClan(name: String, description: String, emblem: String) {
        guard let char = currentCharacter else { return }
        let member = ClanMember(
            id: char.id,
            username: char.username,
            level: char.level,
            characterClass: char.selectedClass,
            role: .leader
        )
        
        let newClan = Clan(
            id: "clan_\(UUID().uuidString.prefix(6))",
            name: name,
            description: description,
            emblem: emblem,
            leaderId: char.id,
            members: [member],
            memberIds: [char.id],
            trophies: 1000
        )
        
        self.userClan = newClan
        self.syncClan(newClan)
        
        var updatedChar = char
        updatedChar.clanId = newClan.id
        syncCharacter(updatedChar)
    }
    
    func sendFriendRequest(to targetUid: String) async {
        guard let char = currentCharacter else { return }
        let functions = Functions.functions()
        do {
            _ = try await functions.httpsCallable("sendFriendRequest").call(["targetUid": targetUid])
            // Notify the target player so they see the request immediately
            NotificationManager.sendInAppNotification(
                to: targetUid,
                title: "New Friend Request!",
                message: "\(char.username) wants to be your friend. Check the Friends list to accept.",
                type: .system,
                actionData: ["type": "friendRequest", "senderUid": char.id]
            )
        } catch {
            print("Failed to send friend request: \(error)")
        }
    }
    
    /// Search players by username prefix or UID. Uses native Firestore queries to ensure Timestamps decode properly.
    func searchPlayers(query: String) async -> [Character] {
        guard query.count >= 2 else { return [] }
        
        let lowerQuery = query.lowercased()
        let db = Firestore.firestore()
        var results: [Character] = []
        
        do {
            // 1. Prefix search using usernameLower
            let snap = try await db.collection("users")
                .whereField("usernameLower", isGreaterThanOrEqualTo: lowerQuery)
                .whereField("usernameLower", isLessThan: lowerQuery + "\u{f8ff}")
                .limit(to: 20)
                .getDocuments()
            
            results = snap.documents.compactMap { try? $0.data(as: Character.self) }
            
            // 2. Fallback: exact username match
            if results.isEmpty {
                let exactSnap = try await db.collection("users")
                    .whereField("username", isEqualTo: query)
                    .limit(to: 5)
                    .getDocuments()
                results = exactSnap.documents.compactMap { try? $0.data(as: Character.self) }
            }
            
            // 3. Fallback: direct UID lookup if it looks like a UID
            if results.isEmpty && query.count >= 20 {
                let doc = try await db.collection("users").document(query).getDocument()
                if let char = try? doc.data(as: Character.self) {
                    results.append(char)
                }
            }
            
            return results.filter { $0.id != self.currentCharacter?.id }
        } catch {
            print("searchPlayers failed: \(error)")
            return []
        }
    }
    
    /// Remove a friend by UID from both users
    func removeFriendByUid(_ uid: String) async {
        guard var char = currentCharacter else { return }
        char.friends = char.unwrappedFriends.filter { $0 != uid }
        syncCharacter(char)
        // Also remove ourselves from their friends list via Firestore
        try? await Firestore.firestore().collection("users").document(uid).updateData([
            "friends": FieldValue.arrayRemove([char.id])
        ])
    }
    
    func fetchCharacters(byUids uids: [String]) async -> [Character] {
        guard !uids.isEmpty else { return [] }
        var characters: [Character] = []
        do {
            for i in stride(from: 0, to: uids.count, by: 10) {
                let end = min(i + 10, uids.count)
                let chunk = Array(uids[i..<end])
                let snapshot = try await Firestore.firestore().collection("users")
                    .whereField("id", in: chunk)
                    .getDocuments()
                for doc in snapshot.documents {
                    if let char = try? doc.data(as: Character.self) {
                        characters.append(char)
                    }
                }
            }
        } catch {
            print("Failed to fetch characters: \(error)")
        }
        return characters
    }
    
    func acceptFriendRequest(from uid: String) async {
        let functions = Functions.functions()
        do {
            _ = try await functions.httpsCallable("acceptFriendRequest").call(["senderUid": uid])
        } catch {
            print("Failed to accept friend request: \(error)")
        }
    }
    
    func declineFriendRequest(from uid: String) {
        let functions = Functions.functions()
        functions.httpsCallable("declineFriendRequest").call(["senderUid": uid]) { _, error in
            if let error = error {
                print("Failed to decline friend request: \(error)")
            }
        }
    }
    
    func startFriendDuel(playerClass: CharacterClass, friendName: String, friendClass: CharacterClass, completion: @escaping (Bool) -> Void) {
        // Look up friend's UID in Firestore by username, then challenge them.
        // Never fall back to bot matchmaking — that fakes a successful friend duel.
        Task {
            let db = Firestore.firestore()
            do {
                let snapshot = try await db.collection("users")
                    .whereField("username", isEqualTo: friendName)
                    .limit(to: 1)
                    .getDocuments()
                
                if let friendDoc = snapshot.documents.first {
                    let friendUid = friendDoc.documentID
                    await MainActor.run {
                        MultiplayerService.shared.challengeFriend(friendUid: friendUid)
                        completion(true)
                    }
                } else {
                    await MainActor.run {
                        MultiplayerService.shared.matchmakingError =
                            "Couldn't find \(friendName) online. Ask them to open FitRPG, then try again."
                        completion(false)
                    }
                }
            } catch {
                print("startFriendDuel error: \(error)")
                await MainActor.run {
                    MultiplayerService.shared.matchmakingError =
                        "Couldn't start duel with \(friendName). Check your connection and try again."
                    completion(false)
                }
            }
        }
    }
    
    func consumeEnergy(amount: Int) -> Bool {
        guard amount > 0 else { return false }
        applyEnergyRegenIfNeeded()
        guard var char = currentCharacter else { return false }
        guard char.energy >= amount else { return false }
        
        char.energy -= amount
        self.currentCharacter = char
        scheduleEnergyRestoredNotification(for: char.energy, maxEnergy: char.maxEnergy)
        Task {
            do {
                let result = try await Functions.functions().httpsCallable("adjustEnergy").call([
                    "op": "spend", "amount": amount
                ])
                if let data = result.data as? [String: Any], let energy = data["energy"] as? Int {
                    await MainActor.run {
                        self.currentCharacter?.energy = energy
                    }
                }
            } catch {
                await MainActor.run {
                    // Roll back optimistic spend
                    if var c = self.currentCharacter {
                        c.energy = min(c.maxEnergy, c.energy + amount)
                        self.currentCharacter = c
                    }
                    self.lastActionError = "Not enough energy (server)."
                }
            }
        }
        return true
    }

    func refundEnergy(amount: Int) {
        guard amount > 0 else { return }
        guard var char = currentCharacter else { return }
        char.energy = min(char.maxEnergy, char.energy + amount)
        self.currentCharacter = char
        Task {
            do {
                let result = try await Functions.functions().httpsCallable("adjustEnergy").call([
                    "op": "refund", "amount": amount
                ])
                if let data = result.data as? [String: Any], let energy = data["energy"] as? Int {
                    await MainActor.run { self.currentCharacter?.energy = energy }
                }
            } catch {
                await MainActor.run {
                    self.lastActionError = "Couldn't refund energy."
                }
            }
        }
    }
    
    // MARK: - Energy Regeneration
    
    private func energyRegenDefaultsKey(for uid: String) -> String {
        "lastEnergyRegenAt_\(uid)"
    }
    
    func applyEnergyRegenIfNeeded() {
        guard var char = currentCharacter else { return }
        let key = energyRegenDefaultsKey(for: char.id)
        let now = Date()
        
        if char.energy >= char.maxEnergy {
            UserDefaults.standard.set(now, forKey: key)
            return
        }
        
        let lastTick = UserDefaults.standard.object(forKey: key) as? Date ?? now
        let elapsed = now.timeIntervalSince(lastTick)
        let pointsToAdd = Int(elapsed / Self.energyRegenInterval)
        guard pointsToAdd > 0 else { return }
        
        // Local preview only — persist via adjustEnergy regen
        char.energy = min(char.maxEnergy, char.energy + pointsToAdd)
        let advancedLastTick = lastTick.addingTimeInterval(Double(pointsToAdd) * Self.energyRegenInterval)
        UserDefaults.standard.set(advancedLastTick, forKey: key)
        self.currentCharacter = char
        
        Task {
            do {
                let result = try await Functions.functions().httpsCallable("adjustEnergy").call(["op": "regen"])
                if let data = result.data as? [String: Any], let energy = data["energy"] as? Int {
                    await MainActor.run { self.currentCharacter?.energy = energy }
                }
            } catch {
                print("adjustEnergy regen failed: \(error)")
            }
        }
        
        if char.energy < char.maxEnergy {
            let secondsUntilNext = Self.energyRegenInterval - now.timeIntervalSince(advancedLastTick)
            NotificationManager.shared.scheduleEnergyRestored(
                inSeconds: max(1, secondsUntilNext + Double(char.maxEnergy - char.energy - 1) * Self.energyRegenInterval)
            )
        }
    }
    
    private func startEnergyRegenTimerIfNeeded() {
        guard energyRegenTimer == nil else { return }
        energyRegenTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.applyEnergyRegenIfNeeded()
        }
    }
    
    private func scheduleEnergyRestoredNotification(for energy: Int, maxEnergy: Int) {
        guard energy < maxEnergy else { return }
        let remaining = maxEnergy - energy
        NotificationManager.shared.scheduleEnergyRestored(inSeconds: TimeInterval(remaining) * Self.energyRegenInterval)
    }
    
    func handleHealthSync(result: HealthSyncResult) {
        guard var char = currentCharacter else { return }
        
        char.energy = min(char.maxEnergy, char.energy + result.energyGained)
        char.lastHealthSyncDate = Date()
        // Optimistic UI for gold/xp; persist via CF (rules block client increases)
        _ = char.addXP(result.xpGained)
        char.gold += result.goldGained
        self.currentCharacter = char
        writeWidgetSnapshot(from: char)
        syncCharacter(char)
        
        if result.xpGained > 0 || result.goldGained > 0 {
            Task {
                do {
                    _ = try await Functions.functions().httpsCallable("awardActivityRewards").call([
                        "xp": min(result.xpGained, 400),
                        "gold": min(result.goldGained, 200),
                        "reason": "health_sync"
                    ])
                } catch {
                    print("health sync rewards failed: \(error)")
                }
            }
        }
        
        if result.steps > 0 {
            DailyQuestProgressStore.record(.steps, amount: result.steps)
        }
        if result.activeCalories > 0 {
            DailyQuestProgressStore.record(.calories, amount: Int(result.activeCalories))
        }
        if result.goldGained > 0 {
            DailyQuestProgressStore.record(.goldEarned, amount: result.goldGained)
        }
        
        if result.damageDealt > 0 {
            // Opt-in: Health sync no longer auto-attacks World Boss without confirmation.
            // Damage is stored on the result UI; user attacks from Raids tab.
            print("Health sync dealt \(result.damageDealt) potential WB damage — attack from Raids tab.")
        }
    }
    
    func updateClanDescription(description: String) {
        guard var clan = userClan else { return }
        clan.description = description
        self.userClan = clan
        self.syncClan(clan)
    }
    
    func depositClanGold(amount: Int) {
        guard var char = currentCharacter else { return }
        guard var clan = userClan else { return }
        guard char.gold >= amount else { return }
        
        char.gold -= amount
        self.currentCharacter = char
        self.syncCharacter(char)
        
        let currentTreasury = clan.treasuryGold ?? 0
        clan.treasuryGold = currentTreasury + amount
        self.userClan = clan
        self.syncClan(clan)
    }
    
    func joinClan(_ clan: Clan) {
        guard let char = currentCharacter else { return }
        // Person can only be in one clan: enforce leaving first if they belong to one
        if char.clanId != nil {
            leaveClan()
        }
        
        var updatedClan = clan
        // Enforce membership limits
        guard updatedClan.members.count < updatedClan.maxMembers else { return }
        
        let member = ClanMember(
            id: char.id,
            username: char.username,
            level: char.level,
            characterClass: char.selectedClass,
            role: .member
        )
        
        updatedClan.members.append(member)
        updatedClan.syncMemberIds()
        self.userClan = updatedClan
        self.syncClan(updatedClan)
        
        var updatedChar = currentCharacter ?? char
        updatedChar.clanId = updatedClan.id
        syncCharacter(updatedChar)
    }
    
    func changeMemberRole(memberId: String, newRole: ClanRole) {
        guard var clan = userClan else { return }
        
        if newRole == .leader {
            clan.leaderId = memberId
            for i in 0..<clan.members.count {
                if clan.members[i].id == memberId {
                    clan.members[i].role = .leader
                } else if clan.members[i].role == .leader {
                    clan.members[i].role = .member // Demote old leader to member
                }
            }
        } else {
            for i in 0..<clan.members.count {
                if clan.members[i].id == memberId {
                    clan.members[i].role = newRole
                }
            }
        }
        
        self.userClan = clan
        self.syncClan(clan)
    }
    func kickMember(memberId: String) {
        guard var clan = userClan else { return }
        clan.members.removeAll(where: { $0.id == memberId })
        self.userClan = clan
        self.syncClan(clan)
    }
    
    func disbandClan() {
        guard let char = currentCharacter, let clan = userClan else { return }
        if clan.leaderId == char.id {
            self.userClan = nil
            // Delete clan document
            Firestore.firestore().collection("clans").document(clan.id).delete()
            
            var updatedChar = char
            updatedChar.clanId = nil
            syncCharacter(updatedChar)
        }
    }
    
    func leaveClan() {
        guard let char = currentCharacter, var clan = userClan else { return }
        
        clan.members.removeAll(where: { $0.id == char.id })
        
        if clan.members.isEmpty {
            self.userClan = nil
            Firestore.firestore().collection("clans").document(clan.id).delete()
        } else {
            // Assign next leader if leaving leader
            if clan.leaderId == char.id {
                if let nextLeader = clan.members.first {
                    clan.leaderId = nextLeader.id
                    if let idx = clan.members.firstIndex(where: { $0.id == nextLeader.id }) {
                        clan.members[idx].role = .leader
                    }
                }
            }
            self.userClan = nil
            self.syncClan(clan)
        }
        
        var updatedChar = char
        updatedChar.clanId = nil
        syncCharacter(updatedChar)
    }
    
    func startClanWar() {
        guard userClan != nil else { return }

        Task {
            do {
                let functions = Functions.functions()
                let result = try await functions.httpsCallable("matchmakeClanWar").call()
                if let data = result.data as? [String: Any] {
                    let opponent = data["opponentName"] as? String ?? "Unknown"
                    let isBot = data["isBot"] as? Bool ?? false
                    print("Clan war started vs \(opponent) (bot: \(isBot))")
                }
                // Clan listener picks up server-written activeWar state
            } catch {
                print("Error starting clan war: \(error.localizedDescription)")
                await MainActor.run {
                    self.lastActionError = "Couldn't start clan war. Try again in a moment."
                }
            }
        }
    }

    func cancelClanWarSearch() {
        guard userClan?.activeWar?.phase == .searching else { return }
        Task {
            do {
                let functions = Functions.functions()
                _ = try await functions.httpsCallable("cancelClanWarSearch").call()
                // Clan listener clears activeWar from server write
            } catch {
                print("Error canceling clan war search: \(error.localizedDescription)")
                await MainActor.run {
                    self.lastActionError = "Couldn't cancel war search. Try again."
                }
            }
        }
    }

    func contributeWarScore(points: Int) {
        guard points > 0 else { return }
        recordClanWarAttack(won: true)
    }

    func recordClanWarAttack(won: Bool) {
        Task {
            do {
                let functions = Functions.functions()
                _ = try await functions.httpsCallable("recordClanWarAttack").call(["won": won])
                // Clan listener reflects server-updated scores and member stats
            } catch {
                print("Error recording clan war attack: \(error.localizedDescription)")
                await MainActor.run {
                    self.lastActionError = "War attack failed. No score was recorded — try again."
                }
            }
        }
    }

    func recordClanWarBattle(won: Bool) {
        recordClanWarAttack(won: won)
    }
    
    // MARK: - Leaderboard Fetch
    func fetchLeaderboards() {
        fetchLeaderboards(for: ["global", "pvp_1v1", "Archer", "Mage", "Swordsman", "Healer"])
    }

    func fetchLeaderboards(for types: [String]) {
        // Run native Firestore query for accurate timestamp decoding and real-time reflection
        fetchLeaderboardsFallback(for: types)
    }

    private func fetchLeaderboardsFallback(for types: [String]) {
        // Direct Firestore fallback (no server-side sort guarantee for composite queries)
        let db = Firestore.firestore()

        // Always fetch global — order by currentLevel (stored field, updated on every login)
        db.collection("users")
            .order(by: "currentLevel", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, let docs = snapshot?.documents else { return }
                let players = docs.compactMap { try? $0.data(as: Character.self) }
                DispatchQueue.main.async {
                    self.leaderboards["global"] = players
                    self.leaderboards["friends"] = players.filter { self.friends.contains($0.username) }
                }
            }

        // Fetch pvp_1v1 sorted by pvpTrophies
        if types.contains("pvp_1v1") {
            db.collection("users")
                .order(by: "pvpTrophies", descending: true)
                .limit(to: 50)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self, let docs = snapshot?.documents else { return }
                    let players = docs.compactMap { try? $0.data(as: Character.self) }
                    DispatchQueue.main.async { self.leaderboards["pvp_1v1"] = players }
                }
        }
        
        // Fetch per-class boards — order by currentLevel, filter + sort by classTrophies in memory
        let classTypes = types.filter { CharacterClass.allCases.map { $0.rawValue }.contains($0) }
        if !classTypes.isEmpty {
            db.collection("users")
                .order(by: "currentLevel", descending: true)
                .limit(to: 200)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self, let docs = snapshot?.documents else { return }
                    let allPlayers = docs.compactMap { try? $0.data(as: Character.self) }
                    DispatchQueue.main.async {
                        for classType in classTypes {
                            guard let cls = CharacterClass(rawValue: classType) else { continue }
                            // Filter: players who have interacted with this class
                            let filtered = allPlayers.filter { player in
                                let classLevel = player.progressions[cls.rawValue]?.level ?? 1
                                let trophies = player.trophies(for: cls)
                                return classLevel > 1 || trophies > 0 || player.selectedClass == cls
                            }
                            // Sort by per-class trophies descending
                            let sorted = filtered.sorted { $0.trophies(for: cls) > $1.trophies(for: cls) }
                            self.leaderboards[classType] = Array(sorted.prefix(30))
                        }
                    }
                }
        }
    }
    
    func equipItem(itemId: String, slot: EquipmentSlot) {
        Task {
            do {
                let functions = Functions.functions()
                _ = try await functions.httpsCallable("equipItem").call([
                    "itemId": itemId,
                    "slot": slot.rawValue
                ])
                DailyQuestProgressStore.record(.equipItem)
                // Character listener refreshes equipped ids from Firestore
            } catch {
                print("Error equipping item: \(error.localizedDescription)")
            }
        }
    }

    func purchaseItem(itemId: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                let functions = Functions.functions()
                let result = try await functions.httpsCallable("purchaseItem").call(["itemId": itemId])
                let data = result.data as? [String: Any]
                let already = data?["alreadyOwned"] as? Bool ?? false
                completion(true, already ? "Already owned" : "Purchase complete!")
            } catch {
                let message = (error as NSError).localizedDescription
                if message.lowercased().contains("gold") {
                    completion(false, "Not enough gold!")
                } else {
                    completion(false, "Purchase failed. Try again.")
                }
            }
        }
    }

    /// FitRPG UGC report — writes to shared `reports` collection (rules: app == fitrpg).
    func submitUserReport(targetUid: String, reason: String, completion: @escaping (Bool, String?) -> Void) {
        guard let reporterUid = Auth.auth().currentUser?.uid else {
            completion(false, "Sign in to submit a report.")
            return
        }
        guard reporterUid != targetUid else {
            completion(false, "You cannot report yourself.")
            return
        }

        let payload: [String: Any] = [
            "reporterUid": reporterUid,
            "targetUid": targetUid,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
            "app": "fitrpg"
        ]

        Firestore.firestore().collection("reports").addDocument(data: payload) { error in
            if let error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }
    
    // MARK: - FCM Token
    func updateFCMToken(_ token: String) {
        guard var char = currentCharacter else { return }
        char.fcmToken = token
        // Persist to Firestore without triggering full character sync overhead
        Firestore.firestore().collection("users").document(char.id).updateData(["fcmToken": token])
    }

    // MARK: - Account deletion (FitRPG data only — preserves shared users/{uid} fields for other apps)

    /// FitRPG-specific Firestore field keys stored on `users/{uid}`.
    private static let fitRPGUserFieldKeys: [String] = [
        "username", "usernameLower", "selectedClass", "energy", "maxEnergy", "basePower", "gold",
        "avatarName", "statPoints", "baseStrength", "baseDexterity", "baseIntelligence", "baseVitality",
        "stats", "equippedWeaponId", "equippedArmorId", "equippedRingId", "equippedAmuletId",
        "ownedEquipmentIds", "clanId", "pvpWins", "pvpTrophies", "friends", "friendRequests",
        "currentLevel", "classTrophies", "lastActive", "lastHealthSyncDate", "progressions"
    ]

    /// Removes FitRPG game data via CF (scoped). Does not wipe sibling-app fields or Auth.
    func deleteFitRPGAccountData(uid: String) async throws {
        _ = try await Functions.functions().httpsCallable("cleanupFitRPGAccount").call([:])

        if currentCharacter?.clanId != nil {
            // Best-effort local clan clear; server already removed membership.
        }

        characterListener?.remove()
        clanListener?.remove()
        currentListenedClanId = nil
        currentCharacter = nil
        userClan = nil
        friends = []
        UserDefaults.standard.removeObject(forKey: "saved_character")
        UserDefaults.standard.removeObject(forKey: "saved_friends")
        _ = uid
    }
}
