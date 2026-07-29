import Foundation

/// Client mirrors of Cloud Function economy caps (functions/src/economyHelpers.ts).
enum FitRPGEconomyCaps {
    static let pveXP = 500
    static let pveGold = 250
    static let activityXP = 200
    static let activityGold = 80

    static let pvpWinXP = 250
    static let pvpWinGold = 60
    static let pvpLossXP = 50
    static let pvpLossGold = 15
    static let pvpDrawXP = 100
    static let pvpDrawGold = 30

    static let arenaMatchEnergy = 10

    static func clampPvE(xp: Int, gold: Int) -> (xp: Int, gold: Int) {
        (min(max(0, xp), pveXP), min(max(0, gold), pveGold))
    }

    static func clampActivity(xp: Int, gold: Int) -> (xp: Int, gold: Int) {
        (min(max(0, xp), activityXP), min(max(0, gold), activityGold))
    }

    static func pvpRewards(outcome: String) -> (xp: Int, gold: Int) {
        switch outcome {
        case "win": return (pvpWinXP, pvpWinGold)
        case "loss": return (pvpLossXP, pvpLossGold)
        default: return (pvpDrawXP, pvpDrawGold)
        }
    }
}

struct PvPSettlementResult: Equatable {
    enum Status: Equatable {
        case settling
        case settled(outcome: String, xp: Int, gold: Int)
        case failed
    }
    var status: Status
}
