import SwiftUI
import Vision

// MARK: – Main Dungeon Run View

struct DungeonRunView: View {
    @StateObject private var vm = DungeonVM()
    @StateObject private var cameraVM: CameraTrackingVM
    @Environment(\.dismiss) private var dismiss

    private let selectedClass: CharacterClass

    init() {
        let cls = FirebaseService.shared.currentCharacter?.selectedClass ?? .archer
        self.selectedClass = cls
        // Init camera VM in dungeon mode: real camera, no simulator, no PvP bridge
        _cameraVM = StateObject(wrappedValue: CameraTrackingVM(selectedClass: cls, targetReps: nil, bossMaxHP: nil, damagePerRep: nil, isDungeonMode: true, onComplete: nil))
    }

    var body: some View {
        ZStack {
            // Background
            Color(hex: "080B12").ignoresSafeArea()

            switch vm.phase {
            case .intro:
                DungeonIntroView(vm: vm, characterClass: selectedClass) { dismiss() }
                    .transition(.opacity)

            case .combat(let wave):
                DungeonCombatView(vm: vm, cameraVM: cameraVM, selectedClass: selectedClass, wave: wave) {
                    // Exit dungeon
                    vm.exitDungeon()
                    dismiss()
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))

            case .waveClear(let wave):
                DungeonWaveClearView(wave: wave, vm: vm) {
                    // Flee
                    vm.exitDungeon()
                    dismiss()
                }
                .transition(.opacity)

            case .victory:
                DungeonVictoryView(vm: vm) {
                    vm.exitDungeon()
                    dismiss()
                }
                .transition(.opacity)

            case .defeat:
                DungeonDefeatView {
                    vm.exitDungeon()
                    dismiss()
                }
                .transition(.opacity)
            }
        }
        .hideNavigationBar()
        .onChange(of: cameraVM.repCount) { _, newCount in
            // Bridge: every new rep → dungeon VM registers it
            let combo = cameraVM.activeCombo
            vm.onRepPerformed(combo: combo)
        }
        .onDisappear {
            vm.exitDungeon()
        }
    }
}

// MARK: – Intro Screen

private struct DungeonIntroView: View {
    @ObservedObject var vm: DungeonVM
    let characterClass: CharacterClass
    let onDismiss: () -> Void
    @State private var appear = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Full cinematic dungeon background
            LinearGradient(
                colors: [Color(hex: "0D0005"), Color(hex: "1A0800"), Color(hex: "080B12")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Atmospheric top glow
            RadialGradient(
                colors: [Theme.danger.opacity(0.22), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.1),
                startRadius: 10, endRadius: 320
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 0) {
                    // ── TOP BAR ─────────────────────────────────────
                    HStack {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.textMuted)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.07))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        Spacer()
                        Text("DUNGEON RUN")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                            .tracking(3)
                        Spacer()
                        Color.clear.frame(width: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 16)

                    // ── BOSS PREVIEW (fills top portion) ────────────
                    VStack(spacing: 12) {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle()
                                    .fill(Theme.danger.opacity(0.5))
                                    .frame(height: 2)
                                    .cornerRadius(1)
                            }
                        }
                        .padding(.horizontal, 60)
                        .opacity(appear ? 1 : 0)

