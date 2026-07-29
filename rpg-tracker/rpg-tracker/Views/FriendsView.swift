import SwiftUI

struct FriendsView: View {
    @StateObject private var vm = FriendsVM()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var multiplayerService: MultiplayerService
    
    @State private var showTeamLobby = false
    @State private var pendingTeamInviteUids: [String] = []
    @State private var reportTarget: Character? = nil
    @State private var reportFeedback: String? = nil
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
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.45))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(TactileButtonStyle())
                    } else {
                        Color.clear.frame(width: 36, height: 36)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("FRIENDS")
                            .font(.system(.headline, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundStyle(Theme.textPrimary)
                        if !vm.friendRequests.isEmpty {
                            Text("\(vm.friendRequests.count) PENDING")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(Theme.warning)
                                .tracking(0.8)
                        }
                    }
                    
                    Spacer()
                    
                    if let char = firebaseService.currentCharacter {
                        let inviteUrl = URL(string: "rpgfitness://friend?uid=\(char.id)")!
                        ShareLink(
                            item: inviteUrl,
                            subject: Text("FitRPG — Add me!"),
                            message: Text("Add me in FitRPG: rpgfitness://friend?uid=\(char.id)")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.primary)
                                .frame(width: 36, height: 36)
                                .background(Theme.primary.opacity(0.15))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.primary.opacity(0.35), lineWidth: 1))
                        }
                        .accessibilityLabel("Share friend invite link")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                // Search bar — solid panel, not empty glass
                HStack(spacing: 10) {
                    Image(systemName: vm.searchIsLoading ? "arrow.triangle.2.circlepath" : "magnifyingglass")
                        .foregroundStyle(searchFocused ? Theme.primary : Theme.textMuted)
                        .font(.system(size: 14, weight: .bold))
                        .rotationEffect(.degrees(vm.searchIsLoading ? 360 : 0))
                        .animation(vm.searchIsLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.searchIsLoading)
                    
                    TextField("Search by username or ID", text: $vm.searchText)
                        .font(.system(size: 15, design: .default))
                        .foregroundStyle(Theme.textPrimary)
                        .focused($searchFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !vm.searchText.isEmpty {
                        Button { vm.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Theme.cardBackground.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(searchFocused ? Theme.primary.opacity(0.55) : Theme.border, lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                if vm.isLoading && vm.friends.isEmpty && vm.friendRequests.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(Theme.primary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if !vm.searchText.isEmpty {
                                searchResultsSection
                            } else {
                                if !vm.friendRequests.isEmpty {
                                    requestsSection
                                }
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
        .sheet(item: $reportTarget) { target in
            ReportUserSheet(
                targetUsername: target.username,
                onSubmit: { reason in
                    firebaseService.submitUserReport(targetUid: target.id, reason: reason) { success, error in
                        reportFeedback = success ? "Report submitted. Thank you." : (error ?? "Could not submit report.")
                    }
                }
            )
        }
        .overlay(alignment: .bottom) {
            if let reportFeedback {
                Text(reportFeedback)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            if self.reportFeedback == reportFeedback { self.reportFeedback = nil }
                        }
                    }
            }
        }
        .onChange(of: multiplayerService.activeBattle) { _, battle in
            if battle != nil { dismiss() }
        }
    }
    
    // MARK: - Search Results Section
    @ViewBuilder
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SEARCH RESULTS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
                    .tracking(1.5)
                Spacer()
                if !vm.searchResults.isEmpty {
                    Text("\(vm.searchResults.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            if vm.searchText.count < 2 {
                Text("Type at least 2 characters to search")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if vm.searchIsLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if vm.searchResults.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "person.slash")
                        .font(.title2)
                        .foregroundStyle(Theme.textMuted.opacity(0.5))
                    Text("No players found for \"\(vm.searchText)\"")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
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
        VStack(alignment: .leading, spacing: 8) {
            Label("FRIEND REQUESTS", systemImage: "bell.badge.fill")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.warning)
                .tracking(1.5)
            
            ForEach(vm.friendRequests) { req in
                friendRequestRow(char: req)
            }
        }
    }
    
    // MARK: - Friends List Section
    @ViewBuilder
    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MY SQUAD")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
                    .tracking(1.5)
                Spacer()
                Text("\(vm.friends.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.secondaryCard)
                    .clipShape(Capsule())
            }
            
            if vm.friends.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.textMuted.opacity(0.45))
                    Text("No allies yet")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Search for players to send friend requests.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 12)
                .background(Theme.cardBackground.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            } else {
                ForEach(vm.friends) { friend in
                    friendRow(char: friend)
                }
            }
        }
    }
    
    // MARK: - Avatar
    @ViewBuilder
    private func friendAvatar(char: Character, size: CGFloat = 44) -> some View {
        let accent = char.selectedClass.themeColor
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.35), Theme.secondaryCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            if let avatar = char.avatarName, let uiImage = loadLocalAvatar(named: avatar) {
                Image(platformImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - 4, height: size - 4)
                    .clipShape(Circle())
            } else {
                let emblem = AvatarEmblem.all.first { $0.id == char.avatarName }
                let tint = emblem?.tint ?? accent
                Image(systemName: emblem?.symbol ?? classIcon(for: char.selectedClass))
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(tint)
                    .glow(color: tint.opacity(0.45), radius: 4)
            }
        }
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
    
    private func classIcon(for c: CharacterClass) -> String {
        switch c {
        case .archer:    return "arrow.up.right.circle.fill"
        case .mage:      return "wand.and.stars"
        case .swordsman: return "shield.fill"
        case .healer:    return "cross.case.fill"
        }
    }
    
    // MARK: - Dense card chrome
    private func denseFriendCard<Content: View>(
        accent: Color = Theme.border,
        accentStrength: Double = 0.0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.cardBackground.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accent.opacity(max(0.35, accentStrength)),
                                Theme.border
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
    
    // MARK: - Search Result Row
    @ViewBuilder
    private func searchResultRow(player: Character) -> some View {
        let alreadyFriend = vm.isFriend(player.id)
        let pending = vm.hasPendingRequest(to: player.id)
        let incomingReq = vm.isIncomingRequest(from: player.id)
        
        denseFriendCard(accent: player.selectedClass.themeColor, accentStrength: 0.25) {
            HStack(spacing: 10) {
                friendAvatar(char: player, size: 42)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.username)
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("Lv.\(player.level) · \(player.selectedClass.rawValue)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(player.selectedClass.themeColor)
                }
                
                Spacer(minLength: 4)
                
                Menu {
                    if !alreadyFriend {
                        Button { vm.sendFriendRequest(to: player.id) } label: {
                            Label("Add Friend", systemImage: "person.badge.plus")
                        }
                    }
                    Button(role: .destructive) {
                        firebaseService.blockUser(uid: player.id)
                        reportFeedback = "Player blocked."
                        if let char = firebaseService.currentCharacter {
                            vm.fetchData(for: char)
                        }
                        vm.searchResults.removeAll { $0.id == player.id }
                    } label: {
                        Label("Block", systemImage: "hand.raised.fill")
                    }
                    Button(role: .destructive) { reportTarget = player } label: {
                        Label("Report", systemImage: "exclamationmark.bubble")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 28, height: 28)
                        .background(Theme.secondaryCard)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if incomingReq {
                    Button { vm.acceptRequest(from: player.id) } label: {
                        Text("ACCEPT")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Theme.success)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(TactileButtonStyle())
                } else if alreadyFriend {
                    Text("ALLY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Theme.success.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if pending {
                    Text("SENT")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Theme.warning.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Button { vm.sendFriendRequest(to: player.id) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("ADD")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(TactileButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Friend Request Row
    @ViewBuilder
    private func friendRequestRow(char: Character) -> some View {
        denseFriendCard(accent: Theme.warning, accentStrength: 0.45) {
            HStack(spacing: 10) {
                friendAvatar(char: char, size: 42)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(char.username)
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("Lv.\(char.level) · \(char.selectedClass.rawValue)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(char.selectedClass.themeColor)
                }
                
                Spacer(minLength: 4)
                
                HStack(spacing: 8) {
                    Button(action: { vm.acceptRequest(from: char.id) }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Theme.success)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(TactileButtonStyle())
                    
                    Button(action: { vm.declineRequest(from: char.id) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Theme.secondaryCard)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(TactileButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Friend Row
    @ViewBuilder
    private func friendRow(char: Character) -> some View {
        denseFriendCard(accent: char.selectedClass.themeColor, accentStrength: 0.3) {
            HStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    friendAvatar(char: char, size: 46)
                    Circle()
                        .fill(Theme.success)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Theme.cardBackground, lineWidth: 2))
                        .offset(x: 1, y: 1)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(char.username)
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("Lv.\(char.level) · \(char.selectedClass.rawValue)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(char.selectedClass.themeColor)
                }
                
                Spacer(minLength: 4)
                
                HStack(spacing: 6) {
                    // 1v1 Duel
                    Button {
                        MultiplayerService.shared.challengeFriend(friendUid: char.id)
                        dismiss()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("DUEL")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .tracking(0.5)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 40)
                        .background(
                            LinearGradient(
                                colors: [Theme.warning, Theme.warning.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(TactileButtonStyle())
                    .accessibilityLabel("Challenge to duel")
                    
                    // 3v3 Invite
                    Button {
                        pendingTeamInviteUids = [char.id]
                        MultiplayerService.shared.initTeamLobby()
                        MultiplayerService.shared.sendTeamInvite(uid: char.id)
                        showTeamLobby = true
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("3v3")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .tracking(0.5)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 40)
                        .background(
                            LinearGradient(
                                colors: [Theme.primary, Theme.primary.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(TactileButtonStyle())
                    .accessibilityLabel("Invite to 3v3 team")

                    Menu {
                        Button(role: .destructive) {
                            firebaseService.blockUser(uid: char.id)
                            reportFeedback = "Player blocked."
                            if let me = firebaseService.currentCharacter {
                                vm.fetchData(for: me)
                            }
                        } label: {
                            Label("Block", systemImage: "hand.raised.fill")
                        }
                        Button(role: .destructive) { reportTarget = char } label: {
                            Label("Report", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textMuted)
                            .frame(width: 32, height: 40)
                            .background(Theme.secondaryCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("More actions")
                }
            }
        }
    }
}

private struct ReportUserSheet: View {
    let targetUsername: String
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = "harassment"
    @State private var details = ""

    private let reasons: [(id: String, label: String)] = [
        ("harassment", "Harassment"),
        ("spam", "Spam"),
        ("hate", "Hate speech"),
        ("sexual", "Sexual content"),
        ("violence", "Violence"),
        ("other", "Other")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Report \(targetUsername)")
                        .font(.headline)
                }
                Section("Reason") {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(reasons, id: \.id) { reason in
                            Text(reason.label).tag(reason.id)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section("Details (optional)") {
                    TextField("What happened?", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Report Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        var reason = selectedReason
                        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            reason += ": \(trimmed)"
                        }
                        onSubmit(reason)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
