import SwiftUI
import Vision

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Boss Raid Entry Point
// ─────────────────────────────────────────────────────────────────────────────

struct BossRaidView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: BossRaidPhase = .selection
    @State private var selectedBoss: RaidBoss = RaidBoss.all[0]
    @State private var selectedClass: CharacterClass = FirebaseService.shared.currentCharacter?.selectedClass ?? .archer
    @State private var showCamera: Bool = false
    @State private var raidResult: BossRaidResult? = nil

    var body: some View {
        ZStack {
            switch phase {
            case .selection:
                BossSelectionScreen(
                    selectedBoss: $selectedBoss,
                    selectedClass: $selectedClass,
                    onStart: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            phase = .fighting
                        }
                    },
                    onBack: { dismiss() }
                )
                .transition(.opacity)

            case .fighting:
                BossRaidCameraView(
                    boss: selectedBoss,
                    characterClass: selectedClass,
                    onComplete: { result in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            raidResult = result
                            phase = .result
                        }
                    },
                    onExit: {
                        withAnimation { phase = .selection }
                    }
                )
                .transition(.opacity)
                .ignoresSafeArea()

            case .result:
                if let result = raidResult {
                    BossRaidResultScreen(
                        result: result,
                        boss: selectedBoss,
                        characterClass: selectedClass,
                        onPlayAgain: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                raidResult = nil
                                phase = .selection
                            }
                        },
                        onExit: { dismiss() }
                    )
                    .transition(.opacity)
                }
            }
        }
        .hideNavigationBar()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Phase / Model
// ─────────────────────────────────────────────────────────────────────────────

enum BossRaidPhase { case selection, fighting, result }

struct BossRaidResult {
    let victory: Bool
    let repsCompleted: Int
    let damageDealt: Int
    let bossMaxHP: Int
    let xpEarned: Int
    let goldEarned: Int
}

struct RaidBoss: Identifiable {
    let id: String
    let name: String
    let title: String
    let imageName: String
    let maxHP: Int
    let attackPower: Int
    let attackInterval: TimeInterval
    let element: BossElement
    let xpReward: Int
    let goldReward: Int
    let description: String

    enum BossElement: String {
        case fire = "Fire"
        case ice = "Ice"
        case shadow = "Shadow"
        case earth = "Earth"
        case dark = "Dark"
        case volcanic = "Volcanic"
        case nature = "Nature"

        var color: Color {
            switch self {
            case .fire: return Color(red: 1.0, green: 0.35, blue: 0.1)
            case .ice: return Color(red: 0.3, green: 0.75, blue: 1.0)
            case .shadow: return Color(red: 0.5, green: 0.2, blue: 0.8)
            case .earth: return Color(red: 0.55, green: 0.4, blue: 0.15)
            case .dark: return Color(red: 0.7, green: 0.1, blue: 0.35)
            case .volcanic: return Color(red: 1.0, green: 0.5, blue: 0.0)
            case .nature: return Color(red: 0.2, green: 0.8, blue: 0.4)
            }
        }

        var icon: String {
            switch self {
            case .fire: return "flame.fill"
            case .ice: return "snowflake"
            case .shadow: return "moon.fill"
            case .earth: return "mountain.2.fill"
            case .dark: return "eye.trianglebadge.exclamationmark"
            case .volcanic: return "tropicalstorm"
            case .nature: return "leaf.fill"
            }
        }
    }

