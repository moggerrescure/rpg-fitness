import SwiftUI

struct WorldBossBattleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: BossRaidPhase = .fighting
    @State private var raidResult: BossRaidResult? = nil
    
    let worldBoss: WorldBoss
    let template: Boss
    let selectedClass: CharacterClass = FirebaseService.shared.currentCharacter?.selectedClass ?? .swordsman
    
    var raidBoss: RaidBoss {
        // Use currentHealth so the local raid session starts at real boss HP
        let bossHP = max(1000, worldBoss.currentHealth)
        
        // World bosses have massive attack power intended for team battles,
        // so we scale it down by 10 in the solo camera raid so the player can survive ~60 seconds.
        let scaledAttack = max(5, template.attackPower / 10)
        
        return RaidBoss(
            id: worldBoss.id,
            name: template.name,
            title: "GLOBAL THREAT",
            imageName: template.avatarName,
            maxHP: bossHP,
            attackPower: scaledAttack,
            attackInterval: template.attackInterval,
            element: .dark,
            xpReward: template.xpReward,
            goldReward: template.goldReward,
            description: template.description
        )
    }

    var body: some View {
        ZStack {
            switch phase {
            case .selection:
                Color.black.ignoresSafeArea() // Skipped for World Boss
                
            case .fighting:
                BossRaidCameraView(
                    boss: raidBoss,
                    characterClass: selectedClass,
                    onComplete: { result in
                        // Submit damage to Firebase
                        FirebaseService.shared.attackWorldBoss(damage: result.damageDealt)
                        
                        withAnimation(.easeInOut(duration: 0.5)) {
                            raidResult = result
                            phase = .result
                        }
                    },
                    onExit: {
                        dismiss()
                    }
                )
                .transition(.opacity)
                .ignoresSafeArea()

            case .result:
                if let result = raidResult {
                    BossRaidResultScreen(
                        result: result,
                        boss: raidBoss,
                        characterClass: selectedClass,
                        onPlayAgain: {
                            dismiss()
                        },
                        onExit: {
                            dismiss()
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .hideNavigationBar()
    }
}
