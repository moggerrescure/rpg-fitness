import Foundation
import SwiftUI

// MARK: – Quest definition

struct DailyQuest: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let xpReward: Int
    let goldReward: Int
    let targetCount: Int
    let questType: QuestType

    enum QuestType: String {
        case squats, pushups, pullups, dips
        case pvpMatch, dungeonRun
        case steps, calories
        case equipItem, visitShop
        case generic
    }
}

// MARK: – Engine

struct DailyQuestEngine {

    // Pool of ALL possible quests
    private static let allQuests: [DailyQuest] = [
        // ── TRAINING ───────────────────────────────────────────────────
        DailyQuest(id: "q_squat_15",    title: "Leg Day Warrior",       description: "Perform 15 squats",          icon: "figure.run",              iconColor: Color(hex: "34D399"), xpReward: 80,  goldReward: 20, targetCount: 15, questType: .squats),
        DailyQuest(id: "q_squat_30",    title: "Iron Legs",             description: "Perform 30 squats",          icon: "figure.run",              iconColor: Color(hex: "34D399"), xpReward: 140, goldReward: 35, targetCount: 30, questType: .squats),
        DailyQuest(id: "q_push_10",     title: "Push-Up Initiate",      description: "Complete 10 push-ups",       icon: "figure.strengthtraining.traditional", iconColor: Color(hex: "818CF8"), xpReward: 70, goldReward: 18, targetCount: 10, questType: .pushups),
        DailyQuest(id: "q_push_25",     title: "Upper Body Dominator",  description: "Complete 25 push-ups",       icon: "figure.strengthtraining.traditional", iconColor: Color(hex: "818CF8"), xpReward: 130, goldReward: 30, targetCount: 25, questType: .pushups),
        DailyQuest(id: "q_pull_5",      title: "Bar Climber",           description: "Complete 5 pull-ups",        icon: "figure.pull.ups",         iconColor: Color(hex: "FB923C"), xpReward: 90,  goldReward: 22, targetCount: 5,  questType: .pullups),
        DailyQuest(id: "q_pull_12",     title: "Vertical Force",        description: "Complete 12 pull-ups",       icon: "figure.pull.ups",         iconColor: Color(hex: "FB923C"), xpReward: 160, goldReward: 40, targetCount: 12, questType: .pullups),
        DailyQuest(id: "q_dips_8",      title: "Tricep Crusher",        description: "Perform 8 dips",             icon: "figure.gymnastics",       iconColor: Color(hex: "F472B6"), xpReward: 75,  goldReward: 18, targetCount: 8,  questType: .dips),
        DailyQuest(id: "q_dips_20",     title: "The Dipper King",       description: "Perform 20 dips",            icon: "figure.gymnastics",       iconColor: Color(hex: "F472B6"), xpReward: 150, goldReward: 38, targetCount: 20, questType: .dips),
        DailyQuest(id: "q_dips_30",     title: "Throne of Dips",        description: "Perform 30 dips",            icon: "figure.gymnastics",       iconColor: Color(hex: "F472B6"), xpReward: 200, goldReward: 50, targetCount: 30, questType: .dips),
        DailyQuest(id: "q_squat_50",    title: "100 Squat Challenge",   description: "Perform 50 squats",          icon: "figure.run.circle.fill",  iconColor: Color(hex: "34D399"), xpReward: 220, goldReward: 55, targetCount: 50, questType: .squats),
        DailyQuest(id: "q_push_50",     title: "Push-Up Legend",        description: "Complete 50 push-ups",       icon: "flame.fill",              iconColor: Color(hex: "818CF8"), xpReward: 250, goldReward: 65, targetCount: 50, questType: .pushups),
        DailyQuest(id: "q_mix_20",      title: "Combo Warrior",         description: "Do 10 pushups + 10 squats",  icon: "bolt.fill",               iconColor: Color(hex: "FBBF24"), xpReward: 180, goldReward: 45, targetCount: 20, questType: .generic),

        // ── COMBAT ─────────────────────────────────────────────────────
        DailyQuest(id: "q_pvp_1",       title: "First Blood",           description: "Win 1 PvP arena match",      icon: "swords.fill",             iconColor: Color(hex: "EF4444"), xpReward: 100, goldReward: 30, targetCount: 1,  questType: .pvpMatch),
        DailyQuest(id: "q_pvp_3",       title: "Arena Conqueror",       description: "Win 3 PvP arena matches",    icon: "crown.fill",              iconColor: Color(hex: "FBBF24"), xpReward: 250, goldReward: 75, targetCount: 3,  questType: .pvpMatch),
        DailyQuest(id: "q_dungeon_1",   title: "Dungeon Diver",         description: "Complete a dungeon run",     icon: "flame.fill",              iconColor: Color(hex: "EF4444"), xpReward: 120, goldReward: 35, targetCount: 1,  questType: .dungeonRun),
        DailyQuest(id: "q_dungeon_3",   title: "Dungeon Master",        description: "Complete 3 dungeon runs",    icon: "flame.circle.fill",       iconColor: Color(hex: "EF4444"), xpReward: 280, goldReward: 80, targetCount: 3,  questType: .dungeonRun),

        // ── HEALTH ─────────────────────────────────────────────────────
        DailyQuest(id: "q_steps_5k",    title: "Step Seeker",           description: "Walk 5,000 steps",           icon: "figure.walk",             iconColor: Color(hex: "22D3EE"), xpReward: 90,  goldReward: 22, targetCount: 5000, questType: .steps),
        DailyQuest(id: "q_steps_10k",   title: "Walker of Worlds",      description: "Walk 10,000 steps",          icon: "figure.walk.circle.fill", iconColor: Color(hex: "22D3EE"), xpReward: 200, goldReward: 50, targetCount: 10000, questType: .steps),
        DailyQuest(id: "q_cal_200",     title: "Calorie Burner",        description: "Burn 200 active calories",   icon: "flame.fill",              iconColor: Color(hex: "F97316"), xpReward: 110, goldReward: 28, targetCount: 200, questType: .calories),
        DailyQuest(id: "q_cal_500",     title: "Inferno Mode",          description: "Burn 500 active calories",   icon: "flame.circle.fill",       iconColor: Color(hex: "F97316"), xpReward: 240, goldReward: 60, targetCount: 500, questType: .calories),

        // ── RPG ────────────────────────────────────────────────────────
        DailyQuest(id: "q_shop_1",      title: "Window Shopping",       description: "Visit the Armory Shop",      icon: "cart.fill",               iconColor: Color(hex: "FBBF24"), xpReward: 40,  goldReward: 10, targetCount: 1, questType: .visitShop),
        DailyQuest(id: "q_equip_1",     title: "Gear Up",               description: "Equip a new item",           icon: "shield.fill",             iconColor: Color(hex: "6366F1"), xpReward: 60,  goldReward: 15, targetCount: 1, questType: .equipItem),
        DailyQuest(id: "q_earn_100g",   title: "Gold Digger",           description: "Earn 100 gold today",        icon: "centsign.circle.fill",    iconColor: Color(hex: "FBBF24"), xpReward: 80,  goldReward: 0,  targetCount: 100, questType: .generic),
    ]

