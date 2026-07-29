import SwiftUI

struct RPGOnboardingView: View {
    let onComplete: () -> Void
    @State private var currentSlide: Int = 0
    @State private var isTransitioning: Bool = false
    @State private var transitionOpacity: Double = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // NPC dialogue content with D&D interactive choices and responses
    private let dialogues: [NPCDialogue] = [
        NPCDialogue(
            name: "Alaric",
            role: "Guild Master",
            message: "Greetings, traveler! I am the Guild Master. Good to see a new face in our Tavern. In this realm, your real-world strength becomes powerful magic and character XP. Are you ready for your first quest?",
            themeColor: Theme.warning,
            avatarIcon: "shield.fill",
            featureText: "Health sync and automatic XP from daily steps",
            choiceA: "[Bow your head] \"I'm ready to train, Master!\"",
            choiceB: "[Ask] \"What reward awaits me?\"",
            choiceAIcon: "hand.raised.fill",
            choiceBIcon: "questionmark.circle.fill",
            replyA: "\"Noble spirit! Your daily effort will pay off handsomely. Now go forth to your first quests!\"",
            replyB: "\"Gold, glory, and great renown! Strong fighters earn the finest gear and their clan's respect here.\""
        ),
        NPCDialogue(
            name: "Caelin",
            role: "Class Master",
            message: "I train warriors and archers. Choose your path: crush foes with a blade, loose arrows, weave spells, or heal allies. Every squat in the real world is a crushing lunge with your blade here!",
            themeColor: Theme.archerColor,
            avatarIcon: "person.fill.viewfinder",
            featureText: "4 hero classes with unique exercises and bonuses",
            choiceA: "[Grip the hilt] \"I shall be a valiant Warrior!\"",
            choiceB: "[Draw the bow] \"I prefer bow and arrow!\"",
            choiceAIcon: "shield.lefthalf.filled",
            choiceBIcon: "scope",
            replyA: "\"Excellent choice! Your squats will become deadly lunges that shatter monster armor!\"",
            replyB: "\"A true marksman! Every push-up you do sends a phantom arrow straight into the enemy's heart.\""
        ),
        NPCDialogue(
            name: "Magister Varius",
            role: "Dungeon Keeper",
            message: "Behold these dark catacombs... ancient bosses lurk within. With your phone's camera we track squats and push-ups in real time. Your sweat and effort deal direct damage to monsters!",
            themeColor: Theme.danger,
            avatarIcon: "eye.fill",
            featureText: "Camera rep tracking and real-time spellcasting",
            choiceA: "[Ready yourself] \"They'll regret waking up!\"",
            choiceB: "[Ask] \"How should I position the camera?\"",
            choiceAIcon: "flame.fill",
            choiceBIcon: "camera.fill",
            replyA: "\"Ha! Now that's fighting spirit! Remember: perfect form doubles your spell damage!\"",
            replyB: "\"Just place your phone on a flat surface about two meters away so your full body stays in frame.\""
        ),
        NPCDialogue(
            name: "Duke Branbran",
            role: "Arena Herald",
            message: "Hear the roar of the crowd? This is the Arena of Glory! Challenge other players in PvP duels or join a mighty clan. Make your name in battle!",
            themeColor: Theme.primary,
            avatarIcon: "flame.fill",
            featureText: "PvP Duels, Story Campaigns, and Clan Halls",
            choiceA: "[Accept the challenge] \"I'll best the Arena's finest!\"",
            choiceB: "[Rally together] \"Guilds are my true family.\"",
            choiceAIcon: "flag.checkered",
            choiceBIcon: "person.3.fill",
            replyA: "\"The Arena welcomes bold gladiators! Duel victories raise your rank on the global leaderboard.\"",
            replyB: "\"Wise choice. Clans share goals and climb the war leaderboard together.\""
        ),
        NPCDialogue(
            name: "Grimli",
            role: "Tavern Keeper",
            message: "Ha-ha! For every drop of sweat I'll pay you gold and XP. Visit my shop — I've stocked legendary swords, staves, and armor. Deal? Come inside, the ale is getting cold!",
            themeColor: Theme.warning,
            avatarIcon: "cart.fill",
            featureText: "Buy gear and upgrade your hero's stats",
            choiceA: "[Strike a deal] \"Show me your wares, Grimli!\"",
            choiceB: "[Raise a mug] \"To meeting at the tavern!\"",
            choiceAIcon: "bag.fill",
            choiceBIcon: "cup.and.saucer.fill",
            replyA: "\"Oh, I've got epic artifacts in stock! Train hard, earn gold from workouts, and claim them!\"",
            replyB: "\"To your health, traveler! Now step inside — your great adventure begins right now!\""
        )
    ]
    