                        Text("3 WAVES AWAIT")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.danger.opacity(0.8))
                            .tracking(4)
                            .opacity(appear ? 1 : 0)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach([1, 2, 3], id: \.self) { wave in
                                    let boss = DungeonBoss.wave(wave, charLevel: FirebaseService.shared.currentCharacter?.level ?? 1)
                                    ZStack(alignment: .bottom) {
                                        // Card background
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [boss.color.opacity(0.3), Color.black.opacity(0.85)],
                                                    startPoint: .top, endPoint: .bottom
                                                )
                                            )
                                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(boss.color.opacity(wave == 2 ? 0.7 : 0.35), lineWidth: wave == 2 ? 2 : 1))

                                        // Boss image fills card
                                        Image(boss.imageName)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 140, height: geo.size.height * 0.28)
                                            .clipped()
                                            .cornerRadius(16)

                                        // Gradient overlay for label
                                        LinearGradient(
                                            colors: [Color.clear, Color.black.opacity(0.9)],
                                            startPoint: .center, endPoint: .bottom
                                        )
                                        .cornerRadius(16)

                                        // Label
                                        VStack(spacing: 3) {
                                            Text("W\(wave)")
                                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                                .foregroundColor(boss.color)
                                            Text(boss.name)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.75)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.bottom, 10)
                                    }
                                    .frame(width: 140, height: geo.size.height * 0.28)
                                    .glow(color: wave == 2 ? boss.color.opacity(0.3) : .clear, radius: 10)
                                    .scaleEffect(wave == 2 ? 1.03 : 1.0)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 18)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 40)

                    Spacer()

                    // ── CENTER TITLE ─────────────────────────────────
                    VStack(spacing: 10) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(Theme.danger)
                            .glow(color: Theme.danger.opacity(0.7), radius: 22)
                            .scaleEffect(pulse ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)

                        Text("ENTER THE DUNGEON")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .glow(color: Theme.danger.opacity(0.3), radius: 8)

                        Text("Keep doing reps to attack the boss.\nStop exercising and the boss attacks YOU.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 32)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)

                    Spacer()


                    // ── BOTTOM CTA ───────────────────────────────────
                    VStack(spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundColor(characterClass.themeColor)
                            Text("Camera tracks your \(characterClass.primaryExercise.uppercased()) reps in real time")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(characterClass.themeColor.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(characterClass.themeColor.opacity(0.3), lineWidth: 1))

                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                vm.startDungeon()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("BEGIN DUNGEON RUN")
                                    .font(.system(size: 15, weight: .black, design: .monospaced))
                                    .tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(colors: [Color(hex: "9B1C1C"), Color(hex: "450A0A")], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.danger.opacity(0.5), lineWidth: 1.5))
                            .shadow(color: Theme.danger.opacity(0.5), radius: 15, y: 6)
                        }
                        .buttonStyle(TactileButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                    .opacity(appear ? 1 : 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appear = true }
            pulse = true
        }
    }
}

// MARK: – Combat View

private struct DungeonCombatView: View {
    @ObservedObject var vm: DungeonVM
    @ObservedObject var cameraVM: CameraTrackingVM
    let selectedClass: CharacterClass
    let wave: Int
    let onExit: () -> Void

