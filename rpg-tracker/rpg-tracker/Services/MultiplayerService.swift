import FirebaseFunctions

import Foundation
import Combine
import FirebaseFirestore

enum MatchmakingStatus: String, Codable {
    case searchingTeammates = "searchingTeammates"
    case searchingOpponent = "searchingOpponent"
    case matched = "matched"
    case waitingForFriend = "waitingForFriend"
}

struct MatchmakingTicket: Codable, Identifiable {
    @DocumentID var id: String?
    var uid: String
    var playerClass: CharacterClass
    var playerLevel: Int
    var playerAvatar: String
    var playerName: String
    var status: MatchmakingStatus
    var battleId: String?
    var teamType: BattleType?
    var team: [BattlePlayer]?
    var targetUid: String?
    var createdAt: Date = Date()
}

@MainActor
class MultiplayerService: ObservableObject {
    static let shared = MultiplayerService()
    
    @Published var activeBattle: Battle?
    @Published var isSearching: Bool = false
    @Published var incomingDuel: MatchmakingTicket?
    
    private let db = Firestore.firestore()
    private var matchmakingListener: ListenerRegistration?
    private var battleListener: ListenerRegistration?
    private var incomingDuelListener: ListenerRegistration?
    
    private var teammateFallbackTimer: Timer?
    private var opponentFallbackTimer: Timer?
    private var currentTicketId: String?
    private var currentSearchType: BattleType = .duel1v1
    
    private init() {}
    
    // MARK: - Friend Duels
    
    func listenForIncomingDuels() {
        guard let myUid = FirebaseService.shared.currentCharacter?.id else { return }
        
        incomingDuelListener?.remove()
        incomingDuelListener = db.collection("matchmaking")
            .whereField("targetUid", isEqualTo: myUid)
            .whereField("status", isEqualTo: MatchmakingStatus.waitingForFriend.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let doc = snapshot?.documents.first,
                   let ticket = try? doc.data(as: MatchmakingTicket.self) {
                    // Show only if not already fighting
                    if self.activeBattle == nil && !self.isSearching {
                        self.incomingDuel = ticket
                    }
                } else {
                    self.incomingDuel = nil
                }
            }
    }
    