    static let all: [RaidBoss] = [
        RaidBoss(
            id: "ancient_dragon",
            name: "Ancient Dragon",
            title: "THE ETERNAL FLAME",
            imageName: "boss_ancient_dragon",
            maxHP: 600,
            attackPower: 20,
            attackInterval: 5,
            element: .fire,
            xpReward: 2500,
            goldReward: 800,
            description: "A legend brought to life. Its fire consumes all who dare challenge it."
        ),
        RaidBoss(
            id: "ice_colossus",
            name: "Ice Colossus",
            title: "THE FROZEN TITAN",
            imageName: "boss_ice_colossus",
            maxHP: 500,
            attackPower: 18,
            attackInterval: 5.5,
            element: .ice,
            xpReward: 2000,
            goldReward: 650,
            description: "A colossal behemoth born from glacial depths. Its touch freezes all."
        ),
        RaidBoss(
            id: "shadow_reaper",
            name: "Shadow Reaper",
            title: "THE SOUL HARVESTER",
            imageName: "boss_shadow_reaper",
            maxHP: 550,
            attackPower: 22,
            attackInterval: 4,
            element: .shadow,
            xpReward: 2200,
            goldReward: 700,
            description: "A phantom that feeds on mortal fear. Darkness is its domain."
        ),
        RaidBoss(
            id: "gorgon_behemoth",
            name: "Gorgon Behemoth",
            title: "THE STONE BREAKER",
            imageName: "boss_gorgon_behemoth",
            maxHP: 480,
            attackPower: 16,
            attackInterval: 6,
            element: .earth,
            xpReward: 1800,
            goldReward: 580,
            description: "A primordial colossus of stone and fury. Its gaze turns heroes to statues."
        ),
        RaidBoss(
            id: "dark_lord",
            name: "Dark Lord",
            title: "THE VOID EMPEROR",
            imageName: "boss_dark_lord",
            maxHP: 650,
            attackPower: 25,
            attackInterval: 4.5,
            element: .dark,
            xpReward: 3000,
            goldReward: 1000,
            description: "Emperor of the abyss. His power warps reality itself."
        ),
        RaidBoss(
            id: "volcanic_peak",
            name: "Volcanic Titan",
            title: "THE MAGMA LORD",
            imageName: "boss_volcanic_peak",
            maxHP: 520,
            attackPower: 19,
            attackInterval: 5,
            element: .volcanic,
            xpReward: 2100,
            goldReward: 680,
            description: "Born in the heart of the volcano. Lava is its lifeblood."
        ),
        RaidBoss(
            id: "goblin_brute",
            name: "Goblin Warchief",
            title: "THE BRUTE KING",
            imageName: "boss_goblin_brute",
            maxHP: 350,
            attackPower: 12,
            attackInterval: 6.5,
            element: .nature,
            xpReward: 1200,
            goldReward: 400,
            description: "The largest goblin ever seen. A mindless engine of destruction."
        )
    ]
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Boss Selection Screen
// ─────────────────────────────────────────────────────────────────────────────

struct BossSelectionScreen: View {
    @Binding var selectedBoss: RaidBoss
    @Binding var selectedClass: CharacterClass
    let onStart: () -> Void
    let onBack: () -> Void

    @State private var scrollPage: Int = 0
    @State private var pulseBoss = false

