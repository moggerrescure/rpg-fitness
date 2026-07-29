import Foundation

/// Shared widget payload written by the main app and read by FitRPGWidget.
///
/// Enable App Group `group.com.borisdev.rpg-tracker` in Apple Developer portal
/// and in both `rpg-tracker.entitlements` and `FitRPGWidget.entitlements`.
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

    static func write(
        level: Int,
        xp: Int,
        nextLevelXp: Int,
        gold: Int,
        username: String,
        className: String
    ) {
        guard let defaults else { return }
        defaults.set(level, forKey: Keys.level)
        defaults.set(xp, forKey: Keys.xp)
        defaults.set(nextLevelXp, forKey: Keys.nextLevelXp)
        defaults.set(gold, forKey: Keys.gold)
        defaults.set(username, forKey: Keys.username)
        defaults.set(className, forKey: Keys.className)
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
