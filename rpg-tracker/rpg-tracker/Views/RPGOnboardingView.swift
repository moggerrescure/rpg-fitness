import SwiftUI

struct RPGOnboardingView: View {
    let onComplete: () -> Void
    @State private var currentSlide: Int = 0
    @State private var isTransitioning: Bool = false
    @State private var transitionOpacity: Double = 0.0
    
    // NPC dialogue content with D&D interactive choices and responses
    private let dialogues: [NPCDialogue] = [
        NPCDialogue(
            name: "Alaric",
            role: "Guild Master",
            message: "Greetings, traveler! I am the Guild Master. Good to see a new face in our Tavern. In this realm, your real-world strength becomes powerful magic and character XP. Are you ready for your first quest?",
            themeColor: Theme.accent,
            avatarIcon: "shield.fill",
            featureText: "Health sync and automatic XP from daily steps",
            choiceA: "⚔️ [Bow your head] \"I'm ready to train, Master!\"",
            choiceB: "💰 [Ask] \"What reward awaits me?\"",
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
            choiceA: "🗡️ [Grip the hilt] \"I shall be a valiant Warrior!\"",
            choiceB: "🏹 [Draw the bow] \"I prefer bow and arrow!\"",
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
            choiceA: "🔥 [Ready yourself] \"They'll regret waking up!\"",
            choiceB: "📱 [Ask] \"How should I position the camera?\"",
            replyA: "\"Ha! Now that's fighting spirit! Remember: perfect form doubles your spell damage!\"",
            replyB: "\"Just place your phone on a flat surface about two meters away so your full body stays in frame.\""
        ),
        NPCDialogue(
            name: "Duke Branbran",
            role: "Arena Herald",
            message: "Hear the roar of the crowd? This is the Arena of Glory! Challenge other players in PvP duels or join a mighty clan for epic co-op raids. Make your name in battle!",
            themeColor: Theme.primary,
            avatarIcon: "flame.fill",
            featureText: "PvP Duels, Story Campaigns, and Clan Halls",
            choiceA: "🛡️ [Accept the challenge] \"I'll best the Arena's finest!\"",
            choiceB: "🤝 [Rally together] \"Guilds are my true family.\"",
            replyA: "\"The Arena welcomes bold gladiators! Duel victories raise your rank on the global leaderboard.\"",
            replyB: "\"Wise choice. Clan raids drop legendary trophies you can't earn alone.\""
        ),
        NPCDialogue(
            name: "Grimli",
            role: "Tavern Keeper",
            message: "Ha-ha! For every drop of sweat I'll pay you gold and XP. Visit my shop — I've stocked legendary swords, staves, and armor. Deal? Come inside, the ale is getting cold!",
            themeColor: Theme.warning,
            avatarIcon: "cart.fill",
            featureText: "Buy gear and upgrade your hero's stats",
            choiceA: "🛍️ [Strike a deal] \"Show me your wares, Grimli!\"",
            choiceB: "🍻 [Raise a mug] \"To meeting at the tavern!\"",
            replyA: "\"Oh, I've got epic artifacts in stock! Train hard, earn gold from workouts, and claim them!\"",
            replyB: "\"To your health, traveler! Now step inside — your great adventure begins right now!\""
        )
    ]
    
    private var activeBackgroundType: BackgroundType {
        switch currentSlide {
        case 0: return .general
        case 1: return .trainingRuins
        case 2: return .mountain
        case 3: return .arena
        case 4: return .tavern
        default: return .general
        }
    }
    
