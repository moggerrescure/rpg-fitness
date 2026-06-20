import Foundation
import Combine
import SwiftUI

@MainActor
class FriendsVM: ObservableObject {
    @Published var friends: [Character] = []
    @Published var friendRequests: [Character] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        FirebaseService.shared.$currentCharacter
            .receive(on: DispatchQueue.main)
            .sink { [weak self] char in
                guard let self = self, let char = char else { return }
                self.fetchData(for: char)
            }
            .store(in: &cancellables)
    }
    
    func fetchData(for char: Character) {
        isLoading = true
        Task {
            let fetchedFriends = await FirebaseService.shared.fetchCharacters(byUids: char.friends)
            let fetchedRequests = await FirebaseService.shared.fetchCharacters(byUids: char.friendRequests)
            
            await MainActor.run {
                self.friends = fetchedFriends
                self.friendRequests = fetchedRequests
                self.isLoading = false
            }
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
}