    /// Prefer curated hub art (tavern / clan hall / arena / mountain) so onboarding never falls back to flat starfield.
    private var activeBackgroundType: BackgroundType {
        switch currentSlide {
        case 0: return .tavern
        case 1: return .clanHall
        case 2: return .mountain
        case 3: return .arena
        case 4: return .tavern
        default: return .tavern
        }
    }
    
    private var activeThemeColor: Color {
        dialogues[min(currentSlide, dialogues.count - 1)].themeColor
    }
    
    var body: some View {
        ZStack {
            AnimatedBackgroundView(backgroundType: activeBackgroundType)
                .ignoresSafeArea()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.85), value: currentSlide)
            
            // Warm guild vignette — keeps art readable without washing to flat grey
            LinearGradient(
                colors: [
                    Color(hex: "1A0F08").opacity(0.55),
                    Color.black.opacity(0.28),
                    Color(hex: "0B0604").opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            RadialGradient(
                colors: [activeThemeColor.opacity(0.12), Color.clear],
                center: .top,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: currentSlide)
            
            if !isTransitioning {
                VStack(spacing: 0) {
                    brandHeader
                    
                    TabView(selection: $currentSlide) {
                        ForEach(0..<dialogues.count, id: \.self) { idx in
                            NPCSpeechView(dialogue: dialogues[idx], reduceMotion: reduceMotion)
                                .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    onboardingFooter
                }
            }
            
            if isTransitioning {
                MagicalTunnelView()
                    .opacity(transitionOpacity)
                    .zIndex(100)
            }
        }
        .hideNavigationBar()
    }
    
    // MARK: - Brand Header
    
    private var brandHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.warning, Color(hex: "FCD34D")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .glow(color: Theme.warning.opacity(0.55), radius: 10)
                
                Text("FITRPG")
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundColor(Theme.textPrimary)
                    .tracking(4)
                    .shadow(color: Color.black.opacity(0.45), radius: 6, y: 2)
            }
            .padding(.top, 16)
            
            if currentSlide == 0 {
                Text("For entertainment & fitness motivation only · Not medical advice · Consult a physician before exercise")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textMuted.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 32)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Footer
    
    private var onboardingFooter: some View {
        VStack(spacing: 14) {
            OnboardingPageIndicator(
                count: dialogues.count,
                current: currentSlide,
                accent: activeThemeColor
            )
            
            if currentSlide < dialogues.count - 1 {
                HStack(alignment: .center) {
                    Button("SKIP") {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.85)) {
                            currentSlide = dialogues.count - 1
                        }
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .accessibilityHint("Jump to the final onboarding step")
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.85)) {
                            currentSlide += 1
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("NEXT")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [
                                    activeThemeColor.opacity(0.85),
                                    activeThemeColor.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                        .shadow(color: activeThemeColor.opacity(0.35), radius: 10, y: 4)
                    }
                    .buttonStyle(TactileButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            } else {
                Button(action: startTavernTransition) {
                    HStack(spacing: 8) {
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 16, weight: .semibold))
                        Text("ENTER THE TAVERN")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundColor(Color(hex: "1A0F08"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FCD34D"), Theme.warning, Color(hex: "D97706")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    )
                    .shadow(color: Theme.warning.opacity(0.5), radius: 14, y: 6)
                }
                .buttonStyle(TactileButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }
    
    private func startTavernTransition() {
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.5)) {
            isTransitioning = true
            transitionOpacity = 1.0
        }
        
        let delay = reduceMotion ? 0.6 : 3.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.4)) {
                onComplete()
            }
        }
    }
}

// MARK: - Page Indicator

