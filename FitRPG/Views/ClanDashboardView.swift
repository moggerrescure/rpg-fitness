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
        .navigationBarHidden(true)
    }
}

// 1. View when player doesn't belong to any clan
struct NoClanView: View {
    @ObservedObject var viewModel: ClanVM
    
    var body: some View {
        VStack(spacing: 24) {
            // Create Clan Card
            VStack(alignment: .leading, spacing: 16) {
                Text("CREATE A CLAN")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Text("Form a clan with up to 3 players and compete in weekly wars.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                HStack(spacing: 12) {
                    TextField("Clan Name...", text: $viewModel.clanNameInput)
                        .padding()
                        .background(Theme.secondaryCard)
                        .cornerRadius(10)
                        .foregroundColor(Theme.textPrimary)
                    
                    Button(action: viewModel.createClan) {
                        Text("CREATE")
                            .fontWeight(.bold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Theme.primary)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(viewModel.clanNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .glassmorphicCard()
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Join Clan Section
            VStack(alignment: .leading, spacing: 16) {
                Text("RECOMMENDED CLANS")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal)
                
                ForEach(viewModel.searchResults) { clan in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(clan.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)
                            
                            HStack(spacing: 12) {
                                Label("\(clan.members.count)/3", systemImage: "person.3.fill")
                                Label("\(clan.trophies)", systemImage: "trophy.fill")
                                    .foregroundColor(Theme.healerColor)
                            }
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { viewModel.joinClan(clan) }) {
                            Text("JOIN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Theme.secondaryCard)
                                .foregroundColor(Theme.primary)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        }
    }
}

// 2. Active clan home panel
struct ActiveClanView: View {
    let clan: Clan
    @ObservedObject var viewModel: ClanVM
    
    var body: some View {
        VStack(spacing: 20) {
            // Clan Overview Card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(clan.name.uppercased())
                            .font(.title3)
                            .fontWeight(.bold)
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
                                Text(member.role.rawValue)
                                    .font(.system(size: 8))
                                    .foregroundColor(Theme.textMuted)
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
                    .font(.headline)
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
                            Label("End Time Remaining: 23h", systemImage: "clock")
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
