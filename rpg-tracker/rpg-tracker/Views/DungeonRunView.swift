import SwiftUI

struct DungeonRunView: View {
    @StateObject private var viewModel = DungeonVM()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if viewModel.activeBattle != nil {
                CombatArenaView(battle: viewModel.activeBattle!, viewModel: BattleVM()) // We use BattleVM just as a prop, though we could decouple it
                    .overlay(
                        VStack {
                            HStack {
                                Spacer()
                                Text(viewModel.currentState.rawValue.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(8)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            Spacer()
                        }
                    )
            } else {
                VStack(spacing: 24) {
                    if viewModel.currentState == .intro {
                        Text("DUNGEON RUN")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.danger)
                            .glow(color: Theme.danger.opacity(0.5), radius: 10)
                        
                        VStack(spacing: 16) {
                            Text("Survive 3 waves of increasingly difficult enemies.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(Theme.textPrimary)
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Theme.warning)
                                Text("Your health DOES NOT REGENERATE between waves.")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.warning)
                            }
                        }
                        .padding(20)
                        .background(Theme.cardBackground.opacity(0.85))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                        .padding(.horizontal, 24)
                        
                        Button(action: {
                            viewModel.startDungeon()
                        }) {
                            Text("ENTER THE DUNGEON")
                                .font(.headline)
                                .fontWeight(.black)
                                .tracking(1.5)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(colors: [Theme.danger, Color(red: 0.6, green: 0, blue: 0)], startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(color: Theme.danger.opacity(0.5), radius: 8, y: 4)
                        }
                        .padding(.horizontal, 40)
                        
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                        .padding(.top, 8)
                        
                    } else if viewModel.currentState == .wave1Clear || viewModel.currentState == .wave2Clear {
                        Text("WAVE CLEARED")
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.success)
                            .glow(color: Theme.success.opacity(0.5), radius: 10)
                        
                        VStack(spacing: 12) {
                            Text("Current HP: \(viewModel.playerHealth) / \(viewModel.playerMaxHealth)")
                                .font(.headline)
                                .foregroundColor(Theme.healerColor)
                            
                            ProgressView(value: Double(viewModel.playerHealth), total: Double(viewModel.playerMaxHealth))
                                .tint(Theme.healerColor)
                                .padding(.horizontal, 40)
                            
                            Text("The next enemy awaits...")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.top, 8)
                        }
                        .padding(24)
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                        
                        Button(action: {
                            viewModel.advanceWave()
                        }) {
                            Text("PROCEED TO NEXT WAVE")
                                .font(.headline)
                                .fontWeight(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.primary)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(color: Theme.primary.opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.horizontal, 40)
                        
                        Button("Flee Dungeon") {
                            viewModel.exitDungeon()
                            dismiss()
                        }
                        .font(.caption)
                        .foregroundColor(Theme.danger)
                        .padding(.top, 8)
                        
                    } else if viewModel.currentState == .victory {
                        Text("DUNGEON CONQUERED!")
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.success)
                            .glow(color: Theme.success.opacity(0.5), radius: 10)
                        
                        VStack(spacing: 16) {
                            Image(systemName: "chest.fill")
                                .font(.system(size: 64))
                                .foregroundColor(Theme.warning)
                                .glow(color: Theme.warning.opacity(0.6), radius: 15)
                            
                            if let loot = viewModel.droppedLoot {
                                VStack(spacing: 8) {
                                    Text("EPIC LOOT SECURED:")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.textSecondary)
                                        .tracking(1)
                                    
                                    HStack(spacing: 12) {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(loot.rarity.color)
                                        Text(loot.name.uppercased())
                                            .font(.headline)
                                            .foregroundColor(loot.rarity.color)
                                            .fontWeight(.black)
                                    }
                                    .padding(12)
                                    .background(loot.rarity.color.opacity(0.15))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(loot.rarity.color, lineWidth: 1))
                                }
                            }
                            
                            HStack(spacing: 24) {
                                VStack {
                                    Text("+1000")
                                        .font(.title2.bold())
                                        .foregroundColor(Theme.healerColor)
                                    Text("XP")
                                        .font(.caption)
                                        .foregroundColor(Theme.textMuted)
                                }
                                VStack {
                                    Text("+500")
                                        .font(.title2.bold())
                                        .foregroundColor(Theme.warning)
                                    Text("GOLD")
                                        .font(.caption)
                                        .foregroundColor(Theme.textMuted)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(24)
                        .background(Theme.cardBackground)
                        .cornerRadius(20)
                        .padding(.horizontal, 24)
                        
                        Button("CLAIM REWARDS & EXIT") {
                            viewModel.exitDungeon()
                            dismiss()
                        }
                        .font(.headline)
                        .fontWeight(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.success)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .padding(.horizontal, 40)
                        
                    } else if viewModel.currentState == .defeat {
                        Text("YOU DIED")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.danger)
                            .glow(color: Theme.danger.opacity(0.7), radius: 15)
                        
                        Text("You fell in battle. Train harder, equip better gear, and return when you are ready.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 32)
                        
                        Button("RESURRECT") {
                            viewModel.exitDungeon()
                            dismiss()
                        }
                        .font(.headline)
                        .fontWeight(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray, lineWidth: 1))
                        .padding(.horizontal, 40)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showCameraTracker) {
            CameraTrackingView(selectedClass: FirebaseService.shared.currentCharacter?.selectedClass ?? .archer)
        }
    }
}
