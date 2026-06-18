import Foundation
import Combine

class FirebaseService: ObservableObject {
    @Published var currentCharacter: Character?
    @Published var activeBattle: Battle?
    @Published var userClan: Clan?
    @Published var leaderboards: [String: [Character]] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    private var battleTimer: Timer?
    
    static let shared = FirebaseService()
    
    init() {
        // Setup initial mock character for testing
        self.currentCharacter = Character(
            id: "local_mock_user",
            username: "FitnessHero",
            selectedClass: .archer,
            level: 1,
            xp: 0,
            gold: 150,
            energy: 100,
            maxEnergy: 100,
            basePower: 100
        )
        
        loadMockLeaderboards()
    }
    
    // MARK: - Character Sync
    func syncCharacter(_ character: Character) {
        self.currentCharacter = character
        // In a real app: Firestore.firestore().collection("users").document(character.id).setData(from: character)
    }
    
    func awardBattleRewards(xp: Int, gold: Int) {
        guard var char = currentCharacter else { return }
        let leveledUp = char.addXP(xp)
        char.gold += gold
        self.currentCharacter = char
        syncCharacter(char)
        
        // If in clan, contribute reps
        if var clan = userClan, let index = clan.members.firstIndex(where: { $0.id == char.id }) {
            clan.members[index].repsContributed += 10 // Mock rep increment
            clan.totalReps += 10
            userClan = clan
        }
    }
    
    // MARK: - Matchmaking & Real-Time PvP
    func startMatchmaking(for characterClass: CharacterClass, completion: @escaping (Bool) -> Void) {
        guard let char = currentCharacter else { return }
        
        // Mock matchmaking delay of 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let opponentClass = CharacterClass.allCases.randomElement() ?? .mage
            let opponent = BattlePlayer(
                id: "opponent_id_999",
                name: "ShadowFiend",
                characterClass: opponentClass,
                health: 120,
                maxHealth: 120
            )
            
            let localPlayer = BattlePlayer(
                id: char.id,
                name: char.username,
                characterClass: char.selectedClass,
                health: 100 + char.level * 10,
                maxHealth: 100 + char.level * 10
            )
            
            let mockBattle = Battle(
                id: "battle_room_\(UUID().uuidString.prefix(6))",
                type: .duel1v1,
                status: .active,
                localTeam: [localPlayer],
                opponentTeam: [opponent]
            )
            
            self.activeBattle = mockBattle
            self.startBattleSimulation()
            completion(true)
        }
    }
    
    // Simulates dynamic combat actions from the opponent and countdown timer
    private func startBattleSimulation() {
        battleTimer?.invalidate()
        battleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, var battle = self.activeBattle else { return }
            
            if battle.secondsRemaining > 0 && battle.status == .active {
                battle.secondsRemaining -= 1
                
                // Randomly trigger opponent action every 3-5 seconds
                if battle.secondsRemaining % 4 == 0 {
                    let damageValue = Int.random(in: 8...15)
                    if var local = battle.localTeam.first {
                        local.health = max(0, local.health - damageValue)
                        battle.localTeam[0] = local
                        
                        let event = CombatEvent(
                            actorName: battle.opponentTeam.first?.name ?? "Opponent",
                            targetName: local.name,
                            actionType: .attack,
                            value: damageValue,
                            detailText: "uses skill and deals \(damageValue) damage!"
                        )
                        battle.combatLog.append(event)
                    }
                }
                
                // Check win/loss
                if let local = battle.localTeam.first, local.health <= 0 {
                    battle.status = .completed
                    battle.winnerId = battle.opponentTeam.first?.id
                    self.battleTimer?.invalidate()
                } else if let opp = battle.opponentTeam.first, opp.health <= 0 {
                    battle.status = .completed
                    battle.winnerId = battle.localTeam.first?.id
                    self.battleTimer?.invalidate()
                    self.awardBattleRewards(xp: 200, gold: 50)
                }
                
                if battle.secondsRemaining <= 0 {
                    battle.status = .completed
                    // Winner has most reps
                    let p1Reps = battle.localTeam.first?.reps ?? 0
                    let p2Reps = battle.opponentTeam.first?.reps ?? 0
                    if p1Reps >= p2Reps {
                        battle.winnerId = battle.localTeam.first?.id
                        self.awardBattleRewards(xp: 150, gold: 40)
                    } else {
                        battle.winnerId = battle.opponentTeam.first?.id
                        self.awardBattleRewards(xp: 50, gold: 10)
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
        // Apply damage to opponent
        if var opp = battle.opponentTeam.first {
            let damage = Int(Double(currentCharacter?.combatPower ?? 100) * 0.08)
            opp.health = max(0, opp.health - damage)
            battle.opponentTeam[0] = opp
            
            let event = CombatEvent(
                actorName: local.name,
                targetName: opp.name,
                actionType: .attack,
                value: damage,
                detailText: "performs \(local.characterClass.primaryExercise) to deal \(damage) damage!"
            )
            battle.combatLog.append(event)
        }
        
        battle.localTeam[0] = local
        
        if let opp = battle.opponentTeam.first, opp.health <= 0 {
            battle.status = .completed
            battle.winnerId = local.id
            battleTimer?.invalidate()
            awardBattleRewards(xp: 200, gold: 50)
        }
        
        self.activeBattle = battle
    }
    
    func leaveMatch() {
        battleTimer?.invalidate()
        activeBattle = nil
    }
    
    // MARK: - Clan Operations
    func createClan(name: String) {
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
            leaderId: char.id,
            members: [member],
            trophies: 1000
        )
        
        self.userClan = newClan
        
        var updatedChar = char
        updatedChar.clanId = newClan.id
        syncCharacter(updatedChar)
    }
    
    func joinClan(_ clan: Clan) {
        guard let char = currentCharacter else { return }
        var updatedClan = clan
        
        let member = ClanMember(
            id: char.id,
            username: char.username,
            level: char.level,
            characterClass: char.selectedClass,
            role: .member
        )
        
        updatedClan.members.append(member)
        self.userClan = updatedClan
        
        var updatedChar = char
        updatedChar.clanId = updatedClan.id
        syncCharacter(updatedChar)
    }
    
    func startClanWar() {
        guard var clan = userClan else { return }
        let endsAt = Date().addingTimeInterval(86400) // 24 hours from now
        clan.activeWar = ClanWar(
            opponentClanId: "opponent_clan_555",
            opponentClanName: "IronBeasts",
            myClanScore: 0,
            opponentClanScore: 15, // Headstart for opponent
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
            let basePower = 100 + Int.random(in: 20...150)
            let totalReps = Int.random(in: 50...1200)
            
            var mockStats = CharacterStats()
            switch cls {
            case .archer: mockStats.totalSquats = totalReps
            case .mage: mockStats.totalPushups = totalReps
            case .swordsman: mockStats.totalPullups = totalReps
            case .healer: mockStats.totalDips = totalReps
            }
            
            let char = Character(
                id: "mock_user_\(i)",
                username: names.randomElement() ?? "Hero\(i)",
                selectedClass: cls,
                level: level,
                xp: 0,
                gold: Int.random(in: 100...2000),
                stats: mockStats
            )
            players.append(char)
        }
        
        // Sort by level/reps to mock global standings
        self.leaderboards["global"] = players.sorted(by: { $0.level > $1.level })
        
        for cls in CharacterClass.allCases {
            self.leaderboards[cls.rawValue] = players
                .filter { $0.selectedClass == cls }
                .sorted(by: { $0.stats.totalReps > $1.stats.totalReps })
        }
    }
}
