import FirebaseFunctions
import FirebaseAuth

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
    case bot(name: String, cls: CharacterClass, avatarName: String)
}

struct TeamSlot: Identifiable {
    let id: String
    var state: TeamSlotState
    var displayName: String {
        switch state {
        case .me: return FirebaseService.shared.currentCharacter?.username ?? "You"
        case .invited(_, let name): return name
        case .joined(_, let name, _): return name
        case .bot(let name, _, _): return name
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
    @Published var matchmakingError: String? = nil           // Shown when CF matchmaking fails
    
    private var pendingFriendBattle: Battle? = nil           // Held until countdown ends
    private var countdownTimer: Timer?
    /// Energy held for queue/lobby; refunded if match never becomes active.
    private var pendingMatchEnergyCharge: Int = 0
    
    private let db = Firestore.firestore()
    private var matchmakingListener: ListenerRegistration?
    private var battleListener: ListenerRegistration?
    private var incomingDuelListener: ListenerRegistration?
    private var teamInviteListener: ListenerRegistration?
    private var teamLobbyListener: ListenerRegistration?
    
    private var teammateFallbackTimer: Timer?
    private var opponentFallbackTimer: Timer?
    private var transitionTimer: Timer?
    /// Drives NPC damage for bot opponents / bot teammates in 1v1 and 3v3.
    private var botCombatTimer: Timer?
    /// Host alone writes bot AI ticks (avoids double damage with multiple humans).
    private var isBattleHost: Bool = false
    private var currentTicketId: String?
    private var currentSearchType: BattleType = .duel1v1
    // Guard flag: prevents leaveMatch() from canceling a match that is in progress of being established
    private var isBattleStarting: Bool = false
    /// Prevents duplicate XP/gold grants when battle snapshots keep firing after completion.
    private var rewardsAwardedBattleIds = Set<String>()
    
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
    
    // MARK: - Clan War skirmish (local bot, no PvP energy / matchmaking)
    
    /// Starts a one-off clan-war attack fight vs a bot. Score is recorded via `recordClanWarAttack` on completion.
    func startClanWarSkirmish() {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        guard let clan = FirebaseService.shared.userClan,
              let war = clan.activeWar,
              war.phase == .active else {
            matchmakingError = "Clan war is not active yet."
            return
        }
        if let me = clan.members.first(where: { $0.id == char.id }), me.warAttacksUsed >= 3 {
            matchmakingError = "No war attacks left (3/3 used)."
            return
        }
        guard activeBattle == nil, !isSearching else {
            matchmakingError = "Finish your current battle first."
            return
        }
        
        leaveMatch()
        matchmakingError = nil
        currentSearchType = .clanWar
        
        let myPlayer = BattlePlayer(
            id: char.id, name: char.username,
            characterClass: char.selectedClass,
            health: 100 + char.level * 10, maxHealth: 100 + char.level * 10,
            avatarName: char.avatarName
        )
        let oppName = war.opponentClanName ?? "War Rival"
        let identity = BotRoster.makeOpponent(index: Int.random(in: 0...4), preferredClass: nil)
        let bot = identity.asBattlePlayer(
            id: "bot_cwar_\(UUID().uuidString.prefix(6))",
            health: 100 + char.level * 10
        )
        var renamed = bot
        renamed.name = oppName
        
        var battle = Battle(
            id: "cwar_\(UUID().uuidString.prefix(8))",
            type: .clanWar,
            status: .active,
            localTeam: [myPlayer],
            opponentTeam: [renamed],
            secondsRemaining: 60
        )
        battle.normalizeParticipantAvatars()
        activeBattle = battle
        isSearching = false
    }
    
    // MARK: - 3v3 Team Battle (Direct, no separate lobby step)
    
    /// Opens the team lobby, creating the battle placeholder but NOT starting a timer.
    func initTeamLobby() {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        
        guard FirebaseService.shared.consumeEnergy(amount: 10) else {
            matchmakingError = "Not enough energy for 3v3 (need 10)."
            return
        }
        pendingMatchEnergyCharge = 10
        
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
        var lobbyBattle = placeholder
        lobbyBattle.ensureParticipantUids()
        
        let ticket = MatchmakingTicket(
            uid: char.id, playerClass: char.selectedClass, playerLevel: char.level,
            playerAvatar: char.avatarName ?? "avatar_knight", playerName: char.username,
            status: .searchingTeammates, teamType: .team3v3, team: [myPlayer],
            pendingInvites: []
        )
        
        do {
            try db.collection("battles").document(battleId).setData(from: lobbyBattle)
            
            var ticketData = (try? Firestore.Encoder().encode(ticket) as? [String: Any]) ?? [:]
            ticketData["battleId"] = battleId
            let docRef = db.collection("matchmaking").addDocument(data: ticketData)
            
            self.teamLobbyTicketId = docRef.documentID
            self.currentTicketId = docRef.documentID
            self.isInTeamLobby = true
            self.matchmakingError = nil
            
            // Set up lobby slots: Host + 2 fantasy bot placeholders
            let allyA = BotRoster.makeAlly(index: 0, preferredClass: .healer)
            let allyB = BotRoster.makeAlly(index: 1, preferredClass: .mage)
            self.teamLobbySlots = [
                TeamSlot(id: char.id, state: .me),
                TeamSlot(id: "bot_slot_0", state: .bot(name: allyA.name, cls: allyA.characterClass, avatarName: allyA.avatarName)),
                TeamSlot(id: "bot_slot_1", state: .bot(name: allyB.name, cls: allyB.characterClass, avatarName: allyB.avatarName))
            ]
            
            listenToTeamLobby(docRef: docRef, battleId: battleId, hostPlayer: myPlayer)
        } catch {
            print("Failed to init team lobby: \(error)")
            refundPendingMatchEnergy()
            matchmakingError = "Could not open 3v3 lobby. Check your connection."
            isInTeamLobby = false
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
    
    /// Fills ally slots via Cloud Function, then enters real opponent matchmaking queue.
    private func startTeamBattle(battleId: String) {
        guard let ticketId = currentTicketId else { return }
        teamLobbyListener?.remove()
        teamLobbyTicketId = nil
        isInTeamLobby = false

        Task {
            guard let battleDoc = try? await db.collection("battles").document(battleId).getDocument(),
                  let battle = try? battleDoc.data(as: Battle.self) else { return }

            // Sync human teammates from the battle doc into the matchmaking ticket before bot fill.
            if let teamData = try? Firestore.Encoder().encode(battle.localTeam) {
                try? await db.collection("matchmaking").document(ticketId).updateData([
                    "team": teamData
                ])
            }

            self.isSearching = true
            self.matchmakingError = nil
            await fillTeammatesWithBots(ticketId: ticketId)

            // Sync filled team onto the lobby battle document
            if let ticketDoc = try? await db.collection("matchmaking").document(ticketId).getDocument(),
               let ticket = try? ticketDoc.data(as: MatchmakingTicket.self),
               let team = ticket.team {
                try? await db.collection("battles").document(battleId).updateData([
                    "localTeam": try Firestore.Encoder().encode(team)
                ])
            }

            let docRef = db.collection("matchmaking").document(ticketId)
            self.listenToTicketAsHost(docRef: docRef, type: .team3v3)
        }
    }
    
    /// Acceptor joins the 3v3 lobby via `joinTeam` CF (updates ticket.team + battle.localTeam).
    func acceptTeamInvite(_ ticket: MatchmakingTicket) {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        guard let ticketId = ticket.id else {
            print("acceptTeamInvite: no ticket id")
            self.incomingTeamInvite = nil
            matchmakingError = "Invite expired. Ask your teammate to invite again."
            return
        }
        guard ticket.battleId != nil else {
            print("acceptTeamInvite: no battleId on ticket")
            self.incomingTeamInvite = nil
            matchmakingError = "Invite is incomplete. Ask your teammate to invite again."
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
                let guestsData = [try Firestore.Encoder().encode(myPlayer)]
                let result = try await Functions.functions().httpsCallable("joinTeam").call([
                    "ticketId": ticketId,
                    "guests": guestsData
                ])
                guard let data = result.data as? [String: Any],
                      data["success"] as? Bool == true,
                      let battleId = (data["battleId"] as? String) ?? ticket.battleId else {
                    await MainActor.run {
                        self.matchmakingError = "Could not join team. The invite may have expired."
                    }
                    return
                }
                
                // Listen for battle to become active (host will trigger startTeamBattle)
                self.matchmakingListener = db.collection("battles").document(battleId)
                    .addSnapshotListener { [weak self] snapshot, _ in
                        guard let self = self, let snap = snapshot, snap.exists else { return }
                        guard let battle = try? snap.data(as: Battle.self) else { return }
                        guard battle.status == .active, !battle.opponentTeam.isEmpty else { return }
                        
                        self.matchmakingListener?.remove()
                        self.isSearching = false
                        
                        self.startFriendBattleCountdown(battle: battle)
                    }
                
                // Host may linger in lobby then wait ~20s for opponent bot fallback — keep listening.
                DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
                    guard let self = self else { return }
                    guard self.activeBattle == nil, self.pendingFriendBattle == nil else { return }
                    self.matchmakingListener?.remove()
                    self.isSearching = false
                }
            } catch {
                print("acceptTeamInvite failed: \(error)")
                await MainActor.run {
                    self.matchmakingError = "Could not join team. Try again."
                }
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

        if BlockedUsersStore.isBlocked(friendUid) {
            matchmakingError = "You've blocked this player."
            return
        }
        
        guard FirebaseService.shared.consumeEnergy(amount: 10) else {
            matchmakingError = "Not enough energy for a duel (need 10)."
            return
        }
        pendingMatchEnergyCharge = 10
        
        self.currentSearchType = .duel1v1
        isSearching = true
        matchmakingError = nil
        
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
        var duelPlaceholder = placeholder
        duelPlaceholder.ensureParticipantUids()
        
        let ticket = MatchmakingTicket(
            uid: char.id, playerClass: char.selectedClass, playerLevel: char.level,
            playerAvatar: char.avatarName ?? "avatar_knight", playerName: char.username,
            status: .waitingForFriend, teamType: .duel1v1, team: [myPlayer], targetUid: friendUid
        )
        
        do {
            // Write battle placeholder
            try db.collection("battles").document(battleId).setData(from: duelPlaceholder)
            
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
            refundPendingMatchEnergy()
            matchmakingError = "Could not send duel challenge. Check your connection."
        }
    }
    
    /// Acceptor fills in their player on the battle document, marking it active immediately.
    func acceptDuel(_ ticket: MatchmakingTicket) {
        guard let char = FirebaseService.shared.currentCharacter else { return }
        guard let ticketId = ticket.id else {
            print("acceptDuel: no ticket id")
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
        
        Task {
            do {
                let functions = Functions.functions()
                let acceptorPayload: [String: Any] = [
                    "id": acceptorPlayer.id,
                    "name": acceptorPlayer.name,
                    "characterClass": acceptorPlayer.characterClass.rawValue,
                    "health": acceptorPlayer.health,
                    "maxHealth": acceptorPlayer.maxHealth,
                    "avatarName": acceptorPlayer.avatarName ?? "avatar_knight"
                ]
                let result = try await functions.httpsCallable("acceptFriendDuel").call([
                    "ticketId": ticketId,
                    "acceptor": acceptorPayload
                ])
                
                guard let data = result.data as? [String: Any],
                      let battleId = data["battleId"] as? String else {
                    throw NSError(domain: "FitRPG", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bad accept response"])
                }
                
                let challengerPlayer: BattlePlayer
                if let challengerData = data["challenger"] as? [String: Any],
                   let decoded = try? Firestore.Decoder().decode(BattlePlayer.self, from: challengerData) {
                    challengerPlayer = decoded
                } else {
                    challengerPlayer = ticket.team?.first ?? BattlePlayer(
                        id: ticket.uid, name: ticket.playerName,
                        characterClass: ticket.playerClass,
                        health: 100 + ticket.playerLevel * 10, maxHealth: 100 + ticket.playerLevel * 10,
                        avatarName: ticket.playerAvatar
                    )
                }
                
                let clientBattle = Battle(
                    id: battleId, type: .duel1v1, status: .active,
                    localTeam: [acceptorPlayer], opponentTeam: [challengerPlayer],
                    secondsRemaining: 60
                )
                self.startFriendBattleCountdown(battle: clientBattle)
            } catch {
                print("acceptDuel failed: \(error)")
                matchmakingError = "Could not join duel. The challenge may have expired."
            }
        }
    }
    
    /// Starts a 3-second countdown, then launches the friend battle.
    private func startFriendBattleCountdown(battle: Battle) {
        pendingMatchEnergyCharge = 0 // Match is on — keep the energy cost
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
        guard let id = ticket.id else { return }
        Task {
            do {
                let functions = Functions.functions()
                _ = try await functions.httpsCallable("declineFriendDuel").call(["ticketId": id])
            } catch {
                // Fallback: delete ticket if CF unavailable
                try? await db.collection("matchmaking").document(id).delete()
            }
        }
    }
    
    private func refundPendingMatchEnergy() {
        guard pendingMatchEnergyCharge > 0 else { return }
        let amount = pendingMatchEnergyCharge
        pendingMatchEnergyCharge = 0
        FirebaseService.shared.refundEnergy(amount: amount)
    }
    
    // MARK: - Core Matchmaking
    
    func startMatchmaking(for characterClass: CharacterClass, type: BattleType = .duel1v1, invitedFriends: [String] = []) {
        guard let char = FirebaseService.shared.currentCharacter else { return }

        // World Boss / raid MM is not a PvP queue — send players to Raid tab (avoids energy leak).
        if type == .worldBoss || type == .bossRaid {
            matchmakingError = type == .worldBoss
                ? "Open the Raids tab to attack the World Boss."
                : "Boss raids require an active World Boss in the Raids tab."
            return
        }
        
        // PVP costs 10 energy — block matchmaking when insufficient
        guard FirebaseService.shared.consumeEnergy(amount: 10) else {
            matchmakingError = "Not enough energy (need 10)."
            return
        }
        pendingMatchEnergyCharge = 10
        
        self.currentSearchType = type
        isSearching = true
        matchmakingError = nil
        
        var localTeam: [BattlePlayer] = []
        localTeam.append(BattlePlayer(id: char.id, name: char.username, characterClass: characterClass, health: 100 + char.level * 10, maxHealth: 100 + char.level * 10, avatarName: char.avatarName))
        
        if type == .team3v3 {
            for friend in invitedFriends {
                if localTeam.count < 3 {
                    localTeam.append(BattlePlayer(id: "friend_\(friend)", name: friend, characterClass: .swordsman, health: 110, maxHealth: 110, avatarName: "avatar_knight"))
                }
            }
        }
        
        let initialStatus: MatchmakingStatus = (type == .team3v3 && localTeam.count < 3) ? .searchingTeammates : .searchingOpponent
        
        Task {
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
                createOwnTicket(myChar: char, myClass: characterClass, type: type, myTeam: localTeam, initialStatus: initialStatus)
            } else if initialStatus == .searchingOpponent {
                // Always create our ticket first so matchWithOpponent always has myTicketId
                // (server rejects calls without it — the old pre-ticket fast path always failed).
                createOwnTicket(myChar: char, myClass: characterClass, type: type, myTeam: localTeam, initialStatus: initialStatus)
                guard let myTicketId = self.currentTicketId, self.isSearching else { return }

                func tryMatchWithExistingOpponent() async -> Bool {
                    let snapshot = try? await db.collection("matchmaking")
                        .whereField("status", isEqualTo: MatchmakingStatus.searchingOpponent.rawValue)
                        .whereField("teamType", isEqualTo: type.rawValue)
                        .limit(to: 5)
                        .getDocuments()
                    
                    let tickets = snapshot?.documents.compactMap { try? $0.data(as: MatchmakingTicket.self) } ?? []
                    let blocked = BlockedUsersStore.blockedUIDs
                    let potentialMatches = tickets.filter {
                        $0.uid != char.id && $0.id != myTicketId && !blocked.contains($0.uid)
                    }
                    
                    if let opponentTicket = potentialMatches.first, let opponentTicketId = opponentTicket.id {
                        let success = try? await matchWithOpponent(opponentTicketId: opponentTicketId, opponent: opponentTicket, myTeam: localTeam)
                        return success == true
                    }
                    return false
                }
                
                if await tryMatchWithExistingOpponent() {
                    self.opponentFallbackTimer?.invalidate()
                    self.opponentFallbackTimer = nil
                    self.matchmakingListener?.remove()
                    let ticketToDelete = myTicketId
                    self.currentTicketId = nil
                    Task { try? await self.db.collection("matchmaking").document(ticketToDelete).delete() }
                    return
                }
                
                let jitter = Double.random(in: 0.5...1.5)
                try? await Task.sleep(nanoseconds: UInt64(jitter * 1_000_000_000))
                guard self.isSearching, self.currentTicketId == myTicketId else { return }
                if await tryMatchWithExistingOpponent() {
                    self.opponentFallbackTimer?.invalidate()
                    self.opponentFallbackTimer = nil
                    self.matchmakingListener?.remove()
                    let ticketToDelete = myTicketId
                    self.currentTicketId = nil
                    Task { try? await self.db.collection("matchmaking").document(ticketToDelete).delete() }
                }
                // Host listener + bot fallback continue if still unmatched
            } else {
                createOwnTicket(myChar: char, myClass: characterClass, type: type, myTeam: localTeam, initialStatus: initialStatus)
            }
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
            await MainActor.run {
                self.matchmakingError = "Could not join team. Try again."
            }
        }
        return false
    }

    private func matchWithOpponent(opponentTicketId: String, opponent: MatchmakingTicket, myTeam: [BattlePlayer]) async throws -> Bool {
        let functions = Functions.functions()
        do {
            var payload: [String: Any] = ["opponentTicketId": opponentTicketId]
            if let myTicketId = currentTicketId {
                payload["myTicketId"] = myTicketId
            }
            let result = try await functions.httpsCallable("matchWithOpponent").call(payload)
            
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
            await MainActor.run {
                self.matchmakingError = "Match failed. Still searching…"
            }
        }
        return false
    }

    private func createOwnTicket(myChar: Character, myClass: CharacterClass, type: BattleType, myTeam: [BattlePlayer], initialStatus: MatchmakingStatus) {
        let ticket = MatchmakingTicket(
            uid: myChar.id, playerClass: myClass, playerLevel: myChar.level,
            playerAvatar: myChar.avatarName ?? "avatar_knight", playerName: myChar.username,
            status: initialStatus, teamType: type, team: myTeam
        )
        
        do {
            let docRef = try db.collection("matchmaking").addDocument(from: ticket)
            self.currentTicketId = docRef.documentID
            self.listenToTicketAsHost(docRef: docRef, type: type)
        } catch {
            print("Failed to create ticket: \(error)")
            isSearching = false
            refundPendingMatchEnergy()
            matchmakingError = "Could not enter matchmaking queue."
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
                var allyIndex = 0
                while team.count < 3 {
                    let preferred: CharacterClass = team.count == 1 ? .healer : .mage
                    let identity = BotRoster.makeAlly(index: allyIndex, preferredClass: preferred)
                    let botPlayer = identity.asBattlePlayer(
                        id: "bot_\(UUID().uuidString)",
                        health: 100 + (ticket.playerLevel * 10)
                    )
                    team.append(botPlayer)
                    allyIndex += 1
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
                            let identity = BotRoster.makeOpponent(index: 0, preferredClass: .swordsman)
                            decodedOppTeam.append(identity.asBattlePlayer(
                                id: "bot_fallback_\(UUID().uuidString)",
                                health: 100 + (ticket.playerLevel * 10)
                            ))
                        } else {
                            decodedOppTeam.normalizeBattleAvatars()
                        }
                        
                        var myTeam = ticket.team ?? []
                        myTeam.normalizeBattleAvatars()
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
                        
                        var clientBattle = Battle(
                            id: battleId,
                            type: type,
                            status: .active,
                            localTeam: myTeam,
                            opponentTeam: decodedOppTeam,
                            secondsRemaining: 60
                        )
                        clientBattle.normalizeParticipantAvatars()
                        
                        self.isBattleHost = true
                        self.activeBattle = clientBattle
                        self.startBotCombatIfNeeded(for: clientBattle)
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
            
            // Local bot creation (no createdByServer — rules forbid client stamp → no ranked settle)
            let botCount = type == .team3v3 ? 3 : 1
            let identities = BotRoster.makeOpponents(count: botCount)
            var opponentBots: [BattlePlayer] = []
            for (i, identity) in identities.enumerated() {
                let health = 100 + (ticket.playerLevel * 10) + (i * 10)
                opponentBots.append(identity.asBattlePlayer(
                    id: "bot_\(UUID().uuidString)",
                    health: health
                ))
            }
            
            // Reuse lobby battleId so 3v3 guests still listening on that doc see the match.
            let battleId = ticket.battleId ?? "battle_\(UUID().uuidString)"
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
            
            do {
                let battleRef = db.collection("battles").document(battleId)
                let existing = try await battleRef.getDocument()
                if existing.exists {
                    // Keep participantUids unchanged (rules); only fill opponents + activate.
                    try await battleRef.updateData([
                        "type": type.rawValue,
                        "status": BattleStatus.active.rawValue,
                        "localTeam": try Firestore.Encoder().encode(myTeam),
                        "opponentTeam": try Firestore.Encoder().encode(opponentBots),
                        "secondsRemaining": 60
                    ])
                } else {
                    var battle = Battle(
                        id: battleId,
                        type: type,
                        status: .active,
                        localTeam: myTeam,
                        opponentTeam: opponentBots,
                        secondsRemaining: 60
                    )
                    battle.ensureParticipantUids()
                    try battleRef.setData(from: battle)
                }
                try await db.collection("matchmaking").document(ticketId).updateData([
                    "status": MatchmakingStatus.matched.rawValue,
                    "battleId": battleId
                ])
                self.isBattleStarting = true
                self.isBattleHost = true
                self.matchmakingListener?.remove()
                self.listenToBattle(battleId: battleId)
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
        
        var newBattle = Battle(
            id: battleId,
            type: self.currentSearchType,
            status: .active,
            localTeam: myTeam,
            opponentTeam: opponentTeam,
            secondsRemaining: 60
        )
        newBattle.ensureParticipantUids()
        
        do {
            let battleRef = db.collection("battles").document(battleId)
            let existing = try await battleRef.getDocument()
            if existing.exists,
               (existing.data()?["createdByServer"] as? Bool) == true {
                // CF already stamped this match — listen only (do not wipe stamp).
                self.matchmakingError = nil
                self.listenToBattle(battleId: battleId)
                return
            }
            if existing.exists, var lobbyBattle = try? existing.data(as: Battle.self) {
                // Preserve human teammates already on a 3v3 lobby battle doc
                if !lobbyBattle.localTeam.isEmpty {
                    newBattle.localTeam = lobbyBattle.localTeam
                }
                newBattle.ensureParticipantUids()
                try battleRef.setData(from: newBattle, merge: false)
            } else {
                try battleRef.setData(from: newBattle)
            }
            self.matchmakingError = nil
            self.listenToBattle(battleId: battleId)
        } catch {
            print("Failed to create battle document: \(error)")
            self.isSearching = false
            self.matchmakingError = "Could not start battle. Try again."
        }
    }
    
    private func listenToBattle(battleId: String) {
        pendingMatchEnergyCharge = 0 // Match found — keep energy cost
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
            Task { @MainActor in
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
                updatedBattle.normalizeParticipantAvatars()
                
                // Snapshot successfully received, invalidate transition guard
                self.transitionTimer?.invalidate()
                self.transitionTimer = nil
                
                let myUid = Auth.auth().currentUser?.uid
                    ?? FirebaseService.shared.currentCharacter?.id
                    ?? ""
                var clientBattle = updatedBattle
                let isHost = updatedBattle.localTeam.contains { $0.id == myUid }
                self.isBattleHost = isHost
                
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
                
                var shouldSettleRewards = false
                
                if let surrenderedBy = clientBattle.surrenderedBy, !surrenderedBy.isEmpty,
                   clientBattle.status == .active {
                    // Peer/self surrendered before status flip landed — end locally.
                    clientBattle.applyLocalSurrender(by: surrenderedBy)
                    if isHost {
                        Task { try? await self.db.collection("battles").document(battleId).updateData([
                            "status": BattleStatus.completed.rawValue
                        ])}
                    }
                    shouldSettleRewards = true
                } else if clientBattle.status == .active && gracePeriodElapsed && (remaining <= 0 || !myTeamAlive || !oppTeamAlive) {
                    clientBattle.deriveClientWinnerId(preferringMyUid: myUid)
                    clientBattle.status = .completed
                    
                    if isHost {
                        // Do not write winnerId (rules + CF derive). Mark completed for peers.
                        Task { try? await self.db.collection("battles").document(battleId).updateData([
                            "status": BattleStatus.completed.rawValue
                        ])}
                    }
                    
                    shouldSettleRewards = true
                } else if clientBattle.status == .completed {
                    // Peer/CF already finished the match — guests & surrender opponents must still settle.
                    if clientBattle.winnerId == nil || clientBattle.winnerId?.isEmpty == true {
                        clientBattle.deriveClientWinnerId(preferringMyUid: myUid)
                    }
                    shouldSettleRewards = true
                }
                
                if shouldSettleRewards {
                    self.stopBotCombat()
                    if !self.rewardsAwardedBattleIds.contains(battleId) {
                        self.rewardsAwardedBattleIds.insert(battleId)
                        FirebaseService.shared.resolvePvPBattle(battleId: battleId)
                    }
                    self.isBattleStarting = false
                } else if clientBattle.status == .active {
                    self.startBotCombatIfNeeded(for: clientBattle)
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
    }
    
    func forceEndBattleTimeout() {
        guard var clientBattle = activeBattle, clientBattle.status == .active else { return }
        
        let elapsed = Int(Date().timeIntervalSince(clientBattle.createdAt))
        if elapsed < 58 { return } // Prevent accidental early triggers, allow slight margin
        
        stopBotCombat()
        
        let myUid = Auth.auth().currentUser?.uid
            ?? FirebaseService.shared.currentCharacter?.id
            ?? ""
        let isHost = isBattleHost || clientBattle.localTeam.contains { $0.id == myUid }
        
        clientBattle.deriveClientWinnerId(preferringMyUid: myUid)
        clientBattle.status = .completed
        
        if isHost {
            Task { try? await self.db.collection("battles").document(clientBattle.id).updateData([
                "status": BattleStatus.completed.rawValue
            ])}
        }
        
        if !rewardsAwardedBattleIds.contains(clientBattle.id) {
            rewardsAwardedBattleIds.insert(clientBattle.id)
            FirebaseService.shared.resolvePvPBattle(battleId: clientBattle.id)
        }
        
        self.isBattleStarting = false
        self.activeBattle = clientBattle
    }

    func registerRepetition(isCorrectForm: Bool = true, isCritical: Bool = false) {
        guard let battle = activeBattle, battle.status == .active, let char = FirebaseService.shared.currentCharacter else { return }
        let myUid = Auth.auth().currentUser?.uid ?? char.id
        let serverBattleRef = db.collection("battles").document(battle.id)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let doc: DocumentSnapshot
            do {
                doc = try transaction.getDocument(serverBattleRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var serverBattle = try? doc.data(as: Battle.self) else { return nil }
            // Do not clobber surrender / completed state with a stale rep write.
            guard serverBattle.status == .active else { return nil }
            if let surrenderedBy = serverBattle.surrenderedBy, !surrenderedBy.isEmpty { return nil }
            
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
            
            do {
                try transaction.setData(from: serverBattle, forDocument: serverBattleRef, merge: true)
            } catch let error as NSError {
                errorPointer?.pointee = error
            }
            return nil
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
            }
        }
    }
    
    // MARK: - Bot combat AI (1v1 / 3v3 NPC damage)
    
    private func startBotCombatIfNeeded(for battle: Battle) {
        guard isBattleHost, battle.status == .active, battle.hasBotCombatants else {
            if !battle.hasBotCombatants { stopBotCombat() }
            return
        }
        guard botCombatTimer == nil else { return }
        // ~2.8s cadence: meaningful HP pressure over a 60s match without melting the player instantly.
        botCombatTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickBotCombat()
            }
        }
        // First pulse shortly after countdown so bots are not idle for 3s+.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self.tickBotCombat()
        }
    }
    
    private func stopBotCombat() {
        botCombatTimer?.invalidate()
        botCombatTimer = nil
    }
    
    private func tickBotCombat() {
        guard isBattleHost,
              let battle = activeBattle,
              battle.status == .active,
              battle.hasBotCombatants else {
            stopBotCombat()
            return
        }
        
        let level = FirebaseService.shared.currentCharacter?.level ?? 1
        // Scale near player hit power so bots feel like a real opponent.
        let damagePerHit = max(6, Int(Double(100 + level * 10) * 0.12))
        let serverBattleRef = db.collection("battles").document(battle.id)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let doc: DocumentSnapshot
            do {
                doc = try transaction.getDocument(serverBattleRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var serverBattle = try? doc.data(as: Battle.self) else { return nil }
            guard serverBattle.status == .active else { return nil }
            if let surrenderedBy = serverBattle.surrenderedBy, !surrenderedBy.isEmpty { return nil }
            
            // Apply on server orientation (host localTeam).
            guard serverBattle.applyBotCombatTick(damagePerHit: damagePerHit) else { return nil }
            
            do {
                try transaction.setData(from: serverBattle, forDocument: serverBattleRef, merge: true)
            } catch let error as NSError {
                errorPointer?.pointee = error
            }
            return nil
        }) { _, error in
            if let error = error {
                print("Bot combat tick failed: \(error)")
            }
        }
    }
    
    func leaveMatch() {
        // Don't cancel if a battle is in the process of starting (race condition guard)
        guard !isBattleStarting || activeBattle == nil else {
            // Already starting a battle — only clear searching state
            isSearching = false
            return
        }

        // Refund energy if we never entered an active battle
        if activeBattle == nil {
            refundPendingMatchEnergy()
        } else {
            pendingMatchEnergyCharge = 0
        }

        self.isSearching = false
        self.isBattleStarting = false
        self.isInTeamLobby = false
        self.matchmakingError = nil
        self.teammateFallbackTimer?.invalidate()
        self.teammateFallbackTimer = nil
        self.opponentFallbackTimer?.invalidate()
        self.opponentFallbackTimer = nil
        self.stopBotCombat()
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
        guard var battle = activeBattle, battle.status == .active else { return }
        let myUid = Auth.auth().currentUser?.uid
            ?? FirebaseService.shared.currentCharacter?.id
            ?? ""
        guard !myUid.isEmpty else {
            print("surrenderMatch: missing auth uid")
            return
        }
        
        let battleId = battle.id
        stopBotCombat()
        battle.applyLocalSurrender(by: myUid)
        activeBattle = battle
        
        Task {
            do {
                try await db.collection("battles").document(battleId).updateData([
                    "status": BattleStatus.completed.rawValue,
                    "surrenderedBy": myUid
                ])
            } catch {
                print("surrenderMatch Firestore update failed: \(error)")
            }
            if !self.rewardsAwardedBattleIds.contains(battleId) {
                self.rewardsAwardedBattleIds.insert(battleId)
                FirebaseService.shared.resolvePvPBattle(battleId: battleId)
            }
        }
    }
}
