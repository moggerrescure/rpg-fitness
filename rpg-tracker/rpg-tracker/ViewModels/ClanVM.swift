import Foundation
import Combine

class ClanVM: ObservableObject {
    @Published var userClan: Clan?
    @Published var searchResults: [Clan] = []
    @Published var leaderboardType: String = "global"
    @Published var clanNameInput: String = ""
    @Published var clanDescriptionInput: String = ""
    @Published var clanEmblemInput: String = "shield.fill"
    @Published var leaderboardPlayers: [Character] = []
    
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
                self.leaderboardPlayers = self.firebaseService.leaderboards[lType] ?? []
            }
            .store(in: &cancellables)
            
        loadMockClansToJoin()
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
    
    func contributeWarScore() {
        // Simulate contributing points from exercises
        firebaseService.contributeWarScore(points: 5)
    }
    
    private func loadMockClansToJoin() {
        let member1 = ClanMember(id: "m1", username: "Berserker", level: 14, characterClass: .swordsman, role: .leader)
        let member2 = ClanMember(id: "m2", username: "ElvenArcher", level: 9, characterClass: .archer, role: .officer)
        let mockClan1 = Clan(id: "clan_mock_111", name: "FitWarriors", description: "Only the strongest warriors who do squats every day!", emblem: "flame.fill", leaderId: "m1", members: [member1, member2], trophies: 1500, totalReps: 450)
        
        let member3 = ClanMember(id: "m3", username: "SaintPriest", level: 18, characterClass: .healer, role: .leader)
        let mockClan2 = Clan(id: "clan_mock_222", name: "SolarGuild", description: "Chilled and casual workouts. All classes welcome.", emblem: "bolt.fill", leaderId: "m3", members: [member3], trophies: 2100, totalReps: 890)
        
        self.searchResults = [mockClan1, mockClan2]
    }
}
