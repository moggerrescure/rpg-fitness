import Foundation
import Combine
import FirebaseFunctions
import FirebaseFirestore
import FirebaseAuth

class FirebaseService: ObservableObject {
    @Published var currentCharacter: Character?
    @Published var activeBattle: Battle?
    @Published var userClan: Clan?
    @Published var leaderboards: [String: [Character]] = [:]
    @Published var friends: [String] = []
    @Published var activeWorldBoss: WorldBoss?
    
    private var cancellables = Set<AnyCancellable>()
    private var battleTimer: Timer?
    
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
        worldBossListener = Firestore.firestore().collection("world_bosses")
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let doc = snapshot?.documents.first,
                   let boss = try? doc.data(as: WorldBoss.self) {
                    DispatchQueue.main.async { self.activeWorldBoss = boss }
                } else {
                    // No active world boss – create one locally so raids still work
                    DispatchQueue.main.async { self.ensureWorldBossExists() }
                }
            }
    }
    
    private func ensureWorldBossExists() {
        if activeWorldBoss == nil {
            let template = Boss.templates.last! // Use strongest boss (dragon)
            let newBoss = WorldBoss(
                id: "current",
                bossTemplateId: template.id,
                maxHealth: template.maxHealth,
                currentHealth: template.maxHealth,
                isActive: true,
                startedAt: Date(),
                topAttackers: [:]
            )
            // Store locally so raids work immediately
            self.activeWorldBoss = newBoss
            // Try to persist to Firestore in background
            Task {
                try? Firestore.firestore().collection("world_bosses").document(newBoss.id).setData(from: newBoss)
            }
        }
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
    func syncCharacter(_ character: Character) {
        var updated = character
        updated.currentLevel = updated.level
        self.currentCharacter = updated
        // Write to Firestore — the snapshot listener will update currentCharacter reactively
        // Also write usernameLower for server-side prefix search
        if var data = try? Firestore.Encoder().encode(updated) as? [String: Any] {
            data["usernameLower"] = updated.username.lowercased()
            Firestore.firestore().collection("users").document(updated.id).setData(data)
        } else {
            try? Firestore.firestore().collection("users").document(updated.id).setData(from: updated)
        }
    }
    
    func syncClan(_ clan: Clan) {
        do {
            try Firestore.firestore().collection("clans").document(clan.id).setData(from: clan)
        } catch {
            print("Failed to sync clan: \(error)")
        }
    }
    
    func awardBattleRewards(xp: Int, gold: Int, isPvP: Bool = false, isPvPWinner: Bool? = nil) {
        guard var char = currentCharacter else { return }
        let leveledUp = char.addXP(xp)
        if leveledUp {
            // Level up handled by UI observers via currentCharacter change
        }
        char.gold += gold
        if isPvP {
            if let isWinner = isPvPWinner {
                // Update per-class trophies for the currently active class
                let cls = char.selectedClass.rawValue
                var dict = char.classTrophies ?? Dictionary(
                    uniqueKeysWithValues: CharacterClass.allCases.map { ($0.rawValue, 0) }
                )
                let current = dict[cls] ?? 0
                if isWinner {
                    char.pvpWins = char.unwrappedPvPWins + 1
                    dict[cls] = current + 50
                } else {
                    dict[cls] = max(0, current - 50)
                }
                char.classTrophies = dict
                // Also keep pvpTrophies as the current-class value (for legacy 1v1 leaderboard)
                char.pvpTrophies = dict[cls]
            }
        }
        self.currentCharacter = char
        syncCharacter(char)
        
        // If in clan, contribute reps via increment to avoid overwriting
        if let clan = userClan {
            let ref = Firestore.firestore().collection("clans").document(clan.id)
            ref.updateData([
                "totalReps": FieldValue.increment(Int64(10))
            ])
            // We can't easily increment a specific array element in Firestore, so we update it locally for UI
            var updatedClan = clan
            if let index = updatedClan.members.firstIndex(where: { $0.id == char.id }) {
                updatedClan.members[index].repsContributed += 10
                updatedClan.totalReps += 10
                self.userClan = updatedClan
            }
        }
    }
    
    func awardWorkoutRewards(reps: Int) -> (xp: Int, gold: Int) {
        guard var char = currentCharacter else { return (0, 0) }
        
        // General workouts yield fewer rewards: 6 XP and 1.5 Gold per rep, base of 10 XP and 3 Gold if at least 1 rep is done
        let baseXP = reps > 0 ? 10 : 0
        let baseGold = reps > 0 ? 3 : 0
        let xpReward = baseXP + (reps * 6)
        let goldReward = baseGold + Int(Double(reps) * 1.5)
        
        _ = char.addXP(xpReward)
        char.gold += goldReward
        
        // Contribute to total reps stats for the active class
        switch char.selectedClass {
        case .archer: char.stats.totalSquats += reps
        case .mage: char.stats.totalPushups += reps
        case .swordsman: char.stats.totalPullups += reps
        case .healer: char.stats.totalDips += reps
        }
        
        self.currentCharacter = char
        syncCharacter(char)
        
        // If in a clan, contribute these reps to the member contribution & total clan reps
        if reps > 0, let clan = userClan {
            let ref = Firestore.firestore().collection("clans").document(clan.id)
            ref.updateData([
                "totalReps": FieldValue.increment(Int64(reps))
            ])
            
            var updatedClan = clan
            if let index = updatedClan.members.firstIndex(where: { $0.id == char.id }) {
                updatedClan.members[index].repsContributed += reps
                updatedClan.totalReps += reps
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
        // Server limit is 5000 per call — split large values into sequential chunks
        let chunkSize = 5000
        let chunks = stride(from: 0, to: damage, by: chunkSize).map {
            min(chunkSize, damage - $0)
        }
        Task {
            for chunk in chunks {
                do {
                    _ = try await functions.httpsCallable("attackWorldBoss").call(["damage": chunk])
                } catch {
                    print("Error attacking world boss (chunk \(chunk)): \(error)")
                }
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
        // Look up friend's UID in Firestore by username, then challenge them
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
                    // Friend not found in Firestore — fall back to local bot duel with friend's stats
                    await MainActor.run {
                        // Start a regular 1v1 with bot using friend class
                        MultiplayerService.shared.startMatchmaking(for: playerClass, type: .duel1v1)
                        completion(true)
                    }
                }
            } catch {
                print("startFriendDuel error: \(error)")
                await MainActor.run {
                    MultiplayerService.shared.startMatchmaking(for: playerClass, type: .duel1v1)
                    completion(true)
                }
            }
        }
    }
    
    func consumeEnergy(amount: Int) -> Bool {
        guard let char = currentCharacter else { return false }
        if char.energy >= amount {
            var updated = char
            updated.energy -= amount
            syncCharacter(updated)
            return true
        }
        return false
    }
    
    func handleHealthSync(result: HealthSyncResult) {
        guard var char = currentCharacter else { return }
        
        var prog = char.progressions[char.selectedClass.rawValue] ?? ClassProgression()
        
        prog.xp += result.xpGained
        char.energy = min(char.maxEnergy, char.energy + result.energyGained)
        char.gold += result.goldGained
        char.lastHealthSyncDate = Date()
        
        var leveledUp = false
        while prog.xp >= (prog.level * 150) {
            prog.xp -= (prog.level * 150)
            prog.level += 1
            char.maxEnergy += 10
            char.energy = char.maxEnergy
            leveledUp = true
        }
        
        char.progressions[char.selectedClass.rawValue] = prog
        
        if result.damageDealt > 0 {
            attackWorldBoss(damage: result.damageDealt)
        }
        
        syncCharacter(char)
        
        if leveledUp {
            print("Leveled up to \(prog.level)!")
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
        guard var clan = userClan else { return }
        
        // Show "searching" state immediately
        let endsAt = Date().addingTimeInterval(3600) // 1 hour search timeout roughly
        clan.activeWar = ClanWar(
            phase: .searching,
            phaseEndsAt: endsAt,
            opponentClanId: nil,
            opponentClanName: nil,
            myClanScore: 0,
            opponentClanScore: 0
        )
        self.userClan = clan
        self.syncClan(clan)
        
        Task {
            do {
                let db = Firestore.firestore()
                // Search for an opponent searching for war
                let snapshot = try await db.collection("matchmaking")
                    .whereField("type", isEqualTo: "clan_war")
                    .whereField("status", isEqualTo: "searching")
                    .limit(to: 5)
                    .getDocuments()
                
                // Find first ticket not from our clan
                if let doc = snapshot.documents.first(where: { ($0.data()["clanId"] as? String) != clan.id }),
                   let opponentClanId = doc.data()["clanId"] as? String {
                    
                    // Claim the ticket
                    try await doc.reference.updateData(["status": "matched", "matchedWith": clan.id])
                    
                    // Fetch opponent clan
                    let oppDoc = try await db.collection("clans").document(opponentClanId).getDocument()
                    let oppName = oppDoc.data()?["name"] as? String ?? "Unknown Clan"
                    
                    let warDuration: TimeInterval = 86400 // 24 hours
                    let warEndsAt = Date().addingTimeInterval(warDuration)
                    
                    // Update My Clan
                    var myClan = clan
                    myClan.activeWar = ClanWar(phase: .active, phaseEndsAt: warEndsAt, opponentClanId: opponentClanId, opponentClanName: oppName, myClanScore: 0, opponentClanScore: 0)
                    self.syncClan(myClan)
                    
                    // Update Opponent Clan
                    if var oppClan = try? oppDoc.data(as: Clan.self) {
                        oppClan.activeWar = ClanWar(phase: .active, phaseEndsAt: warEndsAt, opponentClanId: clan.id, opponentClanName: clan.name, myClanScore: 0, opponentClanScore: 0)
                        self.syncClan(oppClan)
                    }
                } else {
                    // Create our own searching ticket
                    try await db.collection("matchmaking").addDocument(data: [
                        "type": "clan_war",
                        "clanId": clan.id,
                        "status": "searching",
                        "createdAt": FieldValue.serverTimestamp()
                    ])
                }
            } catch {
                print("Error starting clan war: \(error)")
            }
        }
    }
    
    func cancelClanWarSearch() {
        guard var clan = userClan else { return }
        
        // Remove active war locally and in DB
        clan.activeWar = nil
        self.userClan = clan
        self.syncClan(clan)
        
        Task {
            do {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("matchmaking")
                    .whereField("type", isEqualTo: "clan_war")
                    .whereField("clanId", isEqualTo: clan.id)
                    .whereField("status", isEqualTo: "searching")
                    .getDocuments()
                
                for doc in snapshot.documents {
                    try await doc.reference.delete()
                }
            } catch {
                print("Error cancelling clan war search: \(error)")
            }
        }
    }
    
    func contributeWarScore(points: Int) {
        guard var clan = userClan, let charId = currentCharacter?.id else { return }
        
        // Find my member in clan and update their stats
        if let idx = clan.members.firstIndex(where: { $0.id == charId }) {
            if points > 0 {
                clan.members[idx].warScoreContributed += points
            }
        }
        
        if var war = clan.activeWar, points > 0 {
            war.myClanScore += points
            clan.activeWar = war
        }
        
        self.userClan = clan
        self.syncClan(clan)
    }
    
    func recordClanWarBattle(won: Bool) {
        guard var clan = userClan, let charId = currentCharacter?.id else { return }
        
        if let idx = clan.members.firstIndex(where: { $0.id == charId }) {
            clan.members[idx].warAttacksUsed += 1
        }
        
        self.userClan = clan
        // Sync before contributing points to ensure attacks are saved
        self.syncClan(clan)
        
        if won {
            contributeWarScore(points: 2)
        } else {
            // Update opponent clan score locally for the loser
            guard var currentClan = userClan else { return }
            if var war = currentClan.activeWar {
                war.opponentClanScore += 2
                currentClan.activeWar = war
                self.userClan = currentClan
                self.syncClan(currentClan)
            }
        }
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
        guard var char = currentCharacter else { return }
        switch slot {
        case .weapon:
            char.equipWeapon(itemId: itemId)
        case .armor:
            char.equipArmor(itemId: itemId)
        case .ring:
            char.equipRing(itemId: itemId)
        case .amulet:
            char.equipAmulet(itemId: itemId)
        }
        syncCharacter(char)
    }
    
    // MARK: - FCM Token
    func updateFCMToken(_ token: String) {
        guard var char = currentCharacter else { return }
        char.fcmToken = token
        // Persist to Firestore without triggering full character sync overhead
        Firestore.firestore().collection("users").document(char.id).updateData(["fcmToken": token])
    }
}
