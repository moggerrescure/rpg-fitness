import SwiftUI

struct FriendsView: View {
    @StateObject private var vm = FriendsVM()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var multiplayerService: MultiplayerService
    
    @State private var showTeamLobby = false
    @State private var pendingTeamInviteUids: [String] = []
    @FocusState private var searchFocused: Bool
    
    var isEmbedded: Bool = false
    
    var body: some View {
        ZStack {
            if !isEmbedded {
                AnimatedBackgroundView(backgroundType: .tavern)
                Color.black.opacity(0.45).ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    if !isEmbedded {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3.bold())
                                .foregroundStyle(Theme.textPrimary)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    } else {
                        // Spacer to keep layout balanced
                        Color.clear.frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("FRIENDS")
                            .font(.system(.headline, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundStyle(Theme.textPrimary)
                        if !vm.friendRequests.isEmpty {
                            Text("\(vm.friendRequests.count) request\(vm.friendRequests.count > 1 ? "s" : "")")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.warning)
                        }
                    }
                    
                    Spacer()
                    
                    // Share invite link
                    if let char = firebaseService.currentCharacter {
                        let inviteUrl = URL(string: "rpgfitness://friend?uid=\(char.id)")!
                        ShareLink(
                            item: inviteUrl,
                            subject: Text("RPG Fitness — Add me!"),
                            message: Text("Tap to add me as a friend in RPG Fitness!")
                        ) {
                            Image(systemName: "person.badge.plus")
                                .font(.title3.bold())
                                .foregroundStyle(Theme.primary)
                                .padding(12)
                                .background(Theme.primary.opacity(0.12))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: vm.searchIsLoading ? "arrow.triangle.2.circlepath" : "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                        .font(.body.bold())
                        .rotationEffect(.degrees(vm.searchIsLoading ? 360 : 0))
                        .animation(vm.searchIsLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.searchIsLoading)
                    
                    TextField("Search by username or ID", text: $vm.searchText)
                        .font(.system(.body, design: .default))
                        .foregroundStyle(Theme.textPrimary)
                        .focused($searchFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !vm.searchText.isEmpty {
                        Button { vm.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(searchFocused ? Theme.primary.opacity(0.5) : Theme.border, lineWidth: 1.5)
                )
                .padding(.horizontal)
                .padding(.bottom, 12)
                
                // Content
                if vm.isLoading && vm.friends.isEmpty && vm.friendRequests.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(Theme.primary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            // Search results
                            if !vm.searchText.isEmpty {
                                searchResultsSection
                            } else {
                                // Friend requests
                                if !vm.friendRequests.isEmpty {
                                    requestsSection
                                }
                                
                                // Friends list
                                friendsListSection
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .sheet(isPresented: $showTeamLobby) {
            TeamLobbyView(onBattleStarted: { dismiss() })
                .environmentObject(multiplayerService)
                .environmentObject(firebaseService)
        }
        .onChange(of: multiplayerService.activeBattle) { _, battle in
            if battle != nil { dismiss() }
        }
    }
    
    // MARK: - Search Results Section
    @ViewBuilder
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SEARCH RESULTS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(2)
                Spacer()
                if !vm.searchResults.isEmpty {
                    Text("\(vm.searchResults.count) found")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            if vm.searchText.count < 2 {
                Text("Type at least 2 characters to search")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            } else if vm.searchIsLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.top, 20)
            } else if vm.searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.textSecondary.opacity(0.4))
                    Text("No players found for \"\(vm.searchText)\"")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            } else {
                ForEach(vm.searchResults) { player in
                    searchResultRow(player: player)
                }
            }
        }
    }
    
    // MARK: - Friend Requests Section
    @ViewBuilder
    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("FRIEND REQUESTS", systemImage: "bell.badge.fill")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.warning)
                .tracking(2)
            
            ForEach(vm.friendRequests) { req in
                friendRequestRow(char: req)
            }
        }
    }
    
    // MARK: - Friends List Section
    @ViewBuilder
    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MY SQUAD (\(vm.friends.count))")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(2)
                Spacer()
            }
            
            if vm.friends.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.textSecondary.opacity(0.3))
                    Text("No allies yet.")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary.opacity(0.5))
                    Text("Search for players to send friend requests!")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(vm.friends) { friend in
                    friendRow(char: friend)
                }
            }
        }
    }
    
    // MARK: - Search Result Row
    @ViewBuilder
    private func searchResultRow(player: Character) -> some View {
        let alreadyFriend = vm.isFriend(player.id)
        let pending = vm.hasPendingRequest(to: player.id)
        let incomingReq = vm.isIncomingRequest(from: player.id)
        
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(player.selectedClass.themeColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundStyle(player.selectedClass.themeColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(player.username)
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 6) {
                    Text("Lv. \(player.level)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Text("•")
                        .foregroundStyle(Theme.textSecondary.opacity(0.4))
                    Text(player.selectedClass.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(player.selectedClass.themeColor)
                }
            }
            
            Spacer()
            
            // Action button
            if incomingReq {
                Button { vm.acceptRequest(from: player.id) } label: {
                    Label("Accept", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.green)
                        .clipShape(Capsule())
                }
            } else if alreadyFriend {
                Label("Friends", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
            } else if pending {
                Label("Pending", systemImage: "clock")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.warning)
            } else {
                Button { vm.sendFriendRequest(to: player.id) } label: {
                    Label("Add", systemImage: "person.badge.plus")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(TactileButtonStyle())
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
    
    // MARK: - Friend Request Row
    @ViewBuilder
    private func friendRequestRow(char: Character) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(char.selectedClass.themeColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundStyle(char.selectedClass.themeColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(char.username)
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)
                Text("Lv. \(char.level) • \(char.selectedClass.rawValue)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(char.selectedClass.themeColor)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button(action: { vm.acceptRequest(from: char.id) }) {
                    Image(systemName: "checkmark")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .padding(11)
                        .background(.green)
                        .clipShape(Circle())
                }
                .buttonStyle(TactileButtonStyle())
                
                Button(action: { vm.declineRequest(from: char.id) }) {
                    Image(systemName: "xmark")
                        .font(.body.bold())
                        .foregroundStyle(Theme.textSecondary)
                        .padding(11)
                        .background(Theme.cardBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(TactileButtonStyle())
            }
        }
        .padding(14)
        .background(
            ZStack {
                Theme.warning.opacity(0.06)
            }
            .background(.thinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.warning.opacity(0.3), lineWidth: 1.5)
        )
    }
    
    // MARK: - Friend Row
    @ViewBuilder
    private func friendRow(char: Character) -> some View {
        HStack(spacing: 14) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(char.selectedClass.themeColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(char.selectedClass.themeColor)
                }
                // Online dot (always show as online for now — can add presence later)
                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Theme.background, lineWidth: 2))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(char.username)
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 4) {
                    Text("Lv. \(char.level)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Text("•")
                        .foregroundStyle(Theme.textSecondary.opacity(0.4))
                    Text(char.selectedClass.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(char.selectedClass.themeColor)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 10) {
                // 1v1 Duel
                Button {
                    MultiplayerService.shared.challengeFriend(friendUid: char.id)
                    dismiss()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.caption.bold())
                        Text("1v1")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Theme.warning)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(TactileButtonStyle())
                
                // 3v3 Invite
                Button {
                    pendingTeamInviteUids = [char.id]
                    MultiplayerService.shared.initTeamLobby()
                    MultiplayerService.shared.sendTeamInvite(uid: char.id)
                    showTeamLobby = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "person.3.fill")
                            .font(.caption.bold())
                        Text("3v3")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(TactileButtonStyle())
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}
