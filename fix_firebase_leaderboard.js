const fs = require('fs');
let code = fs.readFileSync('rpg-tracker/rpg-tracker/Services/FirebaseService.swift', 'utf8');

// 1. Remove hardcoded friends and loadMockLeaderboards
code = code.replace(
    `@Published var friends: [String] = ["AquaHealer", "FireMage", "WindArcher", "KnightDave"]`,
    `@Published var friends: [String] = []`
);

code = code.replace(
    `        loadMockLeaderboards()`,
    `        fetchLeaderboards()`
);

// 2. Replace loadMockLeaderboards function with fetchLeaderboards
const mockLeaderboardTarget = `    // MARK: - Leaderboard Fetch
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
            
            let char = Character(
                id: "mock_user_\\(i)",
                username: "\\(names.randomElement() ?? "Hero")\\(Int.random(in: 10...99))",
                selectedClass: cls,
                level: level,
                xp: 0,
                gold: Int.random(in: 100...5000),
                stats: mockStats
            )
            var mutatingChar = char
            mutatingChar.pvpWins = pvpWins
            mutatingChar.pvpTrophies = pvpTrophies
            players.append(mutatingChar)
        }
        
        // Sort by level/reps to mock global standings
        let sorted = players.sorted { $0.level > $1.level }
        
        self.leaderboards = [
            "global": sorted,
            "friends": Array(sorted.prefix(5))
        ]
    }`;

const fetchLeaderboardReplace = `    // MARK: - Leaderboard Fetch
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
                    // For friends, we just filter the global list for now since we don't have full social graph
                    self.leaderboards["friends"] = players.filter { self.friends.contains($0.username) }
                }
            }
    }`;

code = code.replace(mockLeaderboardTarget, fetchLeaderboardReplace);

// 3. Fix awardBattleRewards "mock rep increment" and awardWorkoutRewards local mutation
const battleRewardsTarget = `        // If in clan, contribute reps
        if var clan = userClan, let index = clan.members.firstIndex(where: { $0.id == char.id }) {
            clan.members[index].repsContributed += 10 // Mock rep increment
            clan.totalReps += 10
            userClan = clan
        }`;
const battleRewardsReplace = `        // If in clan, contribute reps via increment to avoid overwriting
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
        }`;
code = code.replace(battleRewardsTarget, battleRewardsReplace);

const workoutRewardsTarget = `        // If in a clan, contribute these reps to the member contribution & total clan reps
        if reps > 0, var clan = userClan, let index = clan.members.firstIndex(where: { $0.id == char.id }) {
            clan.members[index].repsContributed += reps
            clan.totalReps += reps
            userClan = clan
        }`;
const workoutRewardsReplace = `        // If in a clan, contribute these reps to the member contribution & total clan reps
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
        }`;
code = code.replace(workoutRewardsTarget, workoutRewardsReplace);

fs.writeFileSync('rpg-tracker/rpg-tracker/Services/FirebaseService.swift', code);
console.log("Fixed Leaderboards and Clan Reps Increment");