    @State private var showExitAlert = false
    @State private var bossPulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {

                    // ╔══════════════════════════════╗
                    // ║      BOSS ARENA (top 50%)    ║
                    // ╚══════════════════════════════╝
                    ZStack {
                        // Dark arena background with boss element tint
                        let bossColor = vm.boss?.color ?? Theme.danger
                        LinearGradient(
                            colors: [
                                Color.black,
                                bossColor.opacity(0.15),
                                Color(red: 0.06, green: 0.03, blue: 0.10)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )

                        // Boss element atmospheric glow
                        RadialGradient(
                            colors: [bossColor.opacity(0.30), Color.clear],
                            center: UnitPoint(x: 0.5, y: 0.0),
                            startRadius: 0, endRadius: 280
                        )

                        // Red flash when player is idle / boss warns
                        if vm.idleWarning {
                            Color.red.opacity(0.18)
                                .ignoresSafeArea()
                                .transition(.opacity)
                        }

                        // Red flash when player takes damage
                        if vm.playerFlash {
                            Color.red.opacity(0.25)
                                .ignoresSafeArea()
                                .transition(.opacity)
                        }

                        VStack(spacing: 0) {
                            // ── Top navigation bar ──────────────────────────
                            HStack {
                                Button(action: { showExitAlert = true }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(.black.opacity(0.55))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                                }
                                .buttonStyle(TactileButtonStyle())

                                Spacer()

                                // Boss name + wave bar
                                VStack(spacing: 3) {
                                    if let boss = vm.boss {
                                        HStack(spacing: 5) {
                                            Image(systemName: "flame.fill")
                                                .font(.system(size: 9))
                                                .foregroundStyle(boss.color)
                                            Text(boss.name.uppercased())
                                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                                .foregroundStyle(boss.color)
                                            Text("·")
                                                .foregroundStyle(.white.opacity(0.3))
                                            Text(boss.subtitle)
                                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                    }
                                    // Wave dots
                                    HStack(spacing: 4) {
                                        ForEach(1...3, id: \.self) { w in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(w <= wave ? Theme.danger : Color.white.opacity(0.15))
                                                .frame(width: 22, height: 5)
                                                .glow(color: w == wave ? Theme.danger.opacity(0.6) : .clear, radius: 3)
                                        }
                                    }
                                }

                                Spacer()

                                // Idle warning pill
                                if vm.idleWarning {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                        Text("STOP!")
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                    }
                                    .foregroundStyle(Theme.danger)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Theme.danger.opacity(0.2))
                                    .cornerRadius(8)
                                    .transition(.scale.combined(with: .opacity))
                                } else {
                                    Color.clear.frame(width: 36)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 8)

                            Spacer()

                            // ── Boss image ───────────────────────────────────
                            if let boss = vm.boss {
                                ZStack {
                                    // Ground glow
                                    Ellipse()
                                        .fill(
                                            RadialGradient(
                                                colors: [boss.color.opacity(bossPulse ? 0.40 : 0.22), .clear],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 80
                                            )
                                        )
                                        .frame(width: 160, height: 50)
                                        .offset(y: geo.size.height * 0.105)
                                        .blur(radius: 16)

                                    Image(boss.imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: geo.size.height * 0.40)
                                        .shadow(color: boss.color.opacity(vm.bossHPPercent < 0.25 ? 0.9 : 0.5), radius: vm.bossHPPercent < 0.25 ? 24 : 14)
                                        .offset(
                                            x: vm.bossShake ? CGFloat.random(in: -8...8) : 0,
                                            y: vm.bossShake ? CGFloat.random(in: -5...5) : 0
                                        )
                                        .scaleEffect(bossPulse ? 1.015 : 1.0)
                                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: bossPulse)

                                    // Floating damage numbers on boss
                                    ForEach(vm.damageNumbers) { dmg in
                                        if dmg.isBossDamage {
                                            DamageFloater(value: dmg.value, color: Color(hex: "34D399"))
                                                .offset(x: CGFloat.random(in: -40...40))
                                        }
                                    }
                                }
                            }

                            // ── Boss HP bar ───────────────────────────────────
                            if let boss = vm.boss {
                                VStack(spacing: 5) {
                                    HStack {
                                        HStack(spacing: 4) {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 9))
                                                .foregroundStyle(boss.color)
                                            Text("BOSS HP")
                                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                .foregroundStyle(boss.color.opacity(0.8))
                                        }
                                        Spacer()
                                        Text("\(boss.currentHP) / \(boss.maxHP)")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundStyle(.white)
                                    }

                                    GeometryReader { barGeo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.black.opacity(0.65))
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(LinearGradient(
                                                    colors: vm.bossHPPercent < 0.25
                                                        ? [Color.red, Color.orange, Color.yellow]
                                                        : [boss.color, boss.color.opacity(0.6)],
                                                    startPoint: .leading, endPoint: .trailing
                                                ))
                                                .frame(width: max(0, CGFloat(vm.bossHPPercent) * barGeo.size.width))
                                                .animation(.spring(response: 0.38), value: vm.bossHPPercent)
                                                .glow(color: boss.color.opacity(vm.bossHPPercent < 0.25 ? 0.9 : 0.5), radius: vm.bossHPPercent < 0.25 ? 8 : 4)
                                        }
                                    }
                                    .frame(height: 12)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.55))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(boss.color.opacity(0.3), lineWidth: 1))
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                        }
                    }
                    .frame(height: geo.size.height * 0.5)

                    // ── Glowing split divider ──────────────────────────────────
                    ZStack {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Theme.danger.opacity(0.7), selectedClass.themeColor.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(height: 2)
                            .blur(radius: 1)
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Theme.danger, selectedClass.themeColor],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(height: 1.5)
                    }

                    // ╔══════════════════════════════╗
                    // ║   CAMERA FEED (bottom 50%)   ║
                    // ╚══════════════════════════════╝
                    ZStack(alignment: .bottom) {
                        // Live camera feed
                        CameraPreview(session: cameraVM.cameraManager.session)
                            .ignoresSafeArea(edges: .bottom)

                        // Pose skeleton overlay
                        PoseOverlayView(joints: cameraVM.rawJoints, themeColor: selectedClass.themeColor)

                        // Player damage flash on camera half
                        ForEach(vm.damageNumbers) { dmg in
                            if !dmg.isBossDamage {
                                Color.red.opacity(0.3)
                                    .transition(.opacity)
                            }
                        }

                        // Gradient vignette for legibility
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.black.opacity(0.50), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 55)
                            Spacer()
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.90)],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 100)
                        }

                        // Rep counter + exercise label (floating center)
                        VStack(spacing: 5) {
                            // Exercise label pill
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(selectedClass.themeColor)
                                Text(selectedClass.primaryExercise.uppercased())
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(selectedClass.themeColor)
                                Text("= ATTACK")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.45))
                                Spacer()
                                // Detection indicator
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(cameraVM.isPersonDetected ? Theme.success : Theme.danger)
                                        .frame(width: 7, height: 7)
                                        .glow(color: cameraVM.isPersonDetected ? Theme.success : Theme.danger, radius: 3)
                                    Text(cameraVM.isPersonDetected ? "TRACKING" : "SEARCHING")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(cameraVM.isPersonDetected ? Theme.success : Theme.danger)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: "111520").opacity(0.88))
                            .cornerRadius(10)
                            .padding(.horizontal, 16)

                            // Big rep counter
                            HStack(alignment: .lastTextBaseline, spacing: 5) {
                                Text("\(vm.repCount)")
                                    .font(.system(size: 64, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .shadow(color: selectedClass.themeColor.opacity(0.9), radius: 18)
                                Text("REPS")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.top, 8)

                        // ── Player HP bar — anchored to very bottom ───────────
                        VStack(spacing: 5) {
                            HStack {
                                HStack(spacing: 5) {
                                    Image(systemName: "shield.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(vm.playerHPPercent < 0.25 ? Color.red : selectedClass.themeColor)
                                    Text("YOUR HP")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                                Text("\(vm.playerHP) / \(vm.playerMaxHP)")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.9))
                            }

                            GeometryReader { barGeo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black.opacity(0.7))
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(LinearGradient(
                                            colors: vm.playerHPPercent < 0.25
                                                ? [Color.red, Color.orange]
                                                : [selectedClass.themeColor, selectedClass.themeColor.opacity(0.65)],
                                            startPoint: .leading, endPoint: .trailing
                                        ))
                                        .frame(width: max(0, CGFloat(vm.playerHPPercent) * barGeo.size.width))
                                        .animation(.spring(response: 0.4), value: vm.playerHP)
                                        .glow(color: (vm.playerHPPercent < 0.25 ? Color.red : selectedClass.themeColor).opacity(0.5), radius: 4)
                                }
                            }
                            .frame(height: 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.0), Color.black.opacity(0.90)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    }
                    .frame(height: geo.size.height * 0.5)
                    .clipped()
                }
            }
            .onAppear { 
                withAnimation { bossPulse = true } 
                cameraVM.cameraManager.checkPermission()
            }
            .onDisappear {
                cameraVM.cameraManager.stopSession()
            }
            // ── Custom Flee Dialog ────────────────────────────────
            if showExitAlert {
                DungeonFleeOverlay(
                    onStay: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showExitAlert = false } },
                    onFlee: onExit
                )
                .zIndex(200)
                .transition(.opacity)
            }
        }
    }
}