    var body: some View {
        ZStack {
            // Background
            AnimatedBackgroundView(backgroundType: .arena)
                .ignoresSafeArea()
            Color.black.opacity(0.65).ignoresSafeArea()

            // Red vignette at top
            LinearGradient(
                colors: [selectedBoss.element.color.opacity(0.25), Color.clear],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar ──────────────────────────────────────────────────
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("BOSS RAID")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(2)
                        Text("Select your challenge")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Color.clear.frame(width: 44)
                }
                .padding(.horizontal)
                .padding(.top, 60)
                .padding(.bottom, 8)

                // ── Boss carousel ─────────────────────────────────────────────
                TabView(selection: $scrollPage) {
                    ForEach(Array(RaidBoss.all.enumerated()), id: \.element.id) { index, boss in
                        BossCard(boss: boss, isSelected: selectedBoss.id == boss.id)
                            .tag(index)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    selectedBoss = boss
                                    scrollPage = index
                                }
                            }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 300)
                .onChange(of: scrollPage) { newVal in
                    withAnimation(.spring()) {
                        selectedBoss = RaidBoss.all[newVal]
                    }
                }

                // Carousel dots
                HStack(spacing: 6) {
                    ForEach(0..<RaidBoss.all.count, id: \.self) { i in
                        Circle()
                            .fill(scrollPage == i ? selectedBoss.element.color : Color.white.opacity(0.25))
                            .frame(width: scrollPage == i ? 8 : 5, height: scrollPage == i ? 8 : 5)
                            .animation(.spring(), value: scrollPage)
                    }
                }
                .padding(.top, 8)

                // ── Boss info ─────────────────────────────────────────────────
                VStack(spacing: 12) {
                    // HP & difficulty
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("BOSS HP")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                            Text("\(selectedBoss.maxHP)")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 1, height: 30)
                        VStack(spacing: 4) {
                            Text("ATK PWR")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                            Text("\(selectedBoss.attackPower)")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundColor(selectedBoss.element.color)
                        }
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 1, height: 30)
                        VStack(spacing: 4) {
                            Text("REWARDS")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                Text("\(selectedBoss.xpReward)")
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedBoss.element.color.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // ── Class selector ────────────────────────────────────────────
                VStack(spacing: 10) {
                    Text("CHOOSE YOUR CLASS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2)

                    HStack(spacing: 10) {
                        ForEach(CharacterClass.allCases) { cls in
                            Button(action: {
                                withAnimation(.spring()) { selectedClass = cls }
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: classIcon(cls))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(selectedClass == cls ? cls.themeColor : .white.opacity(0.4))
                                    Text(cls.rawValue.uppercased())
                                        .font(.system(size: 7, weight: .black, design: .monospaced))
                                        .foregroundColor(selectedClass == cls ? cls.themeColor : .white.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedClass == cls ? cls.themeColor.opacity(0.15) : Color.black.opacity(0.3))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedClass == cls ? cls.themeColor.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 12)

                Spacer()

                // ── Start Button ──────────────────────────────────────────────
                Button(action: onStart) {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.headline)
                        Text("RAID \(selectedBoss.name.uppercased())")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.black)
                            .tracking(1.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(
                        LinearGradient(
                            colors: [selectedBoss.element.color, selectedBoss.element.color.opacity(0.7)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(18)
                    .shadow(color: selectedBoss.element.color.opacity(0.5), radius: 12, y: 4)
                }
                .buttonStyle(TactileButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
        }
    }

    private func classIcon(_ cls: CharacterClass) -> String {
        switch cls {
        case .archer: return "arrow.up.forward.app.fill"
        case .mage: return "bolt.heart.fill"
        case .swordsman: return "hammer.fill"
        case .healer: return "cross.case.fill"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Boss Card
// ─────────────────────────────────────────────────────────────────────────────

struct BossCard: View {
    let boss: RaidBoss
    let isSelected: Bool

    @State private var glow = false

    var body: some View {
        ZStack {
            // Glow background
            RadialGradient(
                colors: [boss.element.color.opacity(glow ? 0.25 : 0.12), Color.clear],
                center: .center, startRadius: 0, endRadius: 160
            )
            .frame(width: 260, height: 260)
            .blur(radius: 10)

            // Boss image
            Image(boss.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .shadow(color: boss.element.color.opacity(0.5), radius: 20)
                .scaleEffect(isSelected ? 1.0 : 0.9)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
        }
        .frame(maxWidth: .infinity)
        .overlay(
            VStack {
                Spacer()
                // Boss name + title at bottom
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: boss.element.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(boss.element.color)
                        Text(boss.element.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(boss.element.color)
                    }
                    Text(boss.name.uppercased())
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text(boss.title)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text(boss.description)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 30)
                }
                .padding(.bottom, 8)
            }
        )
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Boss Raid Camera View (Full-Screen, No PvP Logs)
// ─────────────────────────────────────────────────────────────────────────────

struct BossRaidCameraView: View {
    let boss: RaidBoss
    let characterClass: CharacterClass
    let onComplete: (BossRaidResult) -> Void
    let onExit: () -> Void

    @StateObject private var vm: CameraTrackingVM
    @State private var playerHP: Int
    @State private var bossAttackTimer: Timer? = nil
    @State private var showDamageFlash: Bool = false
    @State private var damageFlashText: String = ""
    @State private var playerDamageFlash: Bool = false
    @State private var bossDefeated: Bool = false
    @State private var playerDefeated: Bool = false

    private let playerMaxHP: Int

    init(boss: RaidBoss, characterClass: CharacterClass, onComplete: @escaping (BossRaidResult) -> Void, onExit: @escaping () -> Void) {
        self.boss = boss
        self.characterClass = characterClass
        self.onComplete = onComplete
        self.onExit = onExit

        let charHP = (FirebaseService.shared.currentCharacter?.energy ?? 100) + 100
        self.playerMaxHP = charHP
        self._playerHP = State(initialValue: charHP)

        let power = FirebaseService.shared.currentCharacter?.combatPower ?? 100
        let dmgPerRep = max(10, Int(Double(power) * 0.18))

        self._vm = StateObject(wrappedValue: CameraTrackingVM(
            selectedClass: characterClass,
            bossMaxHP: boss.maxHP,
            damagePerRep: dmgPerRep,
            isDungeonMode: true,
            onComplete: nil
        ))
    }

    var bossHPFraction: Double {
        guard vm.bossMaxHP > 0 else { return 1.0 }
        return Double(vm.bossCurrentHP) / Double(vm.bossMaxHP)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Full-screen camera ────────────────────────────────────────
                CameraPreview(session: vm.cameraManager.session)
                    .ignoresSafeArea()

                PoseOverlayView(joints: vm.rawJoints, themeColor: characterClass.themeColor)

                // Player damage red flash
                if playerDamageFlash {
                    Color.red.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                // ── VERTICAL SPLIT LAYOUT ─────────────────────────────────────
                VStack(spacing: 0) {

                    // ╔══════════════════════════════╗
                    // ║        BOSS HALF (top)       ║
                    // ╚══════════════════════════════╝
                    ZStack(alignment: .bottom) {
                        // Dark gradient overlay for boss half
                        LinearGradient(
                            colors: [Color.black.opacity(0.92), Color.black.opacity(0.5), Color.clear],
                            startPoint: .top, endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .top)

                        // Element-coloured glow at the top
                        LinearGradient(
                            colors: [boss.element.color.opacity(0.3), Color.clear],
                            startPoint: .top, endPoint: .center
                        )
                        .ignoresSafeArea(edges: .top)

                        VStack(spacing: 0) {
                            // ── Nav bar ───────────────────────────────────────
                            HStack {
                                Button(action: {
                                    bossAttackTimer?.invalidate()
                                    onExit()
                                }) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }

                                Spacer()

                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(characterClass.themeColor)
                                        .font(.caption)
                                    Text(characterClass.primaryExercise.uppercased())
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.black.opacity(0.55))
                                .cornerRadius(18)

                                Spacer()
                                Color.clear.frame(width: 40)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            Spacer()

                            // ── Big boss image ────────────────────────────────
                            Image(boss.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: geo.size.height * 0.28)
                                .shadow(color: boss.element.color.opacity(vm.hpBarBurn ? 0.8 : 0.5), radius: vm.hpBarBurn ? 24 : 14)
                                .offset(x: vm.hpBarShake ? CGFloat.random(in: -6...6) : 0,
                                        y: vm.hpBarShake ? CGFloat.random(in: -4...4) : 0)

                            // ── Boss name + HP ────────────────────────────────
                            VStack(spacing: 8) {
                                // Element badge + name
                                HStack(spacing: 6) {
                                    Image(systemName: boss.element.icon)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(boss.element.color)
                                    Text(boss.name.uppercased())
                                        .font(.system(size: 16, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                        .tracking(1)
                                    if let badge = vm.floatingComboBadge {
                                        Text(badge)
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundColor(.yellow)
                                            .glow(color: .orange.opacity(0.7), radius: 5)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }

                                // HP bar
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("BOSS HP")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundColor(vm.hpBarBurn ? .orange : boss.element.color.opacity(0.8))
                                        Spacer()
                                        Text("\(vm.bossCurrentHP) / \(vm.bossMaxHP)")
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .foregroundColor(.white)
                                    }

                                    GeometryReader { barGeo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.black.opacity(0.6))
                                                .frame(height: 12)
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(LinearGradient(
                                                    colors: vm.hpBarBurn
                                                        ? [Color.red, Color.orange, Color.yellow]
                                                        : [boss.element.color, boss.element.color.opacity(0.65)],
                                                    startPoint: .leading, endPoint: .trailing
                                                ))
                                                .frame(width: max(0, CGFloat(bossHPFraction) * barGeo.size.width), height: 12)
                                                .animation(.spring(response: 0.35), value: vm.bossCurrentHP)
                                                .glow(color: boss.element.color.opacity(0.5), radius: 4)
                                        }
                                    }
                                    .frame(height: 12)
                                }
                                .padding(12)
                                .background(Color.black.opacity(0.55))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(boss.element.color.opacity(0.3), lineWidth: 1))
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(height: geo.size.height * 0.5)

                    // Divider line
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [boss.element.color.opacity(0.6), characterClass.themeColor.opacity(0.6)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 1.5)

                    // ╔══════════════════════════════╗
                    // ║      PLAYER HALF (bottom)    ║
                    // ╚══════════════════════════════╝
                    ZStack(alignment: .top) {
                        // Dark gradient for bottom half
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.55), Color.black.opacity(0.88)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)

                        // Element glow at bottom
                        LinearGradient(
                            colors: [Color.clear, characterClass.themeColor.opacity(0.15)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)

                        VStack(spacing: 8) {
                            // Form feedback pill
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(vm.isPersonDetected ? Theme.success : Theme.danger)
                                    .frame(width: 8, height: 8)
                                    .glow(color: vm.isPersonDetected ? Theme.success : Theme.danger, radius: 4)
                                Text(vm.feedbackMessage)
                                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                if showDamageFlash {
                                    Text(damageFlashText)
                                        .font(.system(size: 13, weight: .black, design: .monospaced))
                                        .foregroundColor(.red)
                                        .shadow(color: .black, radius: 2)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(vm.isCorrectForm ? Color.black.opacity(0.6) : Theme.danger.opacity(0.75))
                            )
                            .overlay(Capsule().stroke(vm.isCorrectForm ? Color.white.opacity(0.1) : Theme.danger, lineWidth: 1))
                            .padding(.top, 16)

                            // Big reps counter
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(vm.repCount)")
                                    .font(.system(size: 72, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .shadow(color: characterClass.themeColor.opacity(0.8), radius: 18)
                                if let target = vm.targetReps {
                                    Text("/ \(target)")
                                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }

                            Text("REPS = DAMAGE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                                .tracking(3)

                            Spacer(minLength: 0)

                            // Player HP bar
                            VStack(spacing: 5) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(characterClass.themeColor)
                                    Text("YOUR HP")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.55))
                                    Spacer()
                                    Text("\(max(0, playerHP)) / \(playerMaxHP)")
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.9))
                                }

                                GeometryReader { barGeo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.black.opacity(0.6))
                                            .frame(height: 10)
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(LinearGradient(
                                                colors: playerHP < playerMaxHP / 4
                                                    ? [Color.red, Color.orange]
                                                    : [characterClass.themeColor, characterClass.themeColor.opacity(0.7)],
                                                startPoint: .leading, endPoint: .trailing
                                            ))
                                            .frame(width: max(0, CGFloat(playerHP) / CGFloat(playerMaxHP) * barGeo.size.width), height: 10)
                                            .animation(.spring(response: 0.4), value: playerHP)
                                    }
                                }
                                .frame(height: 10)
                            }
                            .padding(14)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(characterClass.themeColor.opacity(0.3), lineWidth: 1))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)
                        }
                    }
                    .frame(height: geo.size.height * 0.5)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { startBossAttackTimer() }
        .onDisappear { bossAttackTimer?.invalidate() }
        .onChange(of: vm.bossCurrentHP) { hp in
            if hp <= 0 && !bossDefeated && !playerDefeated {
                bossDefeated = true
                bossAttackTimer?.invalidate()
                triggerVictory()
            }
        }
        .onChange(of: playerHP) { hp in
            if hp <= 0 && !playerDefeated && !bossDefeated {
                playerDefeated = true
                bossAttackTimer?.invalidate()
                triggerDefeat()
            }
        }
    }

    private func startBossAttackTimer() {
        bossAttackTimer = Timer.scheduledTimer(withTimeInterval: boss.attackInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                guard !bossDefeated && !playerDefeated else { return }
                let dmg = boss.attackPower + Int.random(in: -3...5)
                playerHP = max(0, playerHP - dmg)

                // Flash red
                withAnimation(.easeOut(duration: 0.15)) {
                    playerDamageFlash = true
                    showDamageFlash = true
                    damageFlashText = "-\(dmg) HP"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation { playerDamageFlash = false }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { showDamageFlash = false }
                }
            }
        }
    }

    private func triggerVictory() {
        let damageDealt = boss.maxHP - max(0, vm.bossCurrentHP)
        let xp = boss.xpReward
        let gold = boss.goldReward

        if var char = FirebaseService.shared.currentCharacter {
            _ = char.addXP(xp)
            char.gold += gold
            FirebaseService.shared.syncCharacter(char)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete(BossRaidResult(
                victory: true,
                repsCompleted: vm.repCount,
                damageDealt: damageDealt,
                bossMaxHP: boss.maxHP,
                xpEarned: xp,
                goldEarned: gold
            ))
        }
    }

    private func triggerDefeat() {
        let damageDealt = boss.maxHP - max(0, vm.bossCurrentHP)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onComplete(BossRaidResult(
                victory: false,
                repsCompleted: vm.repCount,
                damageDealt: damageDealt,
                bossMaxHP: boss.maxHP,
                xpEarned: 0,
                goldEarned: 0
            ))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Boss Raid Result Screen
// ─────────────────────────────────────────────────────────────────────────────

struct BossRaidResultScreen: View {
    let result: BossRaidResult
    let boss: RaidBoss
    let characterClass: CharacterClass
    let onPlayAgain: () -> Void
    let onExit: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if result.victory {
                LinearGradient(
                    colors: [boss.element.color.opacity(0.3), Color.black],
                    startPoint: .top, endPoint: .center
                )
                .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color.red.opacity(0.25), Color.black],
                    startPoint: .top, endPoint: .center
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 28) {
                Spacer()

                // Victory/Defeat title
                VStack(spacing: 8) {
                    Text(result.victory ? "🏆" : "💀")
                        .font(.system(size: 64))
                        .scaleEffect(appear ? 1.0 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: appear)

                    Text(result.victory ? "BOSS DEFEATED!" : "DEFEATED!")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(result.victory ? boss.element.color : .red)
                        .glow(color: (result.victory ? boss.element.color : Color.red).opacity(0.5), radius: 10)

                    Text(result.victory ? boss.name.uppercased() + " HAS FALLEN" : "YOU WERE SLAIN BY " + boss.name.uppercased())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .tracking(1)
                }
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: appear)

                // Boss image
                Image(boss.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .opacity(result.victory ? 0.5 : 1.0)
                    .saturation(result.victory ? 0.3 : 1.0)
                    .overlay(
                        result.victory ? AnyView(
                            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        ) : AnyView(Color.clear)
                    )
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.3), value: appear)

                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ResultStatCard(title: "REPS DONE", value: "\(result.repsCompleted)", icon: "bolt.fill", color: characterClass.themeColor)
                    ResultStatCard(title: "DAMAGE DEALT", value: "\(result.damageDealt)", icon: "flame.fill", color: boss.element.color)
                    if result.victory {
                        ResultStatCard(title: "XP EARNED", value: "+\(result.xpEarned)", icon: "star.fill", color: .yellow)
                        ResultStatCard(title: "GOLD EARNED", value: "+\(result.goldEarned)", icon: "circle.circle.fill", color: .orange)
                    } else {
                        ResultStatCard(title: "BOSS HP LEFT", value: "\(result.bossMaxHP - result.damageDealt)", icon: "heart.fill", color: .red)
                        ResultStatCard(title: "DAMAGE %", value: "\(Int(Double(result.damageDealt)/Double(result.bossMaxHP)*100))%", icon: "chart.bar.fill", color: .purple)
                    }
                }
                .padding(.horizontal)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .animation(.spring(response: 0.5).delay(0.4), value: appear)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: onPlayAgain) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                            Text("TRY AGAIN")
                                .fontWeight(.black)
                                .tracking(1)
                        }
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(result.victory ? boss.element.color : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: (result.victory ? boss.element.color : Color.red).opacity(0.4), radius: 10, y: 4)
                    }
                    .buttonStyle(TactileButtonStyle())

                    Button(action: onExit) {
                        Text("BACK TO ARENA")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(14)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 50)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: appear)
            }
        }
        .onAppear {
            withAnimation { appear = true }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Result Stat Card
// ─────────────────────────────────────────────────────────────────────────────

struct ResultStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
            .glow(color: color.opacity(0.35), radius: 5)

            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
    }
}