    /// Returns a stable set of 4 quests for the given date (changes at midnight)
    static func dailyQuests(for date: Date = Date()) -> [DailyQuest] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        // Build a deterministic seed from the date
        let seed = (components.year ?? 2026) * 10000 + (components.month ?? 1) * 100 + (components.day ?? 1)
        var rng = SeededRNG(seed: seed)

        // Shuffle the pool using the seeded RNG
        var pool = allQuests
        for i in stride(from: pool.count - 1, through: 1, by: -1) {
            let j = rng.next() % (i + 1)
            pool.swapAt(i, j)
        }
        return Array(pool.prefix(4))
    }

    /// How many seconds until tomorrow's refresh
    static var secondsUntilReset: TimeInterval {
        let now = Date()
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return 86400
        }
        return tomorrow.timeIntervalSince(now)
    }

    /// Returns progress 0…1 for a quest based on character stats (best-effort)
    static func progress(for quest: DailyQuest, character: Character) -> Double {
        let done: Double
        switch quest.questType {
        case .squats:     done = Double(character.stats.totalSquats)
        case .pushups:    done = Double(character.stats.totalPushups)
        case .pullups:    done = Double(character.stats.totalPullups)
        case .dips:       done = Double(character.stats.totalDips)
        default:          return 0 // other types tracked externally
        }
        return min(done / Double(quest.targetCount), 1.0)
    }
}

// MARK: – Seeded RNG (Linear Congruential)

private struct SeededRNG {
    var state: Int
    init(seed: Int) { state = seed }
    mutating func next() -> Int {
        state = (state &* 1664525 &+ 1013904223) & 0x7fffffff
        return state
    }
}