// MARK: – Custom Flee Confirmation Overlay

private struct DungeonFleeOverlay: View {
    let onStay: () -> Void
    let onFlee: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture { onStay() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Theme.danger.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Circle()
                            .stroke(Theme.danger.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 88, height: 88)
                        Image(systemName: "figure.run")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Theme.danger)
                    }
                    .glow(color: Theme.danger.opacity(0.5), radius: 18)

                    // Text
                    VStack(spacing: 10) {
                        Text("FLEE THE DUNGEON?")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(1)

                        Text("Abandoning now will cost you\nall dungeon progress and rewards.")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                    }

                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: onStay) {
                            HStack(spacing: 10) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("STAY & FIGHT")
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "1A4D2E"), Color(hex: "0D2B1A")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.success.opacity(0.5), lineWidth: 1.5))
                            .shadow(color: Theme.success.opacity(0.25), radius: 12, y: 5)
                        }
                        .buttonStyle(TactileButtonStyle())

                        Button(action: onFlee) {
                            HStack(spacing: 10) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 14, weight: .bold))
                                Text("FLEE IN SHAME")
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.white.opacity(0.05))
                            .foregroundColor(Theme.danger)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.danger.opacity(0.45), lineWidth: 1.5))
                        }
                        .buttonStyle(TactileButtonStyle())
                    }
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "110E1E"), Color(hex: "0D0B18")],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .stroke(
                                    LinearGradient(
                                        colors: [Theme.danger.opacity(0.5), Theme.danger.opacity(0.1)],
                                        startPoint: .top, endPoint: .bottom
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
                .padding(.horizontal, 28)
                .scaleEffect(appear ? 1 : 0.85)
                .opacity(appear ? 1 : 0)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appear = true
            }
        }
    }
}

