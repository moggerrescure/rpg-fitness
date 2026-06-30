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
    var pendingInvites: [String]?   // UIDs of friends invited to join 3v3 lobby
    var createdAt: Date = Date()
}

enum TeamSlotState {
    case me
    case invited(uid: String, name: String)
    case joined(uid: String, name: String, cls: CharacterClass)
    case bot
}

struct TeamSlot: Identifiable {
    let id: String
    var state: TeamSlotState
    var displayName: String {
        switch state {
        case .me: return FirebaseService.shared.currentCharacter?.username ?? "You"
        case .invited(_, let name): return name
        case .joined(_, let name, _): return name
        case .bot: return "Bot"
        }
    }
}

@MainActor
class MultiplayerService: ObservableObject {
    static let shared = MultiplayerService()
    
    @Published var activeBattle: Battle?
    @Published var isSearching: Bool = false
    @Published var incomingDuel: MatchmakingTicket?
    @Published var incomingTeamInvite: MatchmakingTicket?   // Incoming 3v3 team invite
    @Published var teamLobbyTicketId: String?               // Active 3v3 lobby ticket (host)
    @Published var teamLobbySlots: [TeamSlot] = []          // Visual lobby state
    @Published var friendDuelCountdown: Int? = nil          // 3→2→1 before friend battle shows
    @Published var isInTeamLobby: Bool = false               // True while 10s team assembly window is open
    
    private var pendingFriendBattle: Battle? = nil           // Held until countdown ends
    private var countdownTimer: Timer?
    
    private let db = Firestore.firestore()
    private var matchmakingListener: ListenerRegistration?
    private var battleListener: ListenerRegistration?
    private var incomingDuelListener: ListenerRegistration?
    private var teamInviteListener: ListenerRegistration?
    private var teamLobbyListener: ListenerRegistration?
    
    private var teammateFallbackTimer: Timer?
    private var opponentFallbackTimer: Timer?
    private var transitionTimer: Timer?
    private var currentTicketId: String?
    private var currentSearchType: BattleType = .duel1v1
    // Guard flag: prevents leaveMatch() from canceling a match that is in progress of being established
    private var isBattleStarting: Bool = false
    
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
        