    var body: some View {
        ZStack {
            // Immersive background matching active NPC's zone
            AnimatedBackgroundView(backgroundType: activeBackgroundType)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: currentSlide)
            
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            
            if !isTransitioning {
                VStack(spacing: 0) {
                    // Header logo
                    HStack(spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.title2)
                            .foregroundColor(Theme.warning)
                        Text("FITRPG")
                            .font(.system(.headline, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .tracking(2.0)
                    }
                    .padding(.top, 20)

                    if currentSlide == 0 {
                        Text("FitRPG is for entertainment and fitness motivation only. It is not medical advice. Consult a physician before starting any exercise program.")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 8)
                    }
                    
                    // Dialog page slider
                    TabView(selection: $currentSlide) {
                        ForEach(0..<dialogues.count, id: \.self) { idx in
                            NPCSpeechView(dialogue: dialogues[idx], index: idx)
                                .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    
                    // Onboarding Action Bar
                    VStack(spacing: 12) {
                        if currentSlide < dialogues.count - 1 {
                            HStack {
                                Button("SKIP") {
                                    withAnimation {
                                        currentSlide = dialogues.count - 1
                                    }
                                }
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                                .padding(.leading, 24)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation {
                                        currentSlide += 1
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Text("NEXT")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(dialogues[currentSlide].themeColor.opacity(0.25))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(dialogues[currentSlide].themeColor.opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .padding(.trailing, 24)
                            }
                            .padding(.bottom, 24)
                        } else {
                            // Let's Enter the Tavern!
                            Button(action: startTavernTransition) {
                                Text("ENTER THE TAVERN")
                                    .font(.system(.headline, design: .monospaced))
                                    .fontWeight(.black)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(colors: [Theme.warning, Theme.accent], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Theme.warning.opacity(0.4), radius: 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                                    )
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
            }
            
            // Magical leaves zoom tunnel view
            if isTransitioning {
                MagicalTunnelView()
                    .opacity(transitionOpacity)
                    .zIndex(100)
            }
        }
        .hideNavigationBar()
    }
    
    private func startTavernTransition() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isTransitioning = true
            transitionOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                onComplete()
            }
        }
    }
}

// MARK: - NPC Speech View Component

private struct NPCSpeechView: View {
    let dialogue: NPCDialogue
    let index: Int
    @State private var isPortraitAnimating = false
    @State private var isTypewritingComplete = false
    @State private var selectedChoiceIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Animated NPC Portrait with spinning runes
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(colors: [dialogue.themeColor.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(isPortraitAnimating ? 360 : 0))
                    .animation(.linear(duration: 10.0).repeatForever(autoreverses: false), value: isPortraitAnimating)
                
                Circle()
                    .fill(dialogue.themeColor.opacity(0.10))
                    .frame(width: 125, height: 125)
                    .scaleEffect(isPortraitAnimating ? 1.04 : 0.96)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPortraitAnimating)
                
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 110, height: 110)
                        .overlay(Circle().stroke(dialogue.themeColor.opacity(0.5), lineWidth: 1.5))
                    
                    Image(systemName: dialogue.avatarIcon)
                        .font(.system(size: 42))
                        .foregroundColor(dialogue.themeColor)
                        .glow(color: dialogue.themeColor.opacity(0.6), radius: 8)
                }
            }
            .onAppear {
                isPortraitAnimating = true
            }
            
            // NPC Speech Dialogue Box (Typewriter dialogue frame + Tap to skip)
            VStack(alignment: .leading, spacing: 14) {
                // Name Tag header block
                HStack(spacing: 6) {
                    Text(dialogue.name)
                        .font(.system(.headline, design: .monospaced))
                        .fontWeight(.black)
                        .foregroundColor(dialogue.themeColor)
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text(dialogue.role.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .tracking(1)
                    
                    Spacer()
                    
                    if !isTypewritingComplete {
                        HStack(spacing: 3) {
                            Text("TAP TO SKIP")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 7))
                                .foregroundColor(Theme.textMuted)
                        }
                    }
                }
                .padding(.bottom, 2)
                
                // Dialogue typewriter message
                TypewriterText(text: dialogue.message, isComplete: $isTypewritingComplete)
                    .frame(height: 110, alignment: .topLeading)
                
                // Dialog decisions / Choices display
                if isTypewritingComplete {
                    VStack(spacing: 8) {
                        if selectedChoiceIndex == nil {
                            // Render two interactive buttons
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedChoiceIndex = 0
                                }
                            }) {
                                Text(dialogue.choiceA)
                                    .font(.system(size: 11, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(dialogue.themeColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(dialogue.themeColor.opacity(0.12))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(dialogue.themeColor.opacity(0.35), lineWidth: 1))
                            }
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedChoiceIndex = 1
                                }
                            }) {
                                Text(dialogue.choiceB)
                                    .font(.system(size: 11, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(dialogue.themeColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(dialogue.themeColor.opacity(0.12))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(dialogue.themeColor.opacity(0.35), lineWidth: 1))
                            }
                        } else {
                            // Render NPC response to selected choice
                            HStack(alignment: .top, spacing: 8) {
                                Text("➔")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(dialogue.themeColor)
                                
                                Text(selectedChoiceIndex == 0 ? dialogue.replyA : dialogue.replyB)
                                    .font(.system(size: 11, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.85))
                                    .italic()
                                    .lineSpacing(3)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(dialogue.themeColor.opacity(0.15), lineWidth: 1))
                            .transition(.opacity)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(22)
            .background(.thinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [dialogue.themeColor.opacity(0.4), dialogue.themeColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .dndBorder(color: dialogue.themeColor.opacity(0.65), length: 16, lineWidth: 2)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture {
                // Skip typing on tap gesture anywhere inside dialogue card
                if !isTypewritingComplete {
                    isTypewritingComplete = true
                }
            }
            .onChange(of: dialogue.name) { _, _ in
                // Reset slide choices when switching slides
                isTypewritingComplete = false
                selectedChoiceIndex = nil
            }
            
            // Feature description summary badge
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(dialogue.themeColor)
                Text(dialogue.featureText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            Spacer()
        }
    }
}

// MARK: - Typewriter Text Component with skip binding

struct TypewriterText: View {
    let text: String
    @Binding var isComplete: Bool
    
    let speed: Double = 0.012
    @State private var displayedText: String = ""
    @State private var animateTask: Task<Void, Never>? = nil
    
    var body: some View {
        Text(displayedText)
            .font(.system(.body, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
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