// MARK: – Wave Clear View

private struct DungeonWaveClearView: View {
    let wave: Int
    @ObservedObject var vm: DungeonVM
    let onFlee: () -> Void
    @State private var appear = false

    var nextBoss: DungeonBoss {
        DungeonBoss.wave(wave + 1, charLevel: FirebaseService.shared.currentCharacter?.level ?? 1)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0A1A0A"), Color(hex: "080B12")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.success)
                        .glow(color: Theme.success.opacity(0.6), radius: 15)
                        .scaleEffect(appear ? 1 : 0.5)

                    Text("WAVE \(wave) CLEARED!")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(Theme.success)
                        .glow(color: Theme.success.opacity(0.4), radius: 6)

                    Text("You performed \(vm.repCount) reps this wave")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
                .opacity(appear ? 1 : 0)

                // Player HP remaining
                VStack(spacing: 8) {
                    Text("HP REMAINING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6).fill(Theme.secondaryCard)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(colors: [Theme.success, Theme.success.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: vm.playerHPPercent * geo.size.width)
                                .glow(color: Theme.success.opacity(0.4), radius: 4)
                        }
                    }
                    .frame(height: 8)
                    Text("\(vm.playerHP) / \(vm.playerMaxHP) HP")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.success)
                }
                .padding(.horizontal, 48)
                .opacity(appear ? 1 : 0)

                // Next boss preview
                VStack(spacing: 12) {
                    Text("NEXT WAVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                        .tracking(2)

                    HStack(spacing: 16) {
                        Image(nextBoss.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(nextBoss.color.opacity(0.5), lineWidth: 1.5))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(nextBoss.name.uppercased())
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundColor(nextBoss.color)
                            Text(nextBoss.subtitle)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.danger)
                                Text("\(nextBoss.maxHP) HP")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Theme.cardBackground.opacity(0.8))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(nextBoss.color.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal, 24)
                .opacity(appear ? 1 : 0)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.spring()) { vm.advanceWave() }
                    }) {
                        HStack(spacing: 10) {
                            Text("CONTINUE TO WAVE \(wave + 1)")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                            Image(systemName: "chevron.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [nextBoss.color, nextBoss.color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: nextBoss.color.opacity(0.4), radius: 10, y: 4)
                    }
                    .buttonStyle(TactileButtonStyle())

                    Button("Flee Dungeon", action: onFlee)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.danger)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appear = true }
        }
    }
}

// MARK: – Victory View

private struct DungeonVictoryView: View {
    @ObservedObject var vm: DungeonVM
    let onExit: () -> Void
    @State private var appear = false
    @State private var particleActive = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1A1200"), Color(hex: "080B12")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Gold sparkle bg effect
            RadialGradient(colors: [Theme.healerColor.opacity(0.15), Color.clear], center: .center, startRadius: 0, endRadius: 300)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Trophy icon
                ZStack {
                    Circle()
                        .fill(Theme.healerColor.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Theme.healerColor)
                        .glow(color: Theme.healerColor.opacity(0.6), radius: 15)
                }
                .scaleEffect(appear ? 1 : 0.5)

                VStack(spacing: 8) {
                    Text("DUNGEON CONQUERED!")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(Theme.healerColor)
                        .glow(color: Theme.healerColor.opacity(0.4), radius: 8)
                    Text("All 3 waves defeated · \(vm.repCount) total reps")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
                .opacity(appear ? 1 : 0)

                // Rewards
                HStack(spacing: 16) {
                    rewardCard(value: "+\(vm.xpEarned)", label: "XP", icon: "star.fill", color: Theme.primary)
                    rewardCard(value: "+\(vm.goldEarned)", label: "GOLD", icon: "centsign.circle.fill", color: Theme.healerColor)
                }
                .padding(.horizontal, 32)
                .opacity(appear ? 1 : 0)

                // Loot drop
                if let loot = vm.droppedLoot {
                    VStack(spacing: 8) {
                        Text("EPIC LOOT SECURED")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                            .tracking(2)
                        HStack(spacing: 12) {
                            Image(systemName: loot.getIconName())
                                .font(.system(size: 22))
                                .foregroundColor(loot.rarity.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loot.name.uppercased())
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(loot.rarity.color)
                                Text(loot.rarity.rawValue.uppercased())
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(loot.rarity.color.opacity(0.7))
                            }
                        }
                        .padding(14)
                        .background(loot.rarity.color.opacity(0.1))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(loot.rarity.color.opacity(0.4), lineWidth: 1.5))
                        .glow(color: loot.rarity.color.opacity(0.2), radius: 8)
                    }
                    .padding(.horizontal, 32)
                    .opacity(appear ? 1 : 0)
                }

                Spacer()

                Button(action: onExit) {
                    Text("CLAIM REWARDS & EXIT")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [Theme.healerColor, Color(hex: "B45309")], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: Theme.healerColor.opacity(0.4), radius: 10, y: 4)
                }
                .buttonStyle(TactileButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true }
        }
    }

    @ViewBuilder
    private func rewardCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .glow(color: color.opacity(0.4), radius: 6)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color.opacity(0.1))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: – Defeat View

