import Foundation
import Combine
import FirebaseFirestore

struct ClanWarResult {
    var won: Bool
    var myScore: Int
    var oppScore: Int
    var xpEarned: Int
    var trophiesChange: Int
    var clanLeveledUp: Bool
    var lootRewarded: EquipmentItem?
}

class ClanVM: ObservableObject {
    @Published var userClan: Clan? {
        didSet {
            checkWarEnd()
        }
    }

    @Published var searchResults: [Clan] = []
    @Published var leaderboardClans: [Clan] = []
    @Published var leaderboardType: String = "global"
    @Published var clanNameInput: String = ""
    @Published var clanDescriptionInput: String = ""
    @Published var clanEmblemInput: String = "shield.fill"
    @Published var leaderboardPlayers: [Character] = []
    @Published var showWarResults: ClanWarResult? = nil
    
    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Bind to FirebaseService clan states
        firebaseService.$userClan
            .receive(on: DispatchQueue.main)
            .assign(to: &$userClan)
            
        // Bind to FirebaseService leaderboards
        firebaseService.$leaderboards
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dict in
                guard let self = self else { return }
                self.leaderboardPlayers = dict[self.leaderboardType] ?? []
            }
            .store(in: &cancellables)
            
        $leaderboardType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lType in
                guard let self = self else { return }
                // Show cached data immediately if available
                self.leaderboardPlayers = self.firebaseService.leaderboards[lType] ?? []
                // Fetch fresh data from server for this type
                self.firebaseService.fetchLeaderboards(for: [lType])
            }
            .store(in: &cancellables)
        fetchClans()
    }
    
    func createClan() {
        let cleanName = clanNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDesc = clanDescriptionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        let desc = cleanDesc.isEmpty ? "A standard clan for RPG fitness enthusiasts." : cleanDesc
        firebaseService.createClan(name: cleanName, description: desc, emblem: clanEmblemInput)
        
        clanNameInput = ""
        clanDescriptionInput = ""
        clanEmblemInput = "shield.fill"
    }
    
    func joinClan(_ clan: Clan) {
        firebaseService.joinClan(clan)
    }
    func kickMember(memberId: String) {
        firebaseService.kickMember(memberId: memberId)
    }
    
    func disbandClan() {
        firebaseService.disbandClan()
    }
    
    func leaveClan() {
        firebaseService.leaveClan()
    }
    
    func updateClanDescription(description: String) {
        firebaseService.updateClanDescription(description: description)
    }
    
    func changeMemberRole(memberId: String, newRole: ClanRole) {
        firebaseService.changeMemberRole(memberId: memberId, newRole: newRole)
    }
    
    func startWar() {
        firebaseService.startClanWar()
    }
    
    func cancelWarSearch() {
        firebaseService.cancelClanWarSearch()
    }
    
    func contributeWarScore() {
        // Simulate contributing points from exercises
        firebaseService.contributeWarScore(points: 5)
    }
    
    private var clansListener: ListenerRegistration?
    
    func fetchClans() {
        clansListener?.remove()
        clansListener = Firestore.firestore().collection("clans")
            .order(by: "trophies", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else { return }
                let clans = snapshot.documents.compactMap { try? $0.data(as: Clan.self) }
                DispatchQueue.main.async {
                    self.searchResults = clans
                    self.leaderboardClans = clans
                }
            }
    }
    
    private func checkWarEnd() {
        // Handled by Cloud Functions
    }
}
