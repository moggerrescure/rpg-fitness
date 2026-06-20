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
        // Load persisted character if it exists
        if let data = UserDefaults.standard.data(forKey: "saved_character"),
           let savedChar = try? JSONDecoder().decode(Character.self, from: data) {
            self.currentCharacter = savedChar
        } else {
            // Setup initial mock character for testing
            self.currentCharacter = Character(
                id: "local_mock_user",
                username: "FitnessHero",
                selectedClass: .archer,
                level: 1,
                xp: 0,
                gold: 2400,
                energy: 100,
                maxEnergy: 100,
                basePower: 100,
                equippedArmorId: "a_arch_1"
            )
            saveCharacterToDisk()
        }
        
        // Load persisted friends list if it exists
        if let savedFriends = UserDefaults.standard.stringArray(forKey: "saved_friends") {
            self.friends = savedFriends
        }
        
        fetchLeaderboards()
        
        AuthManager.shared.$currentUser
            .compactMap { $0 }
            .sink { [weak self] user in
                self?.startListeningToCharacter(uid: user.uid)
            }
            .store(in: &cancellables)
    }
    
    private var characterListener: ListenerRegistration?
    
    func startListeningToCharacter(uid: String) {
        characterListener?.remove()
        characterListener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else { return }
                
                if snapshot.exists {
                    do {
                        let char = try snapshot.data(as: Character.self)
                        // Only update if not currently fighting to avoid UI jumps, or just update directly
                        DispatchQueue.main.async {
                            self.currentCharacter = char
                            // Backup to disk
                            if let data = try? JSONEncoder().encode(char) {
                                UserDefaults.standard.set(data, forKey: "saved_character")
                            }
                        }
                    } catch {
                        print("Error decoding character: \(error)")
                    }
                } else if let char = self.currentCharacter {
                    // Upload local character to Firestore
                    var newChar = char
                    newChar.id = uid
                    try? Firestore.firestore().collection("users").document(uid).setData(from: newChar)
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
    
    // MARK: - Character Sync
    func syncCharacter(_ character: Character) {
        self.currentCharacter = character
        saveCharacterToDisk()
        
        // Write to Firestore!
        if character.id != "local_mock_user" {
            try? Firestore.firestore().collection("users").document(character.id).setData(from: character)
        }
    }
    
    func awardBattleRewards(xp: Int, gold: Int, isPvP: Bool = false) {
        guard var char = currentCharacter else { return }
        let leveledUp = char.addXP(xp)
        char.gold += gold
        if isPvP {
            char.pvpWins += 1
            char.pvpTrophies += 25
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
        let functions = Functions.functions()
        functions.httpsCallable("attackWorldBoss").call(["damage": damage]) { result, error in
            if let error = error {
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
            trophies: 1000
        )
        
        self.userClan = newClan
        
        var updatedChar = char
        updatedChar.clanId = newClan.id
        syncCharacter(updatedChar)
    }
    
    func sendFriendRequest(to targetUid: String) async {
        guard currentCharacter != nil else { return }
        let functions = Functions.functions()
        do {
            _ = try await functions.httpsCallable("sendFriendRequest").call(["targetUid": targetUid])
        } catch {
            print("Failed to send friend request: \(error)")
        }
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
        // Mock duel start. Real logic would go through MultiplayerService.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true)
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
    }
    
    func joinClan(_ clan: Clan) {
        guard let char = currentCharacter else { return }
        // Person can only be in one clan: enforce leaving first if they belong to one
        if char.clanId != nil {
            leaveClan()
        }
        
        var updatedClan = clan
        // Enforce membership limits
        guard updatedClan.members.count < 3 else { return }
        
        let member = ClanMember(
            id: char.id,
            username: char.username,
            level: char.level,
            characterClass: char.selectedClass,
            role: .member
        )
        
        updatedClan.members.append(member)
        self.userClan = updatedClan
        
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
    }
    
    func leaveClan() {
        guard let char = currentCharacter, var clan = userClan else { return }
        
        clan.members.removeAll(where: { $0.id == char.id })
        
        if clan.members.isEmpty {
            self.userClan = nil
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
        }
        
        var updatedChar = char
        updatedChar.clanId = nil
        syncCharacter(updatedChar)
    }
    
    func startClanWar() {
        guard var clan = userClan else { return }
        let endsAt = Date().addingTimeInterval(86400) // 24 hours from now
        clan.activeWar = ClanWar(
            phase: .active,
            phaseEndsAt: endsAt,
            opponentClanId: "opponent_clan_555",
            opponentClanName: "IronBeasts",
            myClanScore: 0,
            opponentClanScore: 15
        )
        self.userClan = clan
    }
    
    func contributeWarScore(points: Int) {
        guard var clan = userClan, var war = clan.activeWar else { return }
        war.myClanScore += points
        clan.activeWar = war
        self.userClan = clan
    }
    
    func recordClanWarBattle(won: Bool) {
        let points = won ? 3 : 1
        contributeWarScore(points: points)
    }
    
    // MARK: - Leaderboard Fetch
    // MARK: - Leaderboard Fetch
    func fetchLeaderboards() {
        Firestore.firestore().collection("users")
            .order(by: "level", descending: true)
            .limit(to: 20)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, let docs = snapshot?.documents else { return }
                
                var players: [Character] = []
                for doc in docs {
                    if let char = try? doc.data(as: Character.self) {
                        players.append(char)
                    }
                }
                
                DispatchQueue.main.async {
                    self.leaderboards["global"] = players
                    self.leaderboards["friends"] = players.filter { self.friends.contains($0.username) }
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
}