private struct DungeonDefeatView: View {
    let onExit: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            Color(hex: "110305").ignoresSafeArea()
            RadialGradient(colors: [Theme.danger.opacity(0.2), Color.clear], center: .center, startRadius: 0, endRadius: 250)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "skull.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Theme.danger)
                    .glow(color: Theme.danger.opacity(0.5), radius: 15)
                    .scaleEffect(appear ? 1 : 0.5)

                VStack(spacing: 8) {
                    Text("YOU DIED")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(Theme.danger)
                        .glow(color: Theme.danger.opacity(0.6), radius: 10)
                    Text("The dungeon has claimed your life.\nTrain harder and return when ready.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(appear ? 1 : 0)

                Spacer()

                Button(action: onExit) {
                    Text("RETREAT & RECOVER")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.25))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(TactileButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appear = true }
        }
    }
}

// MARK: – Sub-components

private struct DungeonTopBar: View {
    @ObservedObject var vm: DungeonVM
    let wave: Int
    let onExit: () -> Void

    var body: some View {
        HStack {
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .buttonStyle(TactileButtonStyle())

            Spacer()

            if let boss = vm.boss {
                VStack(spacing: 1) {
                    Text(boss.name.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(boss.color)
                    Text(boss.subtitle)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
            }

            Spacer()

            // Wave indicator
            HStack(spacing: 3) {
                ForEach(1...3, id: \.self) { w in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(w <= wave ? Theme.danger : Theme.secondaryCard)
                        .frame(width: 18, height: 6)
                        .glow(color: w == wave ? Theme.danger.opacity(0.5) : .clear, radius: 3)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }
}

private struct BossHPBar: View {
    let boss: DungeonBoss
    let percent: Double

    private var barColor: Color {
        if percent > 0.6 { return Color(hex: "EF4444") }
        if percent > 0.3 { return Color(hex: "F97316") }
        return Color(hex: "FBBF24")
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundColor(barColor)
                    Text("\(boss.name.uppercased()) HP")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer()
                Text("\(boss.currentHP) / \(boss.maxHP)")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.5))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [barColor, barColor.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, percent) * geo.size.width)
                        .glow(color: barColor.opacity(0.5), radius: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: percent)
                }
            }
            .frame(height: 8)
        }
        .padding(10)
        .background(Color.black.opacity(0.45))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(barColor.opacity(0.25), lineWidth: 1))
    }
}

private struct PlayerHPBar: View {
    let hp: Int
    let maxHP: Int
    let percent: Double
    let characterClass: CharacterClass

    private var hpColor: Color {
        if percent > 0.5 { return characterClass.themeColor }
        if percent > 0.25 { return Theme.warning }
        return Theme.danger
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.6))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [hpColor, hpColor.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, percent) * geo.size.width)
                        .glow(color: hpColor.opacity(0.4), radius: 3)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: percent)
                }
            }
            .frame(height: 7)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 9))
                        .foregroundColor(hpColor)
                    Text("YOUR HP")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer()
                Text("\(hp) / \(maxHP)")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.55))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(hpColor.opacity(0.25), lineWidth: 1))
    }
}

private struct DamageFloater: View {
    let value: Int
    let color: Color
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text(value < 0 ? "\(value)" : "+\(value)")
            .font(.system(size: 22, weight: .black, design: .monospaced))
            .foregroundColor(color)
            .glow(color: color.opacity(0.5), radius: 6)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    offset = -60
                    opacity = 0
                }
            }
    }
}
