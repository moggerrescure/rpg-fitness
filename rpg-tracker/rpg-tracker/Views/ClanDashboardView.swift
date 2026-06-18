import SwiftUI

struct ClanDashboardView: View {
    @StateObject private var viewModel = ClanVM()
    @State private var selectedTab = 0 // 0: My Clan, 1: Leaderboards
    
    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Segment Bar
                Picker("Tabs", selection: $selectedTab) {
                    Text("CLAN SOCIAL").tag(0)
                    Text("LEADERBOARDS").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                if selectedTab == 0 {
                    ScrollView {
                        if let clan = viewModel.userClan {
                            ActiveClanView(clan: clan, viewModel: viewModel)
                        } else {
                            NoClanView(viewModel: viewModel)
                        }
                    }
                } else {
                    LeaderboardListView(viewModel: viewModel)
                }
            }
        }
        .hideNavigationBar()
    }
}

// 1. View when player doesn't belong to any clan
struct NoClanView: View {
    @ObservedObject var viewModel: ClanVM
    @State private var showCreateClanSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Big Banner and Create Button
            VStack(spacing: 16) {
                ClanEmblemView(emblem: "shield.fill", size: 80)
                .padding(.top, 10)
                
                Text("YOU ARE NOT IN A CLAN")
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.black)
                    .foregroundColor(Theme.textPrimary)
                    .tracking(1.5)
                
                Text("Form or join a clan with other players to contribute reps, engage in epic wars, and conquer standings together.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal)
                
                Button(action: {
                    showCreateClanSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.shield.fill")
                        Text("CREATE A NEW CLAN")
                            .fontWeight(.bold)
                    }
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Theme.primary.opacity(0.35), radius: 8, y: 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .glassmorphicCard()
            .padding(.horizontal)
            .padding(.top, 16)
            .sheet(isPresented: $showCreateClanSheet) {
                CreateClanSheetView(viewModel: viewModel)
            }
            
            // Join Clan Section (Recommended clans list)
            VStack(alignment: .leading, spacing: 16) {
                Text("RECOMMENDED CLANS")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal)
                
                ForEach(viewModel.searchResults) { clan in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ClanEmblemView(emblem: clan.emblem, size: 44)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(clan.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text(clan.description)
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: { viewModel.joinClan(clan) }) {
                                Text("JOIN")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Theme.primary.opacity(0.15))
                                    .foregroundColor(Theme.primary)
                                    .cornerRadius(8)
                            }
                        }
                        
                        Divider()
                            .background(Theme.border)
                        
                        HStack(spacing: 16) {
                            Label("\(clan.members.count)/3 members", systemImage: "person.3.fill")
                            Spacer()
                            Label("\(clan.trophies)", systemImage: "trophy.fill")
                                .foregroundColor(Theme.healerColor)
                        }
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
}

// Popup to configure and establish a clan
struct CreateClanSheetView: View {
    @ObservedObject var viewModel: ClanVM
    @Environment(\.dismiss) private var dismiss
    