private struct OnboardingPageIndicator: View {
    let count: Int
    let current: Int
    let accent: Color
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { idx in
                Capsule()
                    .fill(idx == current ? accent : Color.white.opacity(0.22))
                    .frame(width: idx == current ? 22 : 7, height: 7)
                    .shadow(color: idx == current ? accent.opacity(0.45) : .clear, radius: 4)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

// MARK: - NPC Speech View Component

private struct NPCSpeechView: View {
    let dialogue: NPCDialogue
    let reduceMotion: Bool
    
    @State private var isPortraitAnimating = false
    @State private var isTypewritingComplete = false
    @State private var selectedChoiceIndex: Int? = nil
    @State private var panelAppeared = false
    
    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)
            
            portalPortrait
                .opacity(panelAppeared ? 1 : 0)
                .scaleEffect(panelAppeared ? 1 : 0.88)
            
            dialoguePanel
                .opacity(panelAppeared ? 1 : 0)
                .offset(y: panelAppeared ? 0 : 18)
            
            featureTip
                .opacity(panelAppeared && isTypewritingComplete ? 1 : 0.55)
            
            Spacer(minLength: 4)
        }
        .onAppear {
            isPortraitAnimating = true
            if reduceMotion {
                panelAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.55).delay(0.05)) {
                    panelAppeared = true
                }
            }
        }
        .onChange(of: dialogue.name) { _, _ in
            isTypewritingComplete = false
            selectedChoiceIndex = nil
            panelAppeared = false
            if reduceMotion {
                panelAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.45)) {
                    panelAppeared = true
                }
            }
        }
    }
    
    // MARK: Portal / Avatar
    
    private var portalPortrait: some View {
        ZStack {
            // Soft ethereal rings
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                dialogue.themeColor.opacity(0.45 - Double(ring) * 0.1),
                                dialogue.themeColor.opacity(0.05),
                                dialogue.themeColor.opacity(0.35 - Double(ring) * 0.08)
                            ],
                            center: .center
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: CGFloat(118 + ring * 22), height: CGFloat(118 + ring * 22))
                    .rotationEffect(.degrees(isPortraitAnimating ? 360 : 0))
                    .animation(
                        reduceMotion
                            ? nil
                            : .linear(duration: 14.0 + Double(ring) * 4).repeatForever(autoreverses: false),
                        value: isPortraitAnimating
                    )
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            dialogue.themeColor.opacity(isPortraitAnimating ? 0.28 : 0.14),
                            dialogue.themeColor.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 90
                    )
                )
                .frame(width: 160, height: 160)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                    value: isPortraitAnimating
                )
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "2A1A10").opacity(0.92),
                                Color(hex: "0E0A08").opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                dialogue.themeColor.opacity(0.85),
                                dialogue.themeColor.opacity(0.25),
                                Color(hex: "FCD34D").opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 96, height: 96)
                
                Image(systemName: dialogue.avatarIcon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [dialogue.themeColor, dialogue.themeColor.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .glow(color: dialogue.themeColor.opacity(0.7), radius: 12)
            }
            .shadow(color: dialogue.themeColor.opacity(0.35), radius: 18, y: 4)
        }
        .frame(height: 170)
        .accessibilityHidden(true)
    }
    
    // MARK: Dialogue Panel
    
    private var dialoguePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                // Name plate
                HStack(spacing: 6) {
                    Text(dialogue.name)
                        .font(.system(size: 16, weight: .black, design: .serif))
                        .foregroundColor(dialogue.themeColor)
                    
                    Text("·")
                        .foregroundColor(Color.white.opacity(0.25))
                    
                    Text(dialogue.role.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .tracking(1.2)
                }
                
                Spacer(minLength: 4)
                
                if !isTypewritingComplete {
                    HStack(spacing: 4) {
                        Text("TAP")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
            }
            
            // Warm divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [dialogue.themeColor.opacity(0.55), dialogue.themeColor.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
            TypewriterText(text: dialogue.message, isComplete: $isTypewritingComplete)
                .frame(minHeight: 96, alignment: .topLeading)
            
            if isTypewritingComplete {
                choicesSection
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .move(edge: .bottom))
                    )
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "2C2118").opacity(0.94),
                                Color(hex: "17110C").opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Subtle parchment wash
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "F59E0B").opacity(0.07),
                                Color.clear,
                                Color(hex: "6366F1").opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Top edge highlight (candle catch)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                dialogue.themeColor.opacity(0.35),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.45), radius: 20, y: 10)
        .shadow(color: dialogue.themeColor.opacity(0.12), radius: 24, y: 4)
        .dndBorder(color: dialogue.themeColor.opacity(0.7), length: 18, lineWidth: 2)
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isTypewritingComplete {
                isTypewritingComplete = true
            }
        }
    }
    
    @ViewBuilder
    private var choicesSection: some View {
        VStack(spacing: 10) {
            if selectedChoiceIndex == nil {
                DialogueChoiceButton(
                    title: dialogue.choiceA,
                    icon: dialogue.choiceAIcon,
                    accent: dialogue.themeColor,
                    action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            selectedChoiceIndex = 0
                        }
                    }
                )
                
                DialogueChoiceButton(
                    title: dialogue.choiceB,
                    icon: dialogue.choiceBIcon,
                    accent: dialogue.themeColor,
                    action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            selectedChoiceIndex = 1
                        }
                    }
                )
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(dialogue.themeColor)
                        .padding(.top, 2)
                    
                    Text(selectedChoiceIndex == 0 ? dialogue.replyA : dialogue.replyB)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.textPrimary.opacity(0.9))
                        .italic()
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(dialogue.themeColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(dialogue.themeColor.opacity(0.28), lineWidth: 1)
                )
                .transition(.opacity)
            }
        }
    }
    
    private var featureTip: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(dialogue.themeColor.opacity(0.8))
            Text(dialogue.featureText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Theme.textSecondary.opacity(0.85))
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Choice Button

