import Foundation
import Combine

class FirebaseService: ObservableObject {
    @Published var currentCharacter: Character?
    @Published var activeBattle: Battle?
    @Published var userClan: Clan?
    @Published var leaderboards: [String: [Character]] = [:]
    @Published var friends: [String] = ["AquaHealer", "FireMage", "WindArcher", "KnightDave"]
    
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
        
        loadMockLeaderboards()
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
        // In a real app: Firestore.firestore().collection("users").document(character.id).setData(from: character)
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
        
        // If in clan, contribute reps
        if var clan = userClan, let index = clan.members.firstIndex(where: { $0.id == char.id }) {
            clan.members[index].repsContributed += 10 // Mock rep increment
            clan.totalReps += 10
            userClan = clan
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
        if reps > 0, var clan = userClan, let index = clan.members.firstIndex(where: { $0.id == char.id }) {
            clan.members[index].repsContributed += reps
            clan.totalReps += reps
            userClan = clan
        }
        
        return (xpReward, goldReward)
    }
    
    // MARK: - Matchmaking & Real-Time PvP
    func startMatchmaking(
        for characterClass: CharacterClass,
        type: BattleType,
        invitedFriends: [String],
        completion: @escaping (Bool) -> Void
    ) {
        guard let char = currentCharacter else { return }
        
        // Mock matchmaking delay of 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            var localTeam: [BattlePlayer] = []
            var opponentTeam: [BattlePlayer] = []
            
            // Add local player using selected class and active avatar
            let localPlayer = BattlePlayer(
                id: char.id,
                name: char.username,
                characterClass: characterClass,
                health: 100 + char.level * 10,
                maxHealth: 100 + char.level * 10,
                avatarName: char.avatarName
            )
            localTeam.append(localPlayer)
            
            if type == .duel1v1 {
                let opponentClass = characterClass
                let opponent = BattlePlayer(
                    id: "opponent_id_999",
                    name: "ShadowFiend",
                    characterClass: opponentClass,
                    health: 120,
                    maxHealth: 120,
                    avatarName: "avatar_\(opponentClass.rawValue.lowercased())"
                )
                opponentTeam.append(opponent)
            } else {
                // 3v3 team battle
                // Add invited friends (or mock friends if not fully selected)
                let friendsToUse = invitedFriends.isEmpty ? ["AquaHealer", "FireMage"] : invitedFriends
                for (idx, friendName) in friendsToUse.enumerated() {
                    let friendClass: CharacterClass = idx == 0 ? .healer : .mage
                    let friend = BattlePlayer(
                        id: "friend_id_\(idx)",
                        name: friendName,
                        characterClass: friendClass,
                        health: 110,
                        maxHealth: 110,
                        avatarName: "avatar_\(friendClass.rawValue.lowercased())"
                    )
                    localTeam.append(friend)
                }
                
                // Add 3 opponents mirroring localTeam's classes to ensure identical exercises
                let opponentNames = ["DarkLord", "ChaosWeaver", "DoomArcher"]
                for idx in 0..<localTeam.count {
                    let opposingClass = localTeam[idx].characterClass
                    let opponent = BattlePlayer(
                        id: "opponent_id_\(idx)",
                        name: opponentNames[idx % opponentNames.count],
                        characterClass: opposingClass,
                        health: 120,
                        maxHealth: 120,
                        avatarName: "avatar_\(opposingClass.rawValue.lowercased())"
                    )
                    opponentTeam.append(opponent)
                }
            }
            
            let mockBattle = Battle(
                id: "battle_room_\(UUID().uuidString.prefix(6))",
                type: type,
                status: .active,
                localTeam: localTeam,
                opponentTeam: opponentTeam
            )
            
            self.activeBattle = mockBattle
            self.startBattleSimulation()
            completion(true)
        }
    }
    
    // MARK: - Friend PvP Challenge
    func startFriendDuel(
        playerClass: CharacterClass,
        friendName: String,
        friendClass: CharacterClass,
        completion: @escaping (Bool) -> Void
    ) {
        guard let char = currentCharacter else { return }
        
        // Mock connection delay to feel authentic
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let localPlayer = BattlePlayer(
                id: char.id,
                name: char.username,
                characterClass: playerClass,
                health: 100 + char.level * 10,
                maxHealth: 100 + char.level * 10,
                avatarName: char.avatarName
            )
            
            let opponentPlayer = BattlePlayer(
                id: "friend_\(friendName)",
                name: friendName,
                characterClass: friendClass,
                health: 120,
                maxHealth: 120,
                avatarName: "avatar_\(friendClass.rawValue.lowercased())"
            )
            
            let duelBattle = Battle(
                id: "duel_\(UUID().uuidString.prefix(6))",
                type: .duel1v1,
                status: .active,
                localTeam: [localPlayer],
                opponentTeam: [opponentPlayer]
            )
            
            self.activeBattle = duelBattle
            self.startBattleSimulation()
            completion(true)
        }
    }
    
    // Simulates dynamic combat actions from the opponents and teammate actions, plus countdown timer
    private func startBattleSimulation() {
        battleTimer?.invalidate()
        battleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, var battle = self.activeBattle else { return }
            
            if battle.secondsRemaining > 0 && battle.status == .active {
                battle.secondsRemaining -= 1
                
                let isTeamBattle = battle.type == .team3v3
                
                // 1. Random opponent action every 4 seconds
                if battle.secondsRemaining % 4 == 0 {
                    let aliveOpponents = battle.opponentTeam.filter { !$0.isDead }
                    let aliveAllies = battle.localTeam.filter { !$0.isDead }
                    
                    if let attacker = aliveOpponents.randomElement(),
                       let target = aliveAllies.randomElement(),
                       let targetIdx = battle.localTeam.firstIndex(where: { $0.id == target.id }) {
                        
                        var targetPlayer = battle.localTeam[targetIdx]
                        var damage = Int.random(in: 8...16)
                        var armorText = ""
                        
                        // Apply equipped armor defense to reduce damage if it's the local hero taking damage
                        if targetPlayer.id == self.currentCharacter?.id {
                            if let armorId = self.currentCharacter?.equippedArmorId,
                               let armor = EquipmentItem.findArmor(by: armorId) {
                                let oldDamage = damage
                                damage = max(1, damage - armor.defense)
                                let reducedAmt = oldDamage - damage
                                if reducedAmt > 0 {
                                    armorText = " (\(armor.name) blocked \(reducedAmt) DMG)"
                                }
                            }
                        }
                        
                        var detailMsg = ""
                        var actionType: CombatActionType = .attack
                        
                        // Class-specific custom moves for the opponent
                        switch attacker.characterClass {
                        case .archer:
                            detailMsg = "fires Swift Shot at \(targetPlayer.name) dealing \(damage) DMG!\(armorText)"
                        case .mage:
                            detailMsg = "casts Fireball on \(targetPlayer.name) dealing \(damage) DMG!\(armorText)"
                        case .swordsman:
                            detailMsg = "performs Blade Slam on \(targetPlayer.name) dealing \(damage) DMG!\(armorText)"
                        case .healer:
                            // Healer can choose to self-heal or use Holy Shock on the target
                            if Int.random(in: 0...1) == 0 {
                                detailMsg = "casts Holy Shock on \(targetPlayer.name) dealing \(damage) DMG!\(armorText)"
                            } else {
                                actionType = .heal
                                let healAmt = Int.random(in: 12...20)
                                let attackerIdx = battle.opponentTeam.firstIndex(where: { $0.id == attacker.id }) ?? 0
                                var oppPlayer = battle.opponentTeam[attackerIdx]
                                oppPlayer.health = min(oppPlayer.maxHealth, oppPlayer.health + healAmt)
                                battle.opponentTeam[attackerIdx] = oppPlayer
                                damage = healAmt
                                detailMsg = "casts Rejuvenate on themselves to restore \(healAmt) HP!"
                            }
                        }
                        
                        if actionType == .attack {
                            // Handle shield first
                            if targetPlayer.shield > 0 {
                                let shieldDamage = min(targetPlayer.shield, damage)
                                targetPlayer.shield -= shieldDamage
                                let remainingDamage = damage - shieldDamage
                                targetPlayer.health = max(0, targetPlayer.health - remainingDamage)
                            } else {
                                targetPlayer.health = max(0, targetPlayer.health - damage)
                            }
                            battle.localTeam[targetIdx] = targetPlayer
                        }
                        
                        let event = CombatEvent(
                            actorName: attacker.name,
                            targetName: actionType == .heal ? attacker.name : targetPlayer.name,
                            actionType: actionType,
                            value: damage,
                            detailText: detailMsg
                        )
                        battle.combatLog.append(event)
                    }
                }
                
                // 2. Random teammate action every 5 seconds (only in 3v3)
                if isTeamBattle && battle.secondsRemaining % 5 == 0 {
                    let aliveTeammates = battle.localTeam.enumerated().filter { $0.offset != 0 && !$0.element.isDead }
                    let aliveOpponents = battle.opponentTeam.filter { !$0.isDead }
                    
                    if let teammatePair = aliveTeammates.randomElement(),
                       let targetOpponent = aliveOpponents.randomElement(),
                       let opponentIdx = battle.opponentTeam.firstIndex(where: { $0.id == targetOpponent.id }) {
                        
                        let teammateIdx = teammatePair.offset
                        var teammate = battle.localTeam[teammateIdx]
                        teammate.reps += 1
                        
                        let actionVal = Int.random(in: 10...20)
                        var detail = ""
                        
                        if teammate.characterClass == .healer {
                            // Healer heals or shields a random alive teammate
                            var targetAllyIdx = Int.random(in: 0..<battle.localTeam.count)
                            while battle.localTeam[targetAllyIdx].isDead {
                                targetAllyIdx = Int.random(in: 0..<battle.localTeam.count)
                            }
                            var targetAlly = battle.localTeam[targetAllyIdx]
                            
                            if Int.random(in: 0...1) == 0 {
                                targetAlly.health = min(targetAlly.maxHealth, targetAlly.health + actionVal)
                                detail = "casts Rejuvenate on \(targetAlly.name) restoring \(actionVal) HP!"
                            } else {
                                targetAlly.shield += actionVal
                                detail = "casts Vitality Shield on \(targetAlly.name) (+\(actionVal) Shield)!"
                            }
                            battle.localTeam[targetAllyIdx] = targetAlly
                        } else {
                            // Mage or Archer attacks opponent
                            var opp = battle.opponentTeam[opponentIdx]
                            opp.health = max(0, opp.health - actionVal)
                            battle.opponentTeam[opponentIdx] = opp
                            
                            let skillName = teammate.characterClass == .mage ? "Fireball" : "Swift Shot"
                            detail = "performs exercise and casts \(skillName) on \(opp.name) dealing \(actionVal) damage!"
                        }
                        
                        battle.localTeam[teammateIdx] = teammate
                        
                        let event = CombatEvent(
                            actorName: teammate.name,
                            targetName: teammate.characterClass == .healer ? "Team" : targetOpponent.name,
                            actionType: teammate.characterClass == .healer ? .heal : .attack,
                            value: actionVal,
                            detailText: detail
                        )
                        battle.combatLog.append(event)
                    }
                }
                
                // 3. Check win / loss conditions
                let localTeamDead = battle.localTeam.allSatisfy { $0.isDead }
                let opponentTeamDead = battle.opponentTeam.allSatisfy { $0.isDead }
                
                if localTeamDead {
                    battle.status = .completed
                    battle.winnerId = "opponents"
                    self.battleTimer?.invalidate()
                } else if opponentTeamDead {
                    battle.status = .completed
                    battle.winnerId = self.currentCharacter?.id
                    self.battleTimer?.invalidate()
                    self.awardBattleRewards(xp: 250, gold: 60, isPvP: true)
                }
                
                if battle.secondsRemaining <= 0 {
                    battle.status = .completed
                    // Compare aggregate team reps
                    let localReps = battle.localTeam.reduce(0) { $0 + $1.reps }
                    let opponentReps = battle.opponentTeam.reduce(0) { $0 + $1.reps }
                    
                    if localReps >= opponentReps {
                        battle.winnerId = self.currentCharacter?.id
                        self.awardBattleRewards(xp: 180, gold: 45, isPvP: true)
                    } else {
                        battle.winnerId = "opponents"
                        self.awardBattleRewards(xp: 60, gold: 15, isPvP: false)
                    }
                    self.battleTimer?.invalidate()
                }
                
                self.activeBattle = battle
            }
        }
    }
    
    func registerLocalRepetition() {
        guard var battle = activeBattle, var local = battle.localTeam.first else { return }
        
        local.reps += 1
        
        // Find alive opponents
        let aliveOpponents = battle.opponentTeam.filter { !$0.isDead }
        if let targetOpponent = aliveOpponents.randomElement(),
           let oppIdx = battle.opponentTeam.firstIndex(where: { $0.id == targetOpponent.id }) {
            
            let damage = Int(Double(currentCharacter?.combatPower ?? 100) * 0.08)
            var opp = battle.opponentTeam[oppIdx]
            opp.health = max(0, opp.health - damage)
            battle.opponentTeam[oppIdx] = opp
            
            let event = CombatEvent(
                actorName: local.name,
                targetName: opp.name,
                actionType: .attack,
                value: damage,
                detailText: "performs \(local.characterClass.primaryExercise) to deal \(damage) damage to \(opp.name)!"
            )
            battle.combatLog.append(event)
        }
        
        battle.localTeam[0] = local
        
        let allOpponentsDead = battle.opponentTeam.allSatisfy { $0.isDead }
        if allOpponentsDead {
            battle.status = .completed
            battle.winnerId = local.id
            battleTimer?.invalidate()
            awardBattleRewards(xp: 250, gold: 60, isPvP: true)
        }
        
        self.activeBattle = battle
    }
    
    func leaveMatch() {
        battleTimer?.invalidate()
        activeBattle = nil
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
            opponentClanId: "opponent_clan_555",
            opponentClanName: "IronBeasts",
            myClanScore: 0,
            opponentClanScore: 15,
            endsAt: endsAt
        )
        self.userClan = clan
    }
    
    func contributeWarScore(points: Int) {
        guard var clan = userClan, var war = clan.activeWar else { return }
        war.myClanScore += points
        clan.activeWar = war
        self.userClan = clan
    }
    
    // MARK: - Leaderboard Fetch
    private func loadMockLeaderboards() {
        let classes: [CharacterClass] = [.archer, .mage, .swordsman, .healer]
        let names = ["Valkyrie", "Aegis", "Gollum", "Wizard99", "Merlin", "Legolas", "Conan", "PriestOfLight"]
        
        var players: [Character] = []
        for i in 0..<20 {
            let cls = classes.randomElement() ?? .swordsman
            let level = Int.random(in: 5...25)
            let totalReps = Int.random(in: 50...1200)
            
            var mockStats = CharacterStats()
            switch cls {
            case .archer: mockStats.totalSquats = totalReps
            case .mage: mockStats.totalPushups = totalReps
            case .swordsman: mockStats.totalPullups = totalReps
            case .healer: mockStats.totalDips = totalReps
            }
            
            let pvpWins = Int.random(in: 5...60)
            let pvpTrophies = 1000 + pvpWins * 20 + Int.random(in: -50...50)
            
            var char = Character(
                id: "mock_user_\(i)",
                username: names.randomElement() ?? "Hero\(i)",
                selectedClass: cls,
                level: level,
                xp: 0,
                gold: Int.random(in: 100...2000),
                stats: mockStats
            )
            char.pvpWins = pvpWins
            char.pvpTrophies = pvpTrophies
            players.append(char)
        }
        
        // Sort by level/reps to mock global standings
        self.leaderboards["global"] = players.sorted(by: { $0.level > $1.level })
        self.leaderboards["pvp_1v1"] = players.sorted(by: { $0.pvpTrophies > $1.pvpTrophies })
        
        for cls in CharacterClass.allCases {
            self.leaderboards[cls.rawValue] = players
                .filter { $0.selectedClass == cls }
                .sorted(by: { $0.stats.totalReps > $1.stats.totalReps })
        }
    }
}
