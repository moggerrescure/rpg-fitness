import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Avatar resolution (never leave bots on person.fill)

enum BattleAvatar {
    /// Aliases written by older clients / Cloud Functions → real Assets.xcassets names.
    private static let aliases: [String: String] = [
        "avatar_swordsman": "avatar_knight",
        "avatar_swordman": "avatar_knight",
        "avatar_warrior": "avatar_knight",
        "avatar_tank": "avatar_shield",
        "swordsman": "avatar_knight",
        "knight": "avatar_knight",
        "mage": "avatar_mage",
        "archer": "avatar_archer",
        "healer": "avatar_healer",
    ]

    static func canonicalName(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return aliases[raw.lowercased()] ?? aliases[raw] ?? raw
    }

    static func resolve(avatarName: String?, characterClass: CharacterClass) -> String {
        if let named = canonicalName(avatarName), loadPlatformImage(named: named) != nil {
            return named
        }
        let classDefault = characterClass.defaultAvatarName
        if loadPlatformImage(named: classDefault) != nil {
            return classDefault
        }
        // Extra class-themed assets if class default missing from bundle
        for candidate in characterClass.fallbackAvatarNames {
            if loadPlatformImage(named: candidate) != nil {
                return candidate
            }
        }
        return classDefault
    }

    static func loadImage(avatarName: String?, characterClass: CharacterClass) -> PlatformImage? {
        let resolved = resolve(avatarName: avatarName, characterClass: characterClass)
        return loadPlatformImage(named: resolved)
    }

    static func loadPlatformImage(named name: String) -> PlatformImage? {
        let resolved = canonicalName(name) ?? name
        if let bundleImage = PlatformImage(named: resolved) {
            return bundleImage
        }
        // Asset may be JPEG bytes with a .png filename — UIImage(contentsOfFile:) can fail;
        // UIImage(data:) inspects magic bytes and succeeds.
        let urls = [
            Bundle.main.url(forResource: resolved, withExtension: "png"),
            Bundle.main.url(forResource: resolved, withExtension: "jpg"),
            Bundle.main.url(forResource: resolved, withExtension: "jpeg"),
            Bundle.main.url(forResource: resolved, withExtension: "png", subdirectory: "Assets"),
            Bundle.main.url(forResource: resolved, withExtension: "jpg", subdirectory: "Assets"),
            Bundle.main.url(forResource: resolved, withExtension: "jpeg", subdirectory: "Assets"),
        ].compactMap { $0 }
        for url in urls {
            if let data = try? Data(contentsOf: url), let img = PlatformImage(data: data) {
                return img
            }
        }
        // Last resort: scan Bundle for a matching basename (covers nested resource copies).
        if let resourcePath = Bundle.main.resourcePath {
            let candidates = [
                "\(resourcePath)/\(resolved).png",
                "\(resourcePath)/Assets/\(resolved).png",
                "\(resourcePath)/\(resolved).jpg",
                "\(resourcePath)/Assets/\(resolved).jpg",
            ]
            for path in candidates {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                   let img = PlatformImage(data: data) {
                    return img
                }
            }
        }
        return nil
    }
}

// MARK: - Fantasy bot identities

enum BotRoster {
    struct Identity: Equatable {
        let name: String
        let characterClass: CharacterClass
        let avatarName: String

        var asBattlePlayer: BattlePlayer {
            BattlePlayer(
                id: "bot_\(UUID().uuidString)",
                name: name,
                characterClass: characterClass,
                health: 110,
                maxHealth: 110,
                avatarName: avatarName
            )
        }

        func asBattlePlayer(id: String, health: Int) -> BattlePlayer {
            BattlePlayer(
                id: id,
                name: name,
                characterClass: characterClass,
                health: health,
                maxHealth: health,
                avatarName: avatarName
            )
        }
    }

    private static let opponentPool: [(String, CharacterClass, String)] = [
        ("Shadow Warrior", .swordsman, "avatar_knight"),
        ("Ashen Blade", .swordsman, "avatar_shield"),
        ("Iron Warden", .swordsman, "avatar_dumbbell"),
        ("Frost Hexer", .mage, "avatar_mage"),
        ("Ember Seer", .mage, "avatar_phoenix"),
        ("Void Adept", .mage, "avatar_dragon"),
        ("Silent Arrow", .archer, "avatar_archer"),
        ("Night Falcon", .archer, "avatar_orc"),
        ("Storm Ranger", .archer, "avatar_goblin"),
        ("Dawn Chaplain", .healer, "avatar_healer"),
        ("Crystal Mender", .healer, "avatar_potion"),
        ("Crown Oracle", .healer, "avatar_crown"),
    ]