        // Also listen for incoming 3v3 team invites (ticketId stored in pendingInvites)
        teamInviteListener?.remove()
        teamInviteListener = db.collection("matchmaking")
            .whereField("pendingInvites", arrayContains: myUid)
            .whereField("status", isEqualTo: MatchmakingStatus.searchingTeammates.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let doc = snapshot?.documents.first,
                   let ticket = try? doc.data(as: MatchmakingTicket.self) {
                    if self.activeBattle == nil && !self.isSearching {
                        self.incomingTeamInvite = ticket
                    }
                } else {
                    self.incomingTeamInvite = nil
                }
            }
    }
    
    // MARK: - 3v3 Team Battle (Direct, no separate lobby step)
    
    /// Opens the team lobby, creating the battle placeholder but NOT starting a timer.
    func initTeamLobby() {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        
        self.currentSearchType = .team3v3
        
        let myPlayer = BattlePlayer(
            id: char.id, name: char.username,
            characterClass: char.selectedClass,
            health: 100 + char.level * 10, maxHealth: 100 + char.level * 10,
            avatarName: char.avatarName
        )
        
        let battleId = "t3v3_\(UUID().uuidString)"
        
        // Build initial placeholder: host + empty slots (friends fill them on accept)
        let placeholder = Battle(
            id: battleId, type: .team3v3, status: .searching,
            localTeam: [myPlayer], opponentTeam: [], secondsRemaining: 60
        )
        
        let ticket = MatchmakingTicket(
            uid: char.id, playerClass: char.selectedClass, playerLevel: char.level,
            playerAvatar: char.avatarName ?? "avatar_knight", playerName: char.username,
            status: .searchingTeammates, teamType: .team3v3, team: [myPlayer],
            pendingInvites: []
        )
        
        do {
            try db.collection("battles").document(battleId).setData(from: placeholder)
            
            var ticketData = (try? Firestore.Encoder().encode(ticket) as? [String: Any]) ?? [:]
            ticketData["battleId"] = battleId
            let docRef = db.collection("matchmaking").addDocument(data: ticketData)
            
            self.teamLobbyTicketId = docRef.documentID
            self.currentTicketId = docRef.documentID
            
            // Set up lobby slots: Host + 2 empty Bot slots
            self.teamLobbySlots = [
                TeamSlot(id: char.id, state: .me),
                TeamSlot(id: "bot_\(UUID().uuidString)", state: .bot),
                TeamSlot(id: "bot_\(UUID().uuidString)", state: .bot)
            ]
            
            listenToTeamLobby(docRef: docRef, battleId: battleId, hostPlayer: myPlayer)
        } catch {
            print("Failed to init team lobby: \(error)")
        }
    }
    
    /// Sends an invite to a specific friend from the open team lobby.
    func sendTeamInvite(uid: String) {
        guard let ticketId = currentTicketId, let char = FirebaseService.shared.currentCharacter else { return }
        
        // Find first bot slot and replace with invited
        if let idx = teamLobbySlots.firstIndex(where: { if case .bot = $0.state { return true } else { return false } }) {
            teamLobbySlots[idx] = TeamSlot(id: uid, state: .invited(uid: uid, name: "Inviting..."))
        }
        
        // Update ticket in Firestore
        db.collection("matchmaking").document(ticketId).updateData([
            "pendingInvites": FieldValue.arrayUnion([uid])
        ])
        
        // Send notification
        NotificationManager.sendInAppNotification(
            to: uid,
            title: "3v3 Team Invite! ⚔️",
            message: "\(char.username) wants you on their 3v3 team! Tap to join.",
            type: .duel,
            actionData: ["type": "teamInvite", "ticketId": ticketId]
        )
    }
    
    private func listenToTeamLobby(docRef: DocumentReference, battleId: String, hostPlayer: BattlePlayer) {
        teamLobbyListener?.remove()
        teamLobbyListener = db.collection("battles").document(battleId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot, snapshot.exists else { return }
                guard let battle = try? snapshot.data(as: Battle.self) else { return }
                
                // Update slot states: anyone who joined appears in localTeam
                let joinedIds = Set(battle.localTeam.map { $0.id })
                self.teamLobbySlots = self.teamLobbySlots.map { slot in
                    var updated = slot
                    if case .invited(let uid, let name) = slot.state, joinedIds.contains(uid) {
                        if let player = battle.localTeam.first(where: { $0.id == uid }) {
                            updated.state = .joined(uid: uid, name: player.name, cls: player.characterClass)
                        }
                    }
                    return updated
                }
                
                // If battle is now active (host triggered start), stop listening
                if battle.status == .active {
                    self.teamLobbyListener?.remove()
                }
            }
    }
    
    /// Called when host taps GO NOW: cancels the 10s timer and starts battle immediately.
    func startTeamBattleFromLobby() {
        guard let ticketId = currentTicketId else { return }
        Task {
            if let ticketDoc = try? await db.collection("matchmaking").document(ticketId).getDocument(),
               let bId = ticketDoc.data()?["battleId"] as? String {
                self.startTeamBattle(battleId: bId)
            }
        }
    }
    
    /// Fills remaining team slots with bots, creates opponent team, sets battle to active.
    private func startTeamBattle(battleId: String) {
        teamLobbyListener?.remove()
        let ticketIdToDelete = currentTicketId
        teamLobbyTicketId = nil
        isInTeamLobby = false
        
        Task {
            // Read current battle to get who has joined
            guard let doc = try? await db.collection("battles").document(battleId).getDocument(),
                  var battle = try? doc.data(as: Battle.self) else { return }
            
            // Fill localTeam to 3 with bots
            let botNames = ["IronBot", "StoneBot", "SwiftBot"]
            let botClasses: [CharacterClass] = [.healer, .mage, .archer]
            var idx = 0
            while battle.localTeam.count < 3 {
                let cls = botClasses[idx % botClasses.count]
                battle.localTeam.append(BattlePlayer(
                    id: "bot_ally_\(UUID().uuidString)", name: botNames[idx % botNames.count],
                    characterClass: cls, health: 110, maxHealth: 110,
                    avatarName: "avatar_\(cls.rawValue.lowercased())"
                ))
                idx += 1
            }
            
            // Build opponent team of 3 bots
            let oppNames = ["ShadowFiend", "DoomBringer", "NightStalker"]
            let oppClasses: [CharacterClass] = [.swordsman, .mage, .archer]
            let opponentTeam = (0..<3).map { i in
                BattlePlayer(
                    id: "bot_opp_\(UUID().uuidString)", name: oppNames[i],
                    characterClass: oppClasses[i],
                    health: 110 + (i * 10), maxHealth: 110 + (i * 10),
                    avatarName: "avatar_\(oppClasses[i].rawValue.lowercased())"
                )
            }
            
            // Build the final complete battle and write it to Firestore
            let finalBattle = Battle(
                id: battleId, type: .team3v3, status: .active,
                localTeam: battle.localTeam, opponentTeam: opponentTeam,
                secondsRemaining: 60
            )
            
            do {
                try db.collection("battles").document(battleId).setData(from: finalBattle)
            } catch {
                print("Failed to start 3v3 battle: \(error)")
                return
            }
            
            if let tId = ticketIdToDelete {
                try? await db.collection("matchmaking").document(tId).delete()
            }
            
            self.currentTicketId = nil
            self.isSearching = false
            self.startFriendBattleCountdown(battle: finalBattle)
        }
    }
    
    /// Acceptor joins the team directly on the battle document.
    func acceptTeamInvite(_ ticket: MatchmakingTicket) {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        guard let battleId = ticket.battleId else {
            print("acceptTeamInvite: no battleId on ticket")
            self.incomingTeamInvite = nil
            return
        }
        
        self.incomingTeamInvite = nil
        self.isSearching = false
        
        let myPlayer = BattlePlayer(
            id: char.id, name: char.username,
            characterClass: char.selectedClass,
            health: 100 + char.level * 10, maxHealth: 100 + char.level * 10,
            avatarName: char.avatarName
        )
        
        Task {
            do {
                // Add self to localTeam on the battle document
                let playerData = try Firestore.Encoder().encode(myPlayer)
                try await db.collection("battles").document(battleId).updateData([
                    "localTeam": FieldValue.arrayUnion([playerData])
                ])
                
                // Remove self from pendingInvites on ticket
                if let ticketId = ticket.id {
                    try? await db.collection("matchmaking").document(ticketId).updateData([
                        "pendingInvites": FieldValue.arrayRemove([char.id])
                    ])
                }
                
                // Listen for battle to become active (host will trigger startTeamBattle)
                self.matchmakingListener = db.collection("battles").document(battleId)
                    .addSnapshotListener { [weak self] snapshot, _ in
                        guard let self = self, let snap = snapshot, snap.exists else { return }
                        guard let battle = try? snap.data(as: Battle.self) else { return }
                        guard battle.status == .active, !battle.opponentTeam.isEmpty else { return }
                        
                        self.matchmakingListener?.remove()
                        self.isSearching = false
                        
                        // Build acceptor-perspective battle (my player is in localTeam from server)
                        self.startFriendBattleCountdown(battle: battle)
                    }
                
                // Timeout after 30s: just cancel
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                    guard let self = self else { return }
                    self.matchmakingListener?.remove()
                    self.isSearching = false
                }
            } catch {
                print("acceptTeamInvite failed: \(error)")
            }
        }
    }
    
    /// Decline a 3v3 team invite.
    func declineTeamInvite(_ ticket: MatchmakingTicket) {
        self.incomingTeamInvite = nil
        guard let myUid = FirebaseService.shared.currentCharacter?.id, let ticketId = ticket.id else { return }
        
        Task {
            try? await db.collection("matchmaking").document(ticketId).updateData([
                "pendingInvites": FieldValue.arrayRemove([myUid])
            ])
        }
    }
    

    // MARK: - Friend Duels (Direct, no matchmaking queue)
    
    /// Challenger creates the battle document immediately and waits for acceptor to fill in their player.
    func challengeFriend(friendUid: String) {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        
        self.currentSearchType = .duel1v1
        isSearching = true
        
        let myPlayer = BattlePlayer(
            id: char.id, name: char.username,
            characterClass: char.selectedClass,
            health: 100 + char.level * 10, maxHealth: 100 + char.level * 10,
            avatarName: char.avatarName
        )
        
        // Write a placeholder battle: localTeam = challenger, opponentTeam = empty (filled on accept)
        let battleId = "fduel_\(UUID().uuidString)"
        let placeholder = Battle(
            id: battleId, type: .duel1v1, status: .searching,
            localTeam: [myPlayer], opponentTeam: [], secondsRemaining: 60
        )
        
        let ticket = MatchmakingTicket(
            uid: char.id, playerClass: char.selectedClass, playerLevel: char.level,
            playerAvatar: char.avatarName ?? "avatar_knight", playerName: char.username,
            status: .waitingForFriend, teamType: .duel1v1, team: [myPlayer], targetUid: friendUid
        )
        
        do {
            // Write battle placeholder
            try db.collection("battles").document(battleId).setData(from: placeholder)
            
            // Write matchmaking ticket so acceptor can find it
            var ticketData = (try? Firestore.Encoder().encode(ticket) as? [String: Any]) ?? [:]
            ticketData["battleId"] = battleId
            let docRef = db.collection("matchmaking").addDocument(data: ticketData)
            self.currentTicketId = docRef.documentID
            
            // Notify the friend
            NotificationManager.sendInAppNotification(
                to: friendUid,
                title: "Duel Challenge! ⚔️",
                message: "\(char.username) challenged you to a 1v1 duel! Tap to accept.",
                type: .duel,
                actionData: ["type": "duel", "ticketId": docRef.documentID]
            )
            
            // Listen for battle to become active (acceptor fills opponentTeam)
            self.matchmakingListener = db.collection("battles").document(battleId)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self, let snapshot = snapshot, snapshot.exists else { return }
                    guard let battle = try? snapshot.data(as: Battle.self) else { return }
                    guard battle.status == .active, !battle.opponentTeam.isEmpty else { return }
                    
                    self.matchmakingListener?.remove()
                    self.currentTicketId = nil
                    self.isSearching = false
                    
                    // Build challenger-perspective battle (challenger is localTeam)
                    var clientBattle = battle
                    clientBattle.localTeam = battle.localTeam
                    clientBattle.opponentTeam = battle.opponentTeam
                    self.startFriendBattleCountdown(battle: clientBattle)
                }
            
            // Timeout: 60 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                guard let self = self, self.currentTicketId == docRef.documentID else { return }
                self.leaveMatch()
            }
        } catch {
            print("Failed to challenge friend: \(error)")
            isSearching = false
        }
    }
    
    /// Acceptor fills in their player on the battle document, marking it active immediately.
    func acceptDuel(_ ticket: MatchmakingTicket) {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        guard let battleId = ticket.battleId else {
            print("acceptDuel: no battleId on ticket")
            self.incomingDuel = nil
            return
        }
        
        self.incomingDuel = nil
        self.isSearching = false
        
        let acceptorPlayer = BattlePlayer(
            id: char.id, name: char.username,
            characterClass: char.selectedClass,
            health: 100 + char.level * 10, maxHealth: 100 + char.level * 10,
            avatarName: char.avatarName
        )
        
        let challengerPlayer = ticket.team?.first ?? BattlePlayer(
            id: ticket.uid, name: ticket.playerName,
            characterClass: ticket.playerClass,
            health: 100 + ticket.playerLevel * 10, maxHealth: 100 + ticket.playerLevel * 10,
            avatarName: ticket.playerAvatar
        )
        
        Task {
            do {
                // Update the battle: set opponentTeam (acceptor) and mark active
                let acceptorData = try Firestore.Encoder().encode(acceptorPlayer)
                try await db.collection("battles").document(battleId).updateData([
                    "opponentTeam": [acceptorData],
                    "status": BattleStatus.active.rawValue,
                    "createdAt": Timestamp(date: Date())
                ])
                
                // Build acceptor-perspective battle (acceptor is localTeam, challenger is opponentTeam)
                let clientBattle = Battle(
                    id: battleId, type: .duel1v1, status: .active,
                    localTeam: [acceptorPlayer], opponentTeam: [challengerPlayer],
                    secondsRemaining: 60
                )
                self.startFriendBattleCountdown(battle: clientBattle)
            } catch {
                print("acceptDuel failed: \(error)")
            }
        }
    }
    
    /// Starts a 3-second countdown, then launches the friend battle.
    private func startFriendBattleCountdown(battle: Battle) {
        self.pendingFriendBattle = battle
        self.friendDuelCountdown = 3
        self.countdownTimer?.invalidate()
        
        var remaining = 3
        self.countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            remaining -= 1
            self.friendDuelCountdown = remaining
            if remaining <= 0 {
                timer.invalidate()
                self.countdownTimer = nil
                self.friendDuelCountdown = nil
                self.activeBattle = self.pendingFriendBattle
                self.pendingFriendBattle = nil
                self.listenToBattle(battleId: battle.id)
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
        
        // PVP costs 10 energy – try to consume, but don't block if low energy
        _ = FirebaseService.shared.consumeEnergy(amount: min(10, FirebaseService.shared.currentCharacter?.energy ?? 0))
        
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
                // If world boss not loaded yet, create a local one immediately
                let boss: WorldBoss
                if let activeBoss = FirebaseService.shared.activeWorldBoss {
                    boss = activeBoss
                } else {
                    let template = Boss.templates.last!
                    boss = WorldBoss(
                        id: "wb_local", bossTemplateId: template.id,
                        maxHealth: template.maxHealth, currentHealth: template.maxHealth,
                        isActive: true, startedAt: Date(), topAttackers: [:]
                    )
                    await MainActor.run { FirebaseService.shared.activeWorldBoss = boss }
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
                // Helper to scan for opponents and try to match
                func tryMatchWithExistingOpponent() async -> Bool {
                    let snapshot = try? await db.collection("matchmaking")
                        .whereField("status", isEqualTo: MatchmakingStatus.searchingOpponent.rawValue)
                        .whereField("teamType", isEqualTo: type.rawValue)
                        .limit(to: 5)
                        .getDocuments()
                    
                    let potentialMatches = snapshot?.documents.compactMap { try? $0.data(as: MatchmakingTicket.self) }
                        .filter { $0.uid != char.id } ?? []
                    
                    if let opponentTicket = potentialMatches.first, let opponentTicketId = opponentTicket.id {
                        let success = try? await matchWithOpponent(opponentTicketId: opponentTicketId, opponent: opponentTicket, myTeam: localTeam)
                        return success == true
                    }
                    return false
                }
                
                // First scan — fast path for when an opponent is already waiting
                if await tryMatchWithExistingOpponent() { return }
                
                // Race condition: if matchWithOpponent failed (two players found each other simultaneously
                // but only one transaction wins), add random jitter then try once more before
                // creating our own ticket. This breaks the symmetric race.
                let jitter = Double.random(in: 0.5...1.5)
                try? await Task.sleep(nanoseconds: UInt64(jitter * 1_000_000_000))
                
                // Guard: if we were cancelled while waiting, stop.
                guard self.isSearching else { return }
                
                // Second scan after jitter — catches opponents who just created their ticket
                if await tryMatchWithExistingOpponent() { return }
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
                    let capturedTicketId = docRef.documentID
                    // Reduced from 30s to 10s for fast bot fill
                    self.teammateFallbackTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                        // Only fire if we're still searching with the same ticket
                        guard self.currentTicketId == capturedTicketId, !self.isBattleStarting else { return }
                        Task { @MainActor in await self.fillTeammatesWithBots(ticketId: docRef.documentID) }
                    }
                }
            } else if ticket.status == .searchingOpponent {
                self.teammateFallbackTimer?.invalidate()
                self.teammateFallbackTimer = nil
                if self.opponentFallbackTimer == nil {
                    let capturedTicketId = docRef.documentID
                    // 20s gives real players time to finish App Check + Firestore latency before bots kick in.
                    // Previous 8s caused both players to almost always race against the bot timer.
                    self.opponentFallbackTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { _ in
                        // Only fire if we're still searching with the same ticket
                        guard self.currentTicketId == capturedTicketId, !self.isBattleStarting else { return }
                        Task { @MainActor in await self.triggerOpponentBotFallback(ticket: ticket, type: type) }
                    }
                    
                    // Re-scan for opponents 2.5s after creating our own ticket.
                    // This catches players who created their ticket milliseconds after our initial scan,
                    // which is the most common race-condition scenario.
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        guard self.currentTicketId == capturedTicketId, !self.isBattleStarting, self.isSearching else { return }
                        
                        guard let char = FirebaseService.shared.currentCharacter else { return }
                        let snapshot = try? await self.db.collection("matchmaking")
                            .whereField("status", isEqualTo: MatchmakingStatus.searchingOpponent.rawValue)
                            .whereField("teamType", isEqualTo: type.rawValue)
                            .limit(to: 5)
                            .getDocuments()
                        
                        let myTicketDoc = try? await docRef.getDocument()
                        guard let myCurrentTicket = try? myTicketDoc?.data(as: MatchmakingTicket.self),
                              myCurrentTicket.status == .searchingOpponent else { return }
                        
                        let potentialMatches = snapshot?.documents.compactMap { try? $0.data(as: MatchmakingTicket.self) }
                            .filter { $0.uid != char.id } ?? []
                        
                        if let opponentTicket = potentialMatches.first, let opponentTicketId = opponentTicket.id {
                            // Build local team from current ticket
                            let myTeam = myCurrentTicket.team ?? []
                            // matchWithOpponent calls createBattleDocument + listenToBattle internally
                            let matched = try? await self.matchWithOpponent(
                                opponentTicketId: opponentTicketId,
                                opponent: opponentTicket,
                                myTeam: myTeam
                            )
                            if matched == true {
                                // Successfully matched — cancel bot fallback timer and own listener
                                self.opponentFallbackTimer?.invalidate()
                                self.opponentFallbackTimer = nil
                                self.matchmakingListener?.remove()
                                self.currentTicketId = nil
                                // Delete our own ticket since we are now the challenger
                                Task { try? await docRef.delete() }
                            }
                        }
                    }
                }
            } else if ticket.status == .matched, let battleId = ticket.battleId {
                // Battle found — guard against leaveMatch race condition
                self.isBattleStarting = true
                self.matchmakingListener?.remove()
                self.teammateFallbackTimer?.invalidate()
                self.teammateFallbackTimer = nil
                self.opponentFallbackTimer?.invalidate()
                self.opponentFallbackTimer = nil
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
                // Guard against leaveMatch race condition
                self.isBattleStarting = true
                self.matchmakingListener?.remove()
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
                if let battleId = data["battleId"] as? String {
                    self.isBattleStarting = true
                    self.matchmakingListener?.remove()
                                     if let battleDict = data["battleData"] as? [String: Any] {
                        var decodedOppTeam: [BattlePlayer] = []
                        
                        if let oppTeamArray = battleDict["opponentTeam"] as? [Any] {
                            for oppAny in oppTeamArray {
                                if let opp = oppAny as? [String: Any],
                                   let id = opp["id"] as? String,
                                   let name = opp["name"] as? String,
                                   let charClassStr = opp["characterClass"] as? String,
                                   let charClass = CharacterClass(rawValue: charClassStr),
                                   let health = opp["health"] as? Int,
                                   let maxHealth = opp["maxHealth"] as? Int {
                                    
                                    let reps = opp["reps"] as? Int ?? 0
                                    let shield = opp["shield"] as? Int ?? 0
                                    let avatarName = opp["avatarName"] as? String
                                    
                                    decodedOppTeam.append(BattlePlayer(id: id, name: name, characterClass: charClass, health: health, maxHealth: maxHealth, reps: reps, shield: shield, avatarName: avatarName))
                                } else {
                                    print("Failed to parse individual bot from opponentTeam array: \(oppAny)")
                                }
                            }
                        } else {
                            print("Failed to cast opponentTeam to [Any]. Keys available: \(battleDict.keys)")
                        }
                        
                        // If parsing failed for ANY reason, fallback to a locally generated bot
                        if decodedOppTeam.isEmpty {
                            print("Server returned empty or unparseable bot team. Generating bot locally.")
                            let botClass = CharacterClass.allCases.randomElement() ?? .swordsman
                            decodedOppTeam.append(BattlePlayer(
                                id: "bot_fallback_\(UUID().uuidString)",
                                name: "AI Challenger",
                                characterClass: botClass,
                                health: 100 + (ticket.playerLevel * 10),
                                maxHealth: 100 + (ticket.playerLevel * 10),
                                avatarName: "avatar_knight"
                            ))
                        }
                        
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
                        
                        let clientBattle = Battle(
                            id: battleId,
                            type: type,
                            status: .active,
                            localTeam: myTeam,
                            opponentTeam: decodedOppTeam,
                            secondsRemaining: 60
                        )
                        
                        self.activeBattle = clientBattle
                        self.currentTicketId = nil
                        self.isSearching = false
                    } else {
                        print("Failed to cast battleData to [String: Any]. Type was: \(String(describing: Swift.type(of: data["battleData"])))")
                    }    
                    self.listenToBattle(battleId: battleId)
                    return
                }
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
        self.teammateFallbackTimer?.invalidate()
        self.teammateFallbackTimer = nil
        self.opponentFallbackTimer?.invalidate()
        self.opponentFallbackTimer = nil
        
        // Safety timeout to prevent infinite UI hangs if network drops, ONLY if we haven't already loaded the battle locally
        self.transitionTimer?.invalidate()
        if self.activeBattle == nil {
            self.transitionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                print("Battle transition timed out due to network issues.")
                self.isBattleStarting = false
                self.isSearching = false
                self.currentTicketId = nil
                self.battleListener?.remove()
            }
        }
        
        self.battleListener = db.collection("battles").document(battleId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            // If battleListener was removed by leaveMatch/endMatch, stop processing
            guard self.battleListener != nil else { return }
            
            if let error = error {
                print("Error listening to battle: \(error)")
                self.transitionTimer?.invalidate()
                self.isBattleStarting = false
                self.isSearching = false
                self.currentTicketId = nil
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else { return }
            guard var updatedBattle = try? snapshot.data(as: Battle.self) else { return }
            
            // Snapshot successfully received, invalidate transition guard
            self.transitionTimer?.invalidate()
            self.transitionTimer = nil
            
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
            
            // Grace period: don't evaluate the end condition in the first 3 seconds after
            // battle creation. This prevents instant-win when the very first Firestore
            // snapshot arrives before all clients have synced (clock skew or delayed doc creation).
            let gracePeriodElapsed = elapsed >= 3
            
            if clientBattle.status == .active && gracePeriodElapsed && (remaining <= 0 || !myTeamAlive || !oppTeamAlive) {
                let myReps = clientBattle.localTeam.map { $0.reps }.reduce(0, +)
                let oppReps = clientBattle.opponentTeam.map { $0.reps }.reduce(0, +)
                
                var winner = "draw"
                if !oppTeamAlive { winner = myUid }
                else if !myTeamAlive { winner = clientBattle.opponentTeam.first?.id ?? "opp" }
                else if myReps > oppReps { winner = myUid }
                else if oppReps > myReps { winner = clientBattle.opponentTeam.first?.id ?? "opp" }
                else {
                    let myHP = clientBattle.localTeam.map { $0.health }.reduce(0, +)
                    let oppHP = clientBattle.opponentTeam.map { $0.health }.reduce(0, +)
                    if myHP > oppHP { winner = myUid }
                    else if oppHP > myHP { winner = clientBattle.opponentTeam.first?.id ?? "opp" }
                }
                
                clientBattle.status = .completed
                clientBattle.winnerId = winner
                
                if isHost {
                    Task { try? await self.db.collection("battles").document(battleId).updateData([
                        "status": BattleStatus.completed.rawValue,
                        "winnerId": winner
                    ])}
                }
                
                if winner == myUid {
                    FirebaseService.shared.awardBattleRewards(xp: 250, gold: 60, isPvP: true, isPvPWinner: true)
                } else if winner != "draw" {
                    FirebaseService.shared.awardBattleRewards(xp: 50, gold: 15, isPvP: true, isPvPWinner: false)
                } else {
                    FirebaseService.shared.awardBattleRewards(xp: 100, gold: 30, isPvP: true, isPvPWinner: nil)
                }

                // Battle is fully resolved — clear the starting guard
                self.isBattleStarting = false
            }
            
            self.activeBattle = clientBattle
            
            // Always clear searching state once we have a live battle object —
            // previously this was gated on currentTicketId != nil, but listenToTicketAsHost
            // already nil-ed it before calling listenToBattle, causing the simulator to
            // stay stuck on the "Searching" screen forever until cancel was tapped.
            self.isSearching = false
            if self.currentTicketId != nil {
                self.currentTicketId = nil
            }
        }
    }
    
    func forceEndBattleTimeout() {
        guard var clientBattle = activeBattle, clientBattle.status == .active else { return }
        
        let elapsed = Int(Date().timeIntervalSince(clientBattle.createdAt))
        if elapsed < 58 { return } // Prevent accidental early triggers, allow slight margin
        
        let myUid = FirebaseService.shared.currentCharacter?.id ?? ""
        let isHost = clientBattle.localTeam.contains { $0.id == myUid }
        
        let myTeamAlive = clientBattle.localTeam.contains { $0.health > 0 }
        let oppTeamAlive = clientBattle.opponentTeam.contains { $0.health > 0 }
        
        let myReps = clientBattle.localTeam.map { $0.reps }.reduce(0, +)
        let oppReps = clientBattle.opponentTeam.map { $0.reps }.reduce(0, +)
        
        var winner = "draw"
        if !oppTeamAlive { winner = myUid }
        else if !myTeamAlive { winner = clientBattle.opponentTeam.first?.id ?? "opp" }
        else if myReps > oppReps { winner = myUid }
        else if oppReps > myReps { winner = clientBattle.opponentTeam.first?.id ?? "opp" }
        else {
            let myHP = clientBattle.localTeam.map { $0.health }.reduce(0, +)
            let oppHP = clientBattle.opponentTeam.map { $0.health }.reduce(0, +)
            if myHP > oppHP { winner = myUid }
            else if oppHP > myHP { winner = clientBattle.opponentTeam.first?.id ?? "opp" }
        }
        
        clientBattle.status = .completed
        clientBattle.winnerId = winner
        
        if isHost {
            Task { try? await self.db.collection("battles").document(clientBattle.id).updateData([
                "status": BattleStatus.completed.rawValue,
                "winnerId": winner
            ])}
        }
        
        if winner == myUid {
            FirebaseService.shared.awardBattleRewards(xp: 250, gold: 60, isPvP: true, isPvPWinner: true)
        } else if winner != "draw" {
            FirebaseService.shared.awardBattleRewards(xp: 50, gold: 15, isPvP: true, isPvPWinner: false)
        } else {
            FirebaseService.shared.awardBattleRewards(xp: 100, gold: 30, isPvP: true, isPvPWinner: nil)
        }
        
        self.isBattleStarting = false
        self.activeBattle = clientBattle
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
        // Don't cancel if a battle is in the process of starting (race condition guard)
        guard !isBattleStarting || activeBattle == nil else {
            // Already starting a battle — only clear searching state
            isSearching = false
            return
        }

        self.isSearching = false
        self.isBattleStarting = false
        self.isInTeamLobby = false
        self.teammateFallbackTimer?.invalidate()
        self.teammateFallbackTimer = nil
        self.opponentFallbackTimer?.invalidate()
        self.opponentFallbackTimer = nil
        self.matchmakingListener?.remove()
        self.battleListener?.remove()
        
        // Cancel any pending friend-duel countdown
        self.countdownTimer?.invalidate()
        self.countdownTimer = nil
        self.friendDuelCountdown = nil
        self.pendingFriendBattle = nil
        
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