    let emblems = [
        "shield.fill", "flame.fill", "bolt.fill", "crown.fill",
        "leaf.fill", "drop.fill", "heart.fill", "wand.and.stars"
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Text("FOUND A NEW CLAN")
                .font(.system(.headline, design: .monospaced))
                .fontWeight(.black)
                .foregroundColor(Theme.textPrimary)
                .tracking(1.5)
                .padding(.top, 24)
            
            // Name Input
            VStack(alignment: .leading, spacing: 8) {
                Text("CLAN NAME")
                    .font(.system(size: 10, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textSecondary)
                
                TextField("Enter clan name...", text: $viewModel.clanNameInput)
                    .padding()
                    .background(Theme.secondaryCard)
                    .cornerRadius(10)
                    .foregroundColor(Theme.textPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            
            // Description Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CLAN DESCRIPTION")
                        .font(.system(size: 10, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(viewModel.clanDescriptionInput.count)/150")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(viewModel.clanDescriptionInput.count > 150 ? Theme.danger : Theme.textMuted)
                }
                
                ZStack(alignment: .topLeading) {
                    if viewModel.clanDescriptionInput.isEmpty {
                        Text("Describe your clan's goals, requirements, and style...")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: Binding(
                        get: { viewModel.clanDescriptionInput },
                        set: { if $0.count <= 150 { viewModel.clanDescriptionInput = $0 } }
                    ))
                    .font(.caption)
                    .foregroundColor(Theme.textPrimary)
                    .padding(8)
                    .frame(height: 72)
                    .scrollContentBackground(.hidden)
                    .background(Theme.secondaryCard)
                    .cornerRadius(10)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
            .padding(.horizontal)
            
            // Emblem Selection Grid
            VStack(alignment: .leading, spacing: 12) {
                Text("SELECT CLAN EMBLEM")
                    .font(.system(size: 10, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(emblems, id: \.self) { emblem in
                        let isSelected = viewModel.clanEmblemInput == emblem
                        Button(action: {
                            viewModel.clanEmblemInput = emblem
                        }) {
                            ClanEmblemView(emblem: emblem, size: 54, isSelected: isSelected)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    viewModel.createClan()
                    dismiss()
                }) {
                    Text("ESTABLISH CLAN")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(viewModel.clanNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(viewModel.clanNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                
                Button("CANCEL") {
                    dismiss()
                }
                .font(.caption)
                .foregroundColor(Theme.danger)
                .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

// 2. Active clan home panel
struct ActiveClanView: View {
    let clan: Clan
    @ObservedObject var viewModel: ClanVM
    @State private var isEditingDescription: Bool = false
    @State private var editedDescription: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Clan Overview Card
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ClanEmblemView(emblem: clan.emblem, size: 56)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(clan.name.uppercased())
                            .font(.title3)
                            .fontWeight(.black)
                            .foregroundColor(Theme.textPrimary)
                            .tracking(1.5)
                        
                        Text("ID: \(clan.id)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    Label("\(clan.trophies)", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundColor(Theme.healerColor)
                }
                
                // Description: Editable only by Leader
                if isEditingDescription {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("EDIT CLAN DESCRIPTION")
                                .font(.system(size: 9, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(editedDescription.count)/150")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(editedDescription.count > 150 ? Theme.danger : Theme.textMuted)
                        }
                        
                        ZStack(alignment: .topLeading) {
                            if editedDescription.isEmpty {
                                Text("Enter clan description...")
                                    .font(.caption)
                                    .foregroundColor(Theme.textMuted)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: Binding(
                                get: { editedDescription },
                                set: { if $0.count <= 150 { editedDescription = $0 } }
                            ))
                            .font(.caption)
                            .foregroundColor(Theme.textPrimary)
                            .padding(8)
                            .frame(height: 72)
                            .scrollContentBackground(.hidden)
                            .background(Theme.secondaryCard)
                            .cornerRadius(8)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                let clean = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !clean.isEmpty {
                                    viewModel.updateClanDescription(description: clean)
                                }
                                isEditingDescription = false
                            }) {
                                Text("SAVE")
                                    .font(.system(size: 10, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Theme.success)
                                    .cornerRadius(6)
                            }
                            
                            Button(action: {
                                isEditingDescription = false
                            }) {
                                Text("CANCEL")
                                    .font(.system(size: 10, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Theme.danger)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack(alignment: .top) {
                        Text(clan.description)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                        
                        Spacer()
                        
                        // Edit icon ONLY visible to the Leader
                        if clan.leaderId == FirebaseService.shared.currentCharacter?.id {
                            Button(action: {
                                editedDescription = clan.description
                                isEditingDescription = true
                            }) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(Theme.primary)
                                    .padding(6)
                                    .background(Theme.secondaryCard)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                
                HStack {
                    Spacer()
                    // Leave / Disband Clan button
                    Button(action: {
                        viewModel.leaveClan()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text(clan.leaderId == FirebaseService.shared.currentCharacter?.id ? "DISBAND CLAN" : "LEAVE CLAN")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.danger.opacity(0.85))
                        .cornerRadius(8)
                    }
                }
                
                Divider()
                    .background(Theme.border)
                
                // Member Contribution List
                VStack(alignment: .leading, spacing: 12) {
                    Text("CLAN MEMBERS (\(clan.members.count)/3)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textSecondary)
                    
                    ForEach(clan.members) { member in
                        HStack {
                            Circle()
                                .fill(member.characterClass.themeColor.opacity(0.15))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                        .foregroundColor(member.characterClass.themeColor)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.username)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.textPrimary)
                                Text("Lvl \(member.level) • \(member.characterClass.rawValue)")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(member.repsContributed) Reps")
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.textPrimary)
                                
                                HStack(spacing: 4) {
                                    Text(member.role.rawValue)
                                        .font(.system(size: 8))
                                        .foregroundColor(Theme.textMuted)
                                    
                                    // Ranks administration: Leader-only promotion menu
                                    if clan.leaderId == FirebaseService.shared.currentCharacter?.id && member.id != FirebaseService.shared.currentCharacter?.id {
                                        Menu {
                                            Button("Transfer Leadership") {
                                                viewModel.changeMemberRole(memberId: member.id, newRole: .leader)
                                            }
                                            Button("Set Officer Rank") {
                                                viewModel.changeMemberRole(memberId: member.id, newRole: .officer)
                                            }
                                            Button("Set Member Rank") {
                                                viewModel.changeMemberRole(memberId: member.id, newRole: .member)
                                            }
                                        } label: {
                                            Image(systemName: "arrow.up.and.down.circle.fill")
                                                .foregroundColor(Theme.primary)
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(Theme.secondaryCard)
                        .cornerRadius(8)
                    }
                }
            }
            .glassmorphicCard()
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Clan War panel
            VStack(alignment: .leading, spacing: 16) {
                Text("CLAN WARS")
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                
                if let war = clan.activeWar {
                    VStack(spacing: 12) {
                        HStack {
                            Text(clan.name)
                                .fontWeight(.bold)
                            Spacer()
                            Text("VS")
                                .font(.caption)
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            Text(war.opponentClanName)
                                .fontWeight(.bold)
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                        
                        // Score bar comparison
                        HStack(spacing: 16) {
                            Text("\(war.myClanScore)")
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(Theme.primary)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Theme.danger.opacity(0.8))
                                    
                                    let total = max(1, war.myClanScore + war.opponentClanScore)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Theme.primary)
                                        .frame(width: CGFloat(war.myClanScore) / CGFloat(total) * geo.size.width)
                                }
                            }
                            .frame(height: 12)
                            
                            Text("\(war.opponentClanScore)")
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(Theme.danger)
                        }
                        
                        HStack {
                            Label("Ends in: 23 hours", systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            
                            Button(action: viewModel.contributeWarScore) {
                                Text("+ Contribute (Sim)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.success)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 16) {
                        Text("No active Clan War right now.")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        Button(action: viewModel.startWar) {
                            Text("INITIATE CLAN WAR")
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Theme.accent)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }
}

// 3. Leaderboards View list
struct LeaderboardListView: View {
    @ObservedObject var viewModel: ClanVM
    
    var body: some View {
        VStack(spacing: 12) {
            // Horizontal Class Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    LeaderboardTabBtn(title: "Global Standings", id: "global", activeId: viewModel.leaderboardType) {
                        viewModel.leaderboardType = "global"
                    }
                    
                    ForEach(CharacterClass.allCases) { cls in
                        LeaderboardTabBtn(title: cls.rawValue, id: cls.rawValue, activeId: viewModel.leaderboardType) {
                            viewModel.leaderboardType = cls.rawValue
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)
            
            // List of Players
            ScrollView {
                VStack(spacing: 8) {
                    if viewModel.leaderboardPlayers.isEmpty {
                        Text("Searching rank updates...")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                            .padding(.top, 40)
                    } else {
                        ForEach(Array(viewModel.leaderboardPlayers.enumerated()), id: \.offset) { index, player in
                            HStack(spacing: 12) {
                                // Rank Badge
                                RankIndicator(rank: index + 1)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.username)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.textPrimary)
                                    Text(player.selectedClass.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(player.selectedClass.themeColor)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Lvl \(player.level)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text("\(player.stats.totalReps) total reps")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.border, lineWidth: 0.5)
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct LeaderboardTabBtn: View {
    let title: String
    let id: String
    let activeId: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(id == activeId ? Theme.primary : Theme.cardBackground)
                .foregroundColor(id == activeId ? .white : Theme.textSecondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(id == activeId ? Color.clear : Theme.border, lineWidth: 1)
                )
        }
    }
}

struct RankIndicator: View {
    let rank: Int
    
    var body: some View {
        ZStack {
            if rank <= 3 {
                Circle()
                    .fill(rankColor(for: rank))
                    .frame(width: 28, height: 28)
                
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundColor(rank == 1 ? Color.black : Color.white)
            } else {
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 28, height: 28)
            }
        }
    }
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Theme.warning // Gold
        case 2: return Color.gray // Silver
        case 3: return Color(hex: "CD7F32") // Bronze
        default: return Color.clear
        }
    }
}
struct ClanDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        ClanDashboardView()
    }
}