    private static let allyPool: [(String, CharacterClass, String)] = [
        ("Dawn Sentinel", .swordsman, "avatar_knight"),
        ("Shield Brother", .swordsman, "avatar_shield"),
        ("Rune Companion", .mage, "avatar_mage"),
        ("Spark Familiar", .mage, "avatar_phoenix"),
        ("Keen Scout", .archer, "avatar_archer"),
        ("Grove Ranger", .archer, "avatar_goblin"),
        ("Life Binder", .healer, "avatar_healer"),
        ("Potion Twin", .healer, "avatar_potion"),
    ]

    static func makeOpponent(index: Int = 0, preferredClass: CharacterClass? = nil) -> Identity {
        pick(from: opponentPool, index: index, preferredClass: preferredClass)
    }

    static func makeAlly(index: Int = 0, preferredClass: CharacterClass? = nil) -> Identity {
        pick(from: allyPool, index: index, preferredClass: preferredClass)
    }

    static func makeOpponents(count: Int) -> [Identity] {
        let classes: [CharacterClass] = [.swordsman, .mage, .archer, .healer]
        return (0..<count).map { i in
            makeOpponent(index: i, preferredClass: classes[i % classes.count])
        }
    }

    static func makeAllies(count: Int, excluding occupied: [CharacterClass] = []) -> [Identity] {
        let preferred: [CharacterClass] = [.healer, .mage, .archer, .swordsman]
            .filter { !occupied.contains($0) }
        return (0..<count).map { i in
            let cls = preferred.isEmpty
                ? CharacterClass.allCases[i % CharacterClass.allCases.count]
                : preferred[i % preferred.count]
            return makeAlly(index: i, preferredClass: cls)
        }
    }

    private static func pick(
        from pool: [(String, CharacterClass, String)],
        index: Int,
        preferredClass: CharacterClass?
    ) -> Identity {
        let filtered = preferredClass.map { cls in pool.filter { $0.1 == cls } } ?? pool
        let source = filtered.isEmpty ? pool : filtered
        let entry = source[abs(index) % source.count]
        return Identity(name: entry.0, characterClass: entry.1, avatarName: entry.2)
    }
}

// MARK: - Portrait view (image or class emblem — never person silhouette)

struct BattlePortraitView: View {
    let avatarName: String?
    let characterClass: CharacterClass
    var size: CGFloat = 48
    var lineWidth: CGFloat = 1.5
    var showGlow: Bool = true

    var body: some View {
        let color = characterClass.themeColor
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.35), color.opacity(0.08), Color.black.opacity(0.55)],
                        center: .center,
                        startRadius: 2,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)

            if let uiImage = BattleAvatar.loadImage(avatarName: avatarName, characterClass: characterClass) {
                Image(platformImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - lineWidth * 2, height: size - lineWidth * 2)
                    .clipShape(Circle())
            } else {
                // Rich class emblem — not person.fill
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: size * 0.78, height: size * 0.78)
                Image(systemName: characterClass.emblemSymbol)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )
        )
        .shadow(color: showGlow ? color.opacity(0.45) : .clear, radius: showGlow ? size * 0.08 : 0)
        .accessibilityLabel("\(characterClass.rawValue) portrait")
    }
}

extension BattlePlayer {
    /// Fills missing / stale avatar names so HUD never falls back to a blank person icon.
    mutating func normalizeBattleAvatar() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsFantasyName = trimmed.isEmpty
            || trimmed.lowercased().hasPrefix("bot")
            || trimmed == "AI Challenger"
            || trimmed == "Ally Bot"
            || trimmed == "HealerBot"
            || trimmed == "TankBot"
            || trimmed == "MageBot"
            || trimmed == "ShadowFiend"
            || trimmed == "DoomBringer"
            || trimmed == "NightStalker"

        if needsFantasyName {
            let identity = id.contains("bot")
                ? BotRoster.makeOpponent(index: abs(id.hashValue), preferredClass: characterClass)
                : BotRoster.makeOpponent(index: 0, preferredClass: characterClass)
            name = identity.name
            if avatarName == nil || avatarName?.isEmpty == true
                || avatarName == "avatar_swordsman"
                || canonicalLooksBroken(avatarName) {
                avatarName = identity.avatarName
            }
        }

        avatarName = BattleAvatar.resolve(avatarName: avatarName, characterClass: characterClass)
    }

    private func canonicalLooksBroken(_ raw: String?) -> Bool {
        guard let raw else { return true }
        return BattleAvatar.loadPlatformImage(named: raw) == nil
            && BattleAvatar.loadPlatformImage(named: characterClass.defaultAvatarName) != nil
    }

    var resolvedAvatarName: String {
        BattleAvatar.resolve(avatarName: avatarName, characterClass: characterClass)
    }
}

extension Array where Element == BattlePlayer {
    mutating func normalizeBattleAvatars() {
        for i in indices {
            self[i].normalizeBattleAvatar()
        }
    }
}

extension Battle {
    mutating func normalizeParticipantAvatars() {
        localTeam.normalizeBattleAvatars()
        opponentTeam.normalizeBattleAvatars()
    }
}
