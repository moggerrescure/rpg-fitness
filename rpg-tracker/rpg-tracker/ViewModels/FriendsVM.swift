import Foundation
import Combine
import SwiftUI

@MainActor
class FriendsVM: ObservableObject {
    @Published var friends: [Character] = []
    @Published var friendRequests: [Character] = []
    @Published var searchResults: [Character] = []
    @Published var isLoading = false
    @Published var searchIsLoading = false
    @Published var pendingRequestUids: Set<String> = []
    @Published var searchText: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    
    init() {
        FirebaseService.shared.$currentCharacter
            .receive(on: DispatchQueue.main)
            .sink { [weak self] char in
                guard let self = self, let char = char else { return }
                self.fetchData(for: char)
            }
            .store(in: &cancellables)
        
        // Debounced search
        $searchText
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    func fetchData(for char: Character) {
        isLoading = true
        Task {
            let fetchedFriends = await FirebaseService.shared.fetchCharacters(byUids: char.unwrappedFriends)
            let fetchedRequests = await FirebaseService.shared.fetchCharacters(byUids: char.unwrappedFriendRequests)
            
            await MainActor.run {
                self.friends = fetchedFriends
                self.friendRequests = fetchedRequests
                self.isLoading = false
            }
        }
    }
    
    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        searchTask?.cancel()
        searchTask = Task {
            await MainActor.run { self.searchIsLoading = true }
            let results = await FirebaseService.shared.searchPlayers(query: trimmed)
            guard !Task.isCancelled else { return }
            let myId = FirebaseService.shared.currentCharacter?.id ?? ""
            await MainActor.run {
                self.searchResults = results.filter { $0.id != myId }
                self.searchIsLoading = false
            }
        }
    }
    
    func sendFriendRequest(to uid: String) {
        pendingRequestUids.insert(uid)
        Task {
            await FirebaseService.shared.sendFriendRequest(to: uid)
        }
    }
    
    func acceptRequest(from uid: String) {
        Task {
            await FirebaseService.shared.acceptFriendRequest(from: uid)
        }
    }
    
    func declineRequest(from uid: String) {
        FirebaseService.shared.declineFriendRequest(from: uid)
    }
    
    func isFriend(_ uid: String) -> Bool {
        friends.contains(where: { $0.id == uid })
    }
    
    func hasPendingRequest(to uid: String) -> Bool {
        pendingRequestUids.contains(uid)
    }
    
    func isIncomingRequest(from uid: String) -> Bool {
        friendRequests.contains(where: { $0.id == uid })
    }
}
