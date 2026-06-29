import SwiftUI

struct ClanSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ClanVM
    let clan: Clan
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("CLAN SETTINGS")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.black)
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Members List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MANAGE MEMBERS")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal)
                            
                            ForEach(clan.members) { member in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.username)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.textPrimary)
                                        Text("Lvl \(member.level) • \(member.characterClass.rawValue)")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if member.role == .leader {
                                        Text("Leader")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.accent)
                                    } else {
                                        Button(action: {
                                            viewModel.kickMember(memberId: member.id)
                                        }) {
                                            Text("KICK")
                                                .font(.system(.caption, design: .monospaced))
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Theme.danger)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                        
                        // Danger Zone
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DANGER ZONE")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Theme.danger)
                                .padding(.horizontal)
                            
                            Button(action: {
                                viewModel.disbandClan()
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "xmark.bin.fill")
                                    Text("DISBAND CLAN")
                                }
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.danger)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
