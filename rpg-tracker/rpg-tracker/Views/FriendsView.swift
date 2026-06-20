import SwiftUI

struct FriendsView: View {
    @StateObject private var vm = FriendsVM()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firebaseService: FirebaseService
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3.bold())
                            .foregroundColor(Theme.textPrimary)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Friends")
                        .font(.title2.bold())
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Image(systemName: "xmark").opacity(0).padding(12)
                }
                .padding(.horizontal)
                
                // Invite Link
                if let char = firebaseService.currentCharacter {
                    let inviteUrl = URL(string: "rpgfitness://friend?uid=\(char.id)")!
                    
                    ShareLink(item: inviteUrl, subject: Text("Add me in RPG Fitness!"), message: Text("Tap this link to add me as a friend in RPG Fitness and let's play 3v3 together!")) {
                        HStack {
                            Image(systemName: "link")
                            Text("Share Invite Link")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [Theme.mageColor, Theme.swordsmanColor], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(15)
                        .shadow(color: Theme.mageColor.opacity(0.3), radius: 10)
                    }
                    .padding(.horizontal)
                }
                
                if vm.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Friend Requests
                            if !vm.friendRequests.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Friend Requests")
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary.opacity(0.7))
                                    
                                    ForEach(vm.friendRequests) { req in
                                        friendRequestRow(char: req)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Friends List
                            VStack(alignment: .leading, spacing: 12) {
                                Text("My Friends (\(vm.friends.count))")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary.opacity(0.7))
                                
                                if vm.friends.isEmpty {
                                    VStack {
                                        Image(systemName: "person.2.slash")
                                            .font(.largeTitle)
                                            .foregroundColor(Theme.textPrimary.opacity(0.3))
                                            .padding(.bottom, 8)
                                        Text("You have no friends yet.")
                                            .foregroundColor(Theme.textPrimary.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                                } else {
                                    ForEach(vm.friends) { friend in
                                        friendRow(char: friend)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func friendRequestRow(char: Character) -> some View {
        HStack {
            Image(char.avatarName ?? "avatar_knight")
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(Circle().stroke(char.selectedClass.themeColor, lineWidth: 2))
            
            VStack(alignment: .leading) {
                Text(char.username)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Text("Lv. \(char.level) \(char.selectedClass.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(char.selectedClass.themeColor)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { vm.acceptRequest(from: char.id) }) {
                    Image(systemName: "checkmark")
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                
                Button(action: { vm.declineRequest(from: char.id) }) {
                    Image(systemName: "xmark")
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Theme.cardBackground)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private func friendRow(char: Character) -> some View {
        HStack {
            Image(char.avatarName ?? "avatar_knight")
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(Circle().stroke(char.selectedClass.themeColor, lineWidth: 2))
            
            VStack(alignment: .leading) {
                Text(char.username)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Text("Lv. \(char.level) \(char.selectedClass.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(char.selectedClass.themeColor)
            }
            
            Spacer()
            
            Button(action: {
                MultiplayerService.shared.challengeFriend(friendUid: char.id)
                dismiss() // Close friends view to see the main hub where combat will start
            }) {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundColor(Theme.warning)
                    .padding(10)
                    .background(Theme.cardBackground)
                    .clipShape(Circle())
                    .shadow(color: Theme.warning.opacity(0.3), radius: 5)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(15)
    }
}