private struct DialogueChoiceButton: View {
    let title: String
    let icon: String
    let accent: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(0.22))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(accent)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.2),
                                accent.opacity(0.08)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(0.45), lineWidth: 1.5)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 3)
                    .padding(.vertical, 8)
                    .padding(.leading, 1)
            }
        }
        .buttonStyle(TactileButtonStyle())
    }
}

// MARK: - Typewriter Text Component with skip binding

struct TypewriterText: View {
    let text: String
    @Binding var isComplete: Bool
    
    let speed: Double = 0.012
    @State private var displayedText: String = ""
    @State private var animateTask: Task<Void, Never>? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Text(displayedText)
            .font(.system(size: 15, weight: .regular, design: .rounded))
            .foregroundColor(Theme.textPrimary.opacity(0.92))
            .multilineTextAlignment(.leading)
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onAppear {
                startTyping()
            }
            .onChange(of: text) { _, _ in
                startTyping()
            }
            .onChange(of: isComplete) { _, newValue in
                if newValue {
                    animateTask?.cancel()
                    displayedText = text
                }
            }
            .onDisappear {
                animateTask?.cancel()
            }
    }
    
    private func startTyping() {
        animateTask?.cancel()
        if reduceMotion {
            displayedText = text
            isComplete = true
            return
        }
        displayedText = ""
        isComplete = false
        let chars = Array(text)
        animateTask = Task {
            var temp = ""
            for char in chars {
                if Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                temp.append(char)
                let currentTemp = temp
                await MainActor.run {
                    self.displayedText = currentTemp
                }
            }
            await MainActor.run {
                isComplete = true
            }
        }
    }
}

// MARK: - NPCDialogue Model Struct

struct NPCDialogue {
    let name: String
    let role: String
    let message: String
    let themeColor: Color
    let avatarIcon: String
    let featureText: String
    
    let choiceA: String
    let choiceB: String
    let choiceAIcon: String
    let choiceBIcon: String
    let replyA: String
    let replyB: String
}

// MARK: - Magical Leaf Flight Tunnel transition View (Lag-free)

private struct MagicalTunnelView: View {
    @State private var tunnelScale: CGFloat = 0.05
    @State private var leaves: [TunnelLeaf] = []
    
    var body: some View {
        ZStack {
            Color(hex: "080510")
                .ignoresSafeArea()
            
            StarsOverlay()
                .opacity(0.7)
            
            ZStack {
                ForEach(0..<4) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "F59E0B").opacity(0.15), Color(hex: "10B981").opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                        .scaleEffect(tunnelScale * CGFloat(i + 1) * 0.8)
                }
            }
            
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    
                    for leaf in leaves {
                        let age = (elapsed - leaf.birthTime).truncatingRemainder(dividingBy: leaf.duration)
                        let progress = age / leaf.duration
                        
                        let distance = (size.width * 0.7) * progress
                        let x = center.x + cos(leaf.angle) * distance
                        let y = center.y + sin(leaf.angle) * distance
                        
                        let currentSize = leaf.baseSize * (0.2 + progress * 1.5)
                        let opacity = progress < 0.15 ? (progress / 0.15) : (progress > 0.8 ? (1.0 - progress) / 0.2 : 1.0)
                        
                        context.drawLayer { ctx in
                            ctx.opacity = opacity
                            ctx.translateBy(x: x, y: y)
                            ctx.rotate(by: .degrees(leaf.rotationSpeed * elapsed * 60))
                            
                            var path = Path()
                            path.addEllipse(in: CGRect(x: -currentSize / 2, y: -currentSize / 2, width: currentSize, height: currentSize * 0.5))
                            
                            ctx.fill(path, with: .color(leaf.color))
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            var temp: [TunnelLeaf] = []
            for i in 0..<45 {
                let angle = Double(i) * (2.0 * .pi / 45.0) + Double.random(in: -0.15...0.15)
                let speed = Double.random(in: 2.2...3.5)
                let color: Color
                switch i % 3 {
                case 0: color = Color(hex: "F59E0B") // Autumn gold
                case 1: color = Color(hex: "10B981") // Mint green
                default: color = Color(hex: "EF4444") // Warm red
                }
                
                temp.append(TunnelLeaf(
                    angle: angle,
                    duration: speed,
                    birthTime: Date().timeIntervalSinceReferenceDate - Double.random(in: 0...3),
                    baseSize: CGFloat.random(in: 12...22),
                    rotationSpeed: Double.random(in: -2...2),
                    color: color
                ))
            }
            self.leaves = temp
            
            withAnimation(.easeOut(duration: 3.2)) {
                tunnelScale = 3.5
            }
        }
    }
}

private struct TunnelLeaf {
    let angle: Double
    let duration: Double
    let birthTime: Double
    let baseSize: CGFloat
    let rotationSpeed: Double
    let color: Color
}
