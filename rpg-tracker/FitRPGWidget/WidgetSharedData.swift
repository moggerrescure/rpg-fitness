import Foundation

/// Keep in sync with `rpg-tracker/Helpers/WidgetSharedData.swift`.
enum WidgetSharedData {
    static let appGroupSuite = "group.com.borisdev.rpg-tracker"

    enum Keys {
        static let level = "widget_level"
        static let xp = "widget_xp"
        static let nextLevelXp = "widget_nextLevelXp"
        static let gold = "widget_gold"
        static let username = "widget_username"
        static let className = "widget_className"
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }

    struct Snapshot {
        let level: Int
        let xp: Int
        let nextLevelXp: Int
        let gold: Int
        let username: String
        let className: String
    }

    static func read() -> Snapshot? {
        guard let defaults else { return nil }
        guard defaults.object(forKey: Keys.level) != nil else { return nil }
        return Snapshot(
            level: defaults.integer(forKey: Keys.level),
            xp: defaults.integer(forKey: Keys.xp),
            nextLevelXp: max(1, defaults.integer(forKey: Keys.nextLevelXp)),
            gold: defaults.integer(forKey: Keys.gold),
            username: defaults.string(forKey: Keys.username) ?? "Hero",
            className: defaults.string(forKey: Keys.className) ?? "HERO"
        )
    }
}