    func challengeFriend(friendUid: String) {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        
        // PVP costs 10 energy
        guard FirebaseService.shared.consumeEnergy(amount: 10) else {
            print("Not enough energy for PVP!")
            return
        }
        
        self.currentSearchType = .duel1v1
        isSearching = true
        
        let localTeam = [BattlePlayer(id: char.id, name: char.username, characterClass: char.selectedClass, health: 100 + char.level * 10, maxHealth: 100 + char.level * 10, avatarName: char.avatarName)]
        
        let ticket = MatchmakingTicket(
            uid: char.id, playerClass: char.selectedClass, playerLevel: char.level,
            playerAvatar: char.avatarName ?? "avatar_knight", playerName: char.username,
            status: .waitingForFriend, teamType: .duel1v1, team: localTeam, targetUid: friendUid
        )
        
        do {
            let docRef = try db.collection("matchmaking").addDocument(from: ticket)
            self.currentTicketId = docRef.documentID
            
            // Send in-app notification to target
            NotificationManager.sendInAppNotification(
                to: friendUid,
                title: "Duel Challenge!",
                message: "\(char.username) has challenged you to a duel!",
                type: .duel,
                actionData: ["type": "duel", "ticketId": docRef.documentID]
            )
            
            // Listen for friend to accept (status changes to matched)
            self.matchmakingListener = docRef.addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot, snapshot.exists else { return }
                guard let updatedTicket = try? snapshot.data(as: MatchmakingTicket.self) else { return }
                
                if updatedTicket.status == .matched, let battleId = updatedTicket.battleId {
                    self.matchmakingListener?.remove()
                    self.currentTicketId = nil
                    Task { try? await docRef.delete() }
                    self.listenToBattle(battleId: battleId)
                }
            }
            
            // Timeout if friend doesn't accept in 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if self.currentTicketId == docRef.documentID {
                    self.leaveMatch()
                }
            }
        } catch {
            print("Failed to challenge friend: \(error)")
        }
    }
    
    func acceptDuel(_ ticket: MatchmakingTicket) {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        guard let ticketId = ticket.id else { return }
        
        self.incomingDuel = nil
        self.isSearching = true
        
        let myTeam = [BattlePlayer(id: char.id, name: char.username, characterClass: char.selectedClass, health: 100 + char.level * 10, maxHealth: 100 + char.level * 10, avatarName: char.avatarName)]
        
        Task {
            let success = try? await matchWithOpponent(opponentTicketId: ticketId, opponent: ticket, myTeam: myTeam)
            if success == true {
                // Battle is created in matchWithOpponent, and we can just listen to the new ticket or battle.
                // Actually, matchWithOpponent creates the battle and returns true. Let's start listening to the battle directly.
                // We need the newly generated battleId.
                // Wait, matchWithOpponent updates the ticket, the host will create battle?
                // Let's modify matchWithOpponent to return battleId if needed, or we just listen to ticket as guest.
                self.listenToTicketAsGuest(ticketId: ticketId)
            } else {
                self.isSearching = false
            }
        }
    }
    
    func declineDuel(_ ticket: MatchmakingTicket) {
        self.incomingDuel = nil
        if let id = ticket.id {
            // Just delete the ticket so the host's search gets cancelled/invalidated
            db.collection("matchmaking").document(id).delete()
        }
    }
    
    // MARK: - Core Matchmaking
    
    func startMatchmaking(for characterClass: CharacterClass, type: BattleType = .duel1v1, invitedFriends: [String] = []) {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        
        // PVP costs 10 energy
        guard FirebaseService.shared.consumeEnergy(amount: 10) else {
            // Wait, UI should probably show an alert if not enough energy, but for now we just return
            print("Not enough energy for PVP!")
            return
        }
        
        self.currentSearchType = type
        isSearching = true
        
        var localTeam: [BattlePlayer] = []
        localTeam.append(BattlePlayer(id: char.id, name: char.username, characterClass: characterClass, health: 100 + char.level * 10, maxHealth: 100 + char.level * 10, avatarName: char.avatarName))
        
        if type == .team3v3 {
            for friend in invitedFriends {
                if localTeam.count < 3 {
                    localTeam.append(BattlePlayer(id: "friend_\(friend)", name: friend, characterClass: .swordsman, health: 110, maxHealth: 110, avatarName: "avatar_swordsman"))
                }
            }
        }
        
        let initialStatus: MatchmakingStatus = (type == .team3v3 && localTeam.count < 3) ? .searchingTeammates : .searchingOpponent
        
        Task {
            if type == .bossRaid {
                guard let boss = FirebaseService.shared.activeWorldBoss else {
                    isSearching = false
                    return
                }
                
                let template = Boss.templates.first { $0.id == boss.bossTemplateId } ?? Boss.templates.last!
                let bossPlayer = BattlePlayer(
                    id: boss.id,
                    name: template.name,
                    characterClass: .swordsman, // default logic for boss avatar is handled in View
                    health: boss.currentHealth,
                    maxHealth: boss.maxHealth,
                    avatarName: template.avatarName
                )
                
                let battle = Battle(
                    id: "raid_\(UUID().uuidString)",
                    type: .bossRaid,
                    status: .active,
                    localTeam: localTeam,
                    opponentTeam: [bossPlayer],
                    secondsRemaining: 60 // 60 seconds to deal as much damage as possible
                )
                
                await MainActor.run {
                    self.activeBattle = battle
                    self.isSearching = false
                }
                return
            }
            

            
            if initialStatus == .searchingTeammates {
                let snapshot = try? await db.collection("matchmaking")
                    .whereField("status", isEqualTo: MatchmakingStatus.searchingTeammates.rawValue)
                    .whereField("teamType", isEqualTo: type.rawValue)
                    .limit(to: 5)
                    .getDocuments()
                
                let potentialMatches = snapshot?.documents.compactMap { try? $0.data(as: MatchmakingTicket.self) }
                    .filter { $0.uid != char.id && ($0.team?.count ?? 1) + localTeam.count <= 3 } ?? []
                
                if let opponentTicket = potentialMatches.first, let opponentTicketId = opponentTicket.id {
                    let success = try? await joinTeam(ticketId: opponentTicketId, guests: localTeam)
                    if success == true {
                        self.currentTicketId = opponentTicketId
                        self.listenToTicketAsGuest(ticketId: opponentTicketId)
                        return
                    }
                }
            } else if initialStatus == .searchingOpponent {
                let snapshot = try? await db.collection("matchmaking")
                    .whereField("status", isEqualTo: MatchmakingStatus.searchingOpponent.rawValue)
                    .whereField("teamType", isEqualTo: type.rawValue)
                    .limit(to: 5)
                    .getDocuments()
                
                let potentialMatches = snapshot?.documents.compactMap { try? $0.data(as: MatchmakingTicket.self) }
                    .filter { $0.uid != char.id } ?? []
                
                if let opponentTicket = potentialMatches.first, let opponentTicketId = opponentTicket.id {
                    let success = try? await matchWithOpponent(opponentTicketId: opponentTicketId, opponent: opponentTicket, myTeam: localTeam)
                    if success == true { return }
                }
            }
            
            createOwnTicket(myChar: char, myClass: characterClass, type: type, myTeam: localTeam, initialStatus: initialStatus)
        }
    }
    
    private func joinTeam(ticketId: String, guests: [BattlePlayer]) async throws -> Bool {
        let functions = Functions.functions()
        do {
            let guestsData = guests.compactMap { try? Firestore.Encoder().encode($0) }
            let result = try await functions.httpsCallable("joinTeam").call([
                "ticketId": ticketId,
                "guests": guestsData
            ])
            if let data = result.data as? [String: Any], let success = data["success"] as? Bool {
                return success
            }
        } catch {
            print("Join team failed: \(error)")
        }
        return false
    }

    private func matchWithOpponent(opponentTicketId: String, opponent: MatchmakingTicket, myTeam: [BattlePlayer]) async throws -> Bool {
        let functions = Functions.functions()
        do {
            let result = try await functions.httpsCallable("matchWithOpponent").call([
                "opponentTicketId": opponentTicketId
            ])
            
            if let data = result.data as? [String: Any], 
               let success = data["success"] as? Bool, success,
               let newBattleId = data["battleId"] as? String {
                
                // Decode the actual opponent data returned by server
                var finalOpponent = opponent
                if let oppData = data["opponentData"] as? [String: Any],
                   let decodedOpponent = try? Firestore.Decoder().decode(MatchmakingTicket.self, from: oppData) {
                    finalOpponent = decodedOpponent
                }
                
                await createBattleDocument(battleId: newBattleId, myTeam: myTeam, opponent: finalOpponent)
                return true
            }
        } catch {
            print("Match with opponent failed: \(error)")
        }
        return false
    }

    private func createOwnTicket(myChar: Character, myClass: CharacterClass, type: BattleType, myTeam: [BattlePlayer], initialStatus: MatchmakingStatus) {
        let ticket = MatchmakingTicket(
            uid: myChar.id, playerClass: myClass, playerLevel: myChar.level,
            playerAvatar: myChar.avatarName ?? "avatar_swordsman", playerName: myChar.username,
            status: initialStatus, teamType: type, team: myTeam
        )
        
        do {
            let docRef = try db.collection("matchmaking").addDocument(from: ticket)
            self.currentTicketId = docRef.documentID
            self.listenToTicketAsHost(docRef: docRef, type: type)
        } catch {
            print("Failed to create ticket: \(error)")
        }
    }
    
    private func listenToTicketAsHost(docRef: DocumentReference, type: BattleType) {
        self.matchmakingListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let snapshot = snapshot, snapshot.exists else { return }
            guard let ticket = try? snapshot.data(as: MatchmakingTicket.self) else { return }
            
            if ticket.status == .searchingTeammates {
                if self.teammateFallbackTimer == nil {
                    self.teammateFallbackTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
                        Task { @MainActor in await self.fillTeammatesWithBots(ticketId: docRef.documentID) }
                    }
                }
            } else if ticket.status == .searchingOpponent {
                self.teammateFallbackTimer?.invalidate()
                if self.opponentFallbackTimer == nil {
                    self.opponentFallbackTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
                        Task { @MainActor in await self.triggerOpponentBotFallback(ticket: ticket, type: type) }
                    }
                }
            } else if ticket.status == .matched, let battleId = ticket.battleId {
                self.matchmakingListener?.remove()
                self.teammateFallbackTimer?.invalidate()
                self.opponentFallbackTimer?.invalidate()
                self.currentTicketId = nil
                Task { try? await docRef.delete() }
                self.listenToBattle(battleId: battleId)
            }
        }
    }

    private func listenToTicketAsGuest(ticketId: String) {
        let docRef = db.collection("matchmaking").document(ticketId)
        self.matchmakingListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let snapshot = snapshot, snapshot.exists else { return }
            guard let ticket = try? snapshot.data(as: MatchmakingTicket.self) else { return }
            
            if ticket.status == .matched, let battleId = ticket.battleId {
                self.matchmakingListener?.remove()
                self.currentTicketId = nil
                self.listenToBattle(battleId: battleId)
            }
        }
    }

    private func fillTeammatesWithBots(ticketId: String) async {
        let functions = Functions.functions()
        do {
            let result = try await functions.httpsCallable("fillTeammatesWithBots").call([
                "ticketId": ticketId
            ])
            if let data = result.data as? [String: Any], let success = data["success"] as? Bool, success {
                print("Successfully filled teammates with bots via server")
            }
        } catch {
            print("Failed to fill teammates with bots on server: \(error). Falling back to local teammates fill.")
            // Local teammates fill
            do {
                let ticketDoc = try await db.collection("matchmaking").document(ticketId).getDocument()
                guard var ticket = try? ticketDoc.data(as: MatchmakingTicket.self) else { return }
                
                var team = ticket.team ?? []
                while team.count < 3 {
                    let botClass = CharacterClass.allCases.randomElement() ?? .healer
                    let botPlayer = BattlePlayer(
                        id: "bot_\(UUID().uuidString)",
                        name: "Ally Bot",
                        characterClass: botClass,
                        health: 100 + (ticket.playerLevel * 10),
                        maxHealth: 100 + (ticket.playerLevel * 10),
                        avatarName: "avatar_archer"
                    )
                    team.append(botPlayer)
                }
                
                try await db.collection("matchmaking").document(ticketId).updateData([
                    "team": try Firestore.Encoder().encode(team),
                    "status": MatchmakingStatus.searchingOpponent.rawValue
                ])
                print("Successfully filled teammates locally.")
            } catch {
                print("Failed local teammates fill: \(error)")
            }
        }
    }

    private func triggerOpponentBotFallback(ticket: MatchmakingTicket, type: BattleType) async {
        guard let ticketId = ticket.id else { return }
        
        let functions = Functions.functions()
        do {
            let result = try await functions.httpsCallable("triggerOpponentBotFallback").call([
                "ticketId": ticketId,
                "type": type.rawValue
            ])
            if let data = result.data as? [String: Any], let success = data["success"] as? Bool, success {
                print("Successfully triggered opponent bot fallback via server")
            }
        } catch {
            print("Failed to trigger opponent bot fallback on server: \(error). Falling back to local bot creation.")
            
            // Local bot creation
            let botClass = CharacterClass.allCases.randomElement() ?? .swordsman
            let botPlayer = BattlePlayer(
                id: "bot_\(UUID().uuidString)",
                name: "AI Challenger",
                characterClass: botClass,
                health: 100 + (ticket.playerLevel * 10),
                maxHealth: 100 + (ticket.playerLevel * 10),
                avatarName: "avatar_knight"
            )
            
            let battleId = "battle_\(UUID().uuidString)"
            var myTeam = ticket.team ?? []
            if myTeam.isEmpty {
                myTeam.append(BattlePlayer(
                    id: ticket.uid,
                    name: ticket.playerName,
                    characterClass: ticket.playerClass,
                    health: 100 + (ticket.playerLevel * 10),
                    maxHealth: 100 + (ticket.playerLevel * 10),
                    avatarName: ticket.playerAvatar
                ))
            }
            
            let battle = Battle(
                id: battleId,
                type: type,
                status: .active,
                localTeam: myTeam,
                opponentTeam: [botPlayer],
                secondsRemaining: 60
            )
            
            do {
                try db.collection("battles").document(battleId).setData(from: battle)
                try await db.collection("matchmaking").document(ticketId).updateData([
                    "status": MatchmakingStatus.matched.rawValue,
                    "battleId": battleId
                ])
                print("Local bot fallback succeeded.")
            } catch {
                print("Failed local bot fallback: \(error)")
            }
        }
    }

    private func createBattleDocument(battleId: String, myTeam: [BattlePlayer], opponent: MatchmakingTicket) async {
        let opponentTeam: [BattlePlayer]
        if let oppTeam = opponent.team, !oppTeam.isEmpty {
            opponentTeam = oppTeam
        } else {
            let oppPlayer = BattlePlayer(
                id: opponent.uid,
                name: opponent.playerName,
                characterClass: opponent.playerClass,
                health: 100 + (opponent.playerLevel * 10),
                maxHealth: 100 + (opponent.playerLevel * 10),
                avatarName: opponent.playerAvatar
            )
            opponentTeam = [oppPlayer]
        }
        
        let newBattle = Battle(
            id: battleId,
            type: self.currentSearchType,
            status: .active,
            localTeam: myTeam,
            opponentTeam: opponentTeam,
            secondsRemaining: 60
        )
        
        do {
            try db.collection("battles").document(battleId).setData(from: newBattle)
            self.listenToBattle(battleId: battleId)
        } catch {
            print("Failed to create battle document: \(error)")
        }
    }
    
    private func listenToBattle(battleId: String) {
        self.isSearching = false
        self.teammateFallbackTimer?.invalidate()
        self.opponentFallbackTimer?.invalidate()
        
        self.battleListener = db.collection("battles").document(battleId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let snapshot = snapshot, snapshot.exists else { return }
            guard var updatedBattle = try? snapshot.data(as: Battle.self) else { return }
            
            let myUid = FirebaseService.shared.currentCharacter?.id ?? ""
            var clientBattle = updatedBattle
            let isHost = updatedBattle.localTeam.contains { $0.id == myUid }
            
            if !isHost {
                clientBattle.opponentTeam = updatedBattle.localTeam
                clientBattle.localTeam = updatedBattle.opponentTeam
            }
            
            let elapsed = Int(Date().timeIntervalSince(updatedBattle.createdAt))
            let remaining = max(0, 60 - elapsed)
            clientBattle.secondsRemaining = remaining
            
            let myTeamAlive = clientBattle.localTeam.contains { $0.health > 0 }
            let oppTeamAlive = clientBattle.opponentTeam.contains { $0.health > 0 }
            
            if clientBattle.status == .active && (remaining <= 0 || !myTeamAlive || !oppTeamAlive) {
                let myReps = clientBattle.localTeam.map { $0.reps }.reduce(0, +)
                let oppReps = clientBattle.opponentTeam.map { $0.reps }.reduce(0, +)
                
                var winner = "draw"
                if !oppTeamAlive { winner = myUid }
                else if !myTeamAlive { winner = clientBattle.opponentTeam.first?.id ?? "opp" }
                else if myReps > oppReps { winner = myUid }
                else if oppReps > myReps { winner = clientBattle.opponentTeam.first?.id ?? "opp" }
                
                clientBattle.status = .completed
                clientBattle.winnerId = winner
                
                if isHost {
                    Task { try? await self.db.collection("battles").document(battleId).updateData([
                        "status": BattleStatus.completed.rawValue,
                        "winnerId": winner
                    ])}
                }
                
                if winner == myUid {
                    FirebaseService.shared.awardBattleRewards(xp: 250, gold: 60, isPvP: true)
                } else {
                    FirebaseService.shared.awardBattleRewards(xp: 50, gold: 15, isPvP: true)
                }
            }
            
            self.activeBattle = clientBattle
        }
    }
    
    func registerRepetition(isCorrectForm: Bool = true, isCritical: Bool = false) {
        guard let battle = activeBattle, battle.status == .active, let char = FirebaseService.shared.currentCharacter else { return }
        let myUid = char.id
        let serverBattleRef = db.collection("battles").document(battle.id)
        
        Task {
            let doc = try? await serverBattleRef.getDocument()
            guard var serverBattle = try? doc?.data(as: Battle.self) else { return }
            
            let isHost = serverBattle.localTeam.contains { $0.id == myUid }
            var myTeamRef = isHost ? serverBattle.localTeam : serverBattle.opponentTeam
            var oppTeamRef = isHost ? serverBattle.opponentTeam : serverBattle.localTeam
            
            if let myIdx = myTeamRef.firstIndex(where: { $0.id == myUid }) {
                myTeamRef[myIdx].reps += 1
            }
            
            var damage = Int(Double(char.combatPower) * 0.15)
            if !isCorrectForm { damage = max(1, damage / 2) }
            
            let aliveOpponents = oppTeamRef.enumerated().filter { $0.element.health > 0 }
            if let target = aliveOpponents.randomElement() {
                oppTeamRef[target.offset].health = max(0, target.element.health - damage)
            }
            
            let formText = isCorrectForm ? "" : "[BAD FORM] "
            let critText = isCritical ? "[CRIT] " : ""
            let targetName = aliveOpponents.randomElement()?.element.name ?? "Enemy"
            let event = CombatEvent(
                actorName: char.username,
                targetName: targetName,
                actionType: .attack,
                value: damage,
                detailText: "\(formText)\(critText)\(char.username) scores a hit! (\(damage) DMG)",
                isCritical: isCritical
            )
            serverBattle.combatLog.append(event)
            
            if isHost {
                serverBattle.localTeam = myTeamRef
                serverBattle.opponentTeam = oppTeamRef
            } else {
                serverBattle.opponentTeam = myTeamRef
                serverBattle.localTeam = oppTeamRef
            }
            
            try? serverBattleRef.setData(from: serverBattle)
        }
    }
    
    func leaveMatch() {
        self.isSearching = false
        self.teammateFallbackTimer?.invalidate()
        self.teammateFallbackTimer = nil
        self.opponentFallbackTimer?.invalidate()
        self.opponentFallbackTimer = nil
        self.matchmakingListener?.remove()
        self.battleListener?.remove()
        
        if let ticketId = currentTicketId {
            Task { try? await db.collection("matchmaking").document(ticketId).delete() }
            self.currentTicketId = nil
        }
        
        self.activeBattle = nil
    }
    
    func surrenderMatch() {
        guard let battle = activeBattle, battle.status == .active else { return }
        let oppUid = battle.opponentTeam.first?.id ?? "opp"
        Task { try? await db.collection("battles").document(battle.id).updateData([
            "status": BattleStatus.completed.rawValue,
            "winnerId": oppUid
        ])}
    }
}
