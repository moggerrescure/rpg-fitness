import SwiftUI

enum ConstellationNodeState {
    case activated
    case available
    case locked
}

struct ConstellationNode: Identifiable, Hashable {
    /// Stable across re-renders — UUID broke selection / double-tap feel.
    let id: String
    let name: String
    let stat: String // "STR", "DEX", "INT", "VIT"
    let x: CGFloat
    let y: CGFloat
    let description: String
    let index: Int
}

struct TwinklingStar: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let speed: Double
}

struct ConstellationSkillTreeView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedNodeIndex: Int? = nil
    @State private var pulseScale: CGFloat = 1.0
    @State private var dashPhase: CGFloat = 0.0
    @State private var twinkle = false
    @State private var isUpgrading = false
    @State private var spendFeedback: String? = nil
    
    @State private var backgroundStars: [TwinklingStar] = []
    
    private var character: Character {
        firebaseService.currentCharacter ?? Character(id: "local", username: "Hero", selectedClass: .swordsman)
    }
    
    private var classKey: String { character.selectedClass.rawValue }
    
    private var nodes: [ConstellationNode] {
        switch character.selectedClass {
        case .archer:
            return [
                node("Root Core", "DEX", 0, 100, "Celestial core of the Archer's Path. Unlocks initial attributes.", 0),
                node("Flex String", "DEX", -60, 40, "Increases Dexterity for higher accuracy and speed. +1 DEX.", 1),
                node("Wind Shear", "DEX", -110, -20, "Ultimate velocity. Arrows cut through wind resistance. +1 DEX.", 2),
                node("Iron Grip", "STR", 60, 40, "Strengthens draw weight for armor penetration. +1 STR.", 3),
                node("Heavy Arrow", "STR", 110, -20, "Devastating kinetic impact. Explodes on target shield. +1 STR.", 4),
                node("Starlight Sight", "VIT", 0, -20, "Sharpened focus and health. Grants permanent vitality. +1 VIT.", 5),
                node("Phoenix Arrow", "INT", 0, -100, "Enchant arrows with holy fire. Grants bonus magic intelligence. +1 INT.", 6)
            ]
        case .mage:
            return [
                node("Staff Base", "INT", 0, 110, "The base of magical alignment. Anchor for celestial power.", 0),
                node("Focus Gem", "INT", 0, 40, "Amplifies magical focus and spell power. +1 INT.", 1),
                node("Mana Ring", "INT", 0, -30, "Deep reserve of celestial energy for quick castings. +1 INT.", 2),
                node("Runic Shield", "VIT", -50, 10, "Enchanted defensive ward that absorbs incoming physical hits. +1 VIT.", 3),
                node("Swift Cast", "DEX", 50, 10, "Speeds up elemental execution and staff swings. +1 DEX.", 4),
                node("Cosmic Sigil", "INT", 0, -100, "Channels stellar space magic to double basic spells. +1 INT.", 5)
            ]
        case .swordsman:
            return [
                node("Blade Hilt", "STR", 0, 110, "The core anchor of physical power. Base sword node.", 0),
                node("Heavy Strike", "STR", 0, 40, "Adds weight to broadsword blows, bypassing armor. +1 STR.", 1),
                node("Starlight Guard", "VIT", -55, 20, "Shield wall from falling stardust, raising health. +1 VIT.", 2),
                node("Sun Crest", "VIT", 55, 20, "Sunlight warmth heals your soul. Permanently raises vitality. +1 VIT.", 3),
                node("Engraved Runes", "INT", 0, -30, "Runes carved on the blade, adding elemental magic damage. +1 INT.", 4),
                node("Vortex Slash", "STR", 0, -100, "Strikedown with double heavy swings, creating a whirlwind. +1 STR.", 5)
            ]
        case .healer:
            return [
                node("Ankh Core", "VIT", 0, 100, "Holy alignment for self recovery. Foundation of life.", 0),
                node("Solar Flare", "VIT", 0, 30, "Light warmth increases health and aura pool. +1 VIT.", 1),
                node("Aura Wing L", "INT", -60, -10, "Divine light heals companions continuously. +1 INT.", 2),
                node("Aura Wing R", "INT", 60, -10, "Stellar pulse targets raid boss vulnerabilities. +1 INT.", 3),
                node("Sacred Relic", "DEX", 0, -45, "Relic increases agility and movement speeds. +1 DEX.", 4),
                node("Divine Arch", "VIT", 0, -110, "Ultimate celestial armor, shielding entire party. +1 VIT.", 5)
            ]
        }
    }
    
    private func node(_ name: String, _ stat: String, _ x: CGFloat, _ y: CGFloat, _ description: String, _ index: Int) -> ConstellationNode {
        ConstellationNode(
            id: "\(classKey)_\(index)",
            name: name,
            stat: stat,
            x: x,
            y: y,
            description: description,
            index: index
        )
    }
    
    private var lineConnections: [(Int, Int)] {
        switch character.selectedClass {
        case .archer:
            return [(0, 1), (1, 2), (0, 3), (3, 4), (0, 5), (5, 6)]
        case .mage:
            return [(0, 1), (1, 2), (1, 3), (1, 4), (2, 5)]
        case .swordsman:
            return [(0, 1), (1, 2), (1, 3), (1, 4), (4, 5)]
        case .healer:
            return [(0, 1), (1, 2), (1, 3), (1, 4), (4, 5)]
        }
    }
    
    private var parentIndexByNode: [Int: Int] {
        Dictionary(uniqueKeysWithValues: lineConnections.map { ($0.1, $0.0) })
    }
    
    private var activeClassColor: Color {
        character.selectedClass.themeColor
    }
    
    private var classEmblemIconName: String {
        switch character.selectedClass {
        case .swordsman: return "shield.fill"
        case .archer: return "arrow.up.forward.app.fill"
        case .mage: return "wand.and.stars"
        case .healer: return "cross.case.fill"
        }
    }
    
    private var selectedNode: ConstellationNode? {
        guard let idx = selectedNodeIndex else { return nil }
        return nodes.first { $0.index == idx }
    }
    
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "080B18"), Color(hex: "020306")],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            ZStack {
                ForEach(backgroundStars) { star in
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size, height: star.size)
                        .offset(x: star.x, y: star.y)
                        .opacity(twinkle ? Double.random(in: 0.15...0.7) : 0.4)
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                generateStars()
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    twinkle.toggle()
                }
            }
            
            RadialGradient(
                colors: [activeClassColor.opacity(0.08), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("LEAVE MAP")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Theme.textSecondary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            ZStack {
                                Color.black.opacity(0.4)
                                Blur(style: .systemThinMaterialDark)
                            }
                        )
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(TactileButtonStyle())
                    
                    Spacer()
                    
                    Text("STELLAR CONSTELLATIONS")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(activeClassColor)
                        .glow(color: activeClassColor.opacity(0.4), radius: 8)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Theme.warning)
                            .glow(color: Theme.warning.opacity(0.6), radius: 5)
                        Text("\(character.statPoints) SP")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.warning.opacity(0.5), lineWidth: 1.5))
                }
                .padding()
                
                HStack(spacing: 12) {
                    hudStatCard(title: "STR", value: character.baseStrength, color: Theme.swordsmanColor, systemIcon: "figure.strength.strength")
                    hudStatCard(title: "DEX", value: character.baseDexterity, color: Theme.archerColor, systemIcon: "figure.run")
                    hudStatCard(title: "INT", value: character.baseIntelligence, color: Theme.mageColor, systemIcon: "sparkles")
                    hudStatCard(title: "VIT", value: character.baseVitality, color: Theme.healerColor, systemIcon: "heart.fill")
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                Spacer()
                
                ZStack {
                    Image(systemName: classEmblemIconName)
                        .font(.system(size: 160))
                        .foregroundColor(activeClassColor.opacity(0.04))
                        .glow(color: activeClassColor.opacity(0.1), radius: 15)
                        .blur(radius: 2)
                        .allowsHitTesting(false)
                    
                    ForEach(lineConnections, id: \.1) { connection in
                        if let start = nodes.first(where: { $0.index == connection.0 }),
                           let end = nodes.first(where: { $0.index == connection.1 }) {
                            let lit = state(for: start) == .activated && state(for: end) != .locked
                            
                            LineView(from: CGPoint(x: start.x, y: start.y), to: CGPoint(x: end.x, y: end.y))
                                .stroke(
                                    lit ? activeClassColor.opacity(0.4) : Color.white.opacity(0.08),
                                    style: StrokeStyle(lineWidth: lit ? 2.0 : 1.0, lineCap: .round)
                                )
                                .allowsHitTesting(false)
                            
                            if lit {
                                LineView(from: CGPoint(x: start.x, y: start.y), to: CGPoint(x: end.x, y: end.y))
                                    .stroke(
                                        activeClassColor,
                                        style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [10, 25], dashPhase: dashPhase)
                                    )
                                    .glow(color: activeClassColor.opacity(0.6), radius: 4)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    
                    ForEach(nodes) { node in
                        let nodeState = state(for: node)
                        let isSelected = selectedNodeIndex == node.index
                        
                        Button {
                            spendFeedback = nil
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedNodeIndex = node.index
                            }
                        } label: {
                            ZStack {
                                if nodeState == .activated || nodeState == .available || isSelected {
                                    Circle()
                                        .fill(nodeFillHalo(nodeState, selected: isSelected))
                                        .frame(width: isSelected ? 52 : 40, height: isSelected ? 52 : 40)
                                        .scaleEffect(nodeState == .available ? pulseScale : 1.0)
                                    
                                    Circle()
                                        .stroke(ringColor(nodeState).opacity(0.35), lineWidth: 0.5)
                                        .frame(width: isSelected ? 40 : 30)
                                        .scaleEffect(nodeState == .available ? pulseScale * 1.1 : 1.0)
                                }
                                
                                Circle()
                                    .stroke(
                                        isSelected ? activeClassColor : ringColor(nodeState),
                                        lineWidth: isSelected ? 2.5 : 1.5
                                    )
                                    .frame(width: isSelected ? 30 : 22, height: isSelected ? 30 : 22)
                                    .glow(color: nodeState == .activated ? activeClassColor.opacity(0.65) : Color.clear, radius: 5)
                                
                                Circle()
                                    .fill(coreFill(nodeState))
                                    .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
                                    .glow(color: nodeState == .activated ? .white.opacity(0.8) : Color.clear, radius: 3)
                            }
                            .frame(width: 56, height: 56)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .offset(x: node.x, y: node.y)
                        .accessibilityLabel("\(node.name), \(statusLabel(nodeState))")
                    }
                }
                .frame(width: 320, height: 320)
                
                Spacer()
                
                if let node = selectedNode {
                    let nodeState = state(for: node)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(node.name.uppercased())
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("ASTRONOMICAL SIGN: \(node.stat)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(activeClassColor)
                            }
                            Spacer()
                            
                            Text(statusLabel(nodeState))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(statusColor(nodeState))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(statusColor(nodeState).opacity(0.12))
                                .cornerRadius(6)
                        }
                        
                        Text(node.description)
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(2)
                            .lineLimit(3)
                        
                        if let spendFeedback {
                            Text(spendFeedback)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.warning)
                        } else if nodeState == .locked {
                            Text(lockReason(for: node))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                        } else if nodeState == .activated && node.index == 0 {
                            Text("Core star is always active. Select a connected star to spend SP.")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                        } else if nodeState == .activated {
                            Text("Already activated. +\(node.stat) applied.")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.success)
                        }
                        
                        if nodeState == .available {
                            Button(action: { allocatePoint(for: node) }) {
                                HStack {
                                    Spacer()
                                    if isUpgrading {
                                        ProgressView()
                                            .tint(.black)
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("SPEND 1 SP → +\(node.stat)")
                                    }
                                    Spacer()
                                }
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.vertical, 14)
                                .background(Theme.warning)
                                .cornerRadius(12)
                                .shadow(color: Theme.warning.opacity(0.4), radius: 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(TactileButtonStyle())
                            .disabled(isUpgrading)
                        } else if nodeState == .locked && character.statPoints == 0 {
                            Text("Earn SP by leveling up, then return here.")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.warning.opacity(0.9))
                        }
                    }
                    .padding(20)
                    .background(
                        ZStack {
                            Color.black.opacity(0.85)
                            Blur(style: .systemThinMaterialDark)
                        }
                    )
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(activeClassColor.opacity(0.45), lineWidth: 1.5))
                    .shadow(color: activeClassColor.opacity(0.2), radius: 12, y: 6)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("Tap a star · gold ring = ready to unlock with SP")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                        .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                dashPhase = -35.0
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.35
            }
        }
    }
    
    private func generateStars() {
        var temp: [TwinklingStar] = []
        for _ in 0..<50 {
            temp.append(TwinklingStar(
                x: CGFloat.random(in: -200...200),
                y: CGFloat.random(in: -350...350),
                size: CGFloat.random(in: 1.0...2.5),
                speed: Double.random(in: 1.5...3.0)
            ))
        }
        backgroundStars = temp
    }
    
    private func hudStatCard(title: String, value: Int, color: Color, systemIcon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemIcon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textMuted)
            Text("\(value)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.18), lineWidth: 1))
    }
    
    private var totalStatPointsSpent: Int {
        max(0, character.baseStrength - 10)
            + max(0, character.baseDexterity - 10)
            + max(0, character.baseIntelligence - 10)
            + max(0, character.baseVitality - 10)
    }
    
    private func isActivated(_ index: Int) -> Bool {
        if index == 0 { return true }
        return totalStatPointsSpent >= index
    }
    
    private func isParentActivated(_ node: ConstellationNode) -> Bool {
        if node.index == 0 { return true }
        guard let parent = parentIndexByNode[node.index] else { return false }
        return isActivated(parent)
    }
    
    private func state(for node: ConstellationNode) -> ConstellationNodeState {
        if isActivated(node.index) { return .activated }
        let nextIndex = totalStatPointsSpent + 1
        if character.statPoints > 0, isParentActivated(node), node.index == nextIndex {
            return .available
        }
        return .locked
    }
    
    private func statusLabel(_ state: ConstellationNodeState) -> String {
        switch state {
        case .activated: return "ACTIVATED"
        case .available: return "READY"
        case .locked: return "LOCKED"
        }
    }
    
    private func statusColor(_ state: ConstellationNodeState) -> Color {
        switch state {
        case .activated: return Theme.success
        case .available: return Theme.warning
        case .locked: return Theme.textMuted
        }
    }
    
    private func ringColor(_ state: ConstellationNodeState) -> Color {
        switch state {
        case .activated: return activeClassColor.opacity(0.7)
        case .available: return Theme.warning
        case .locked: return Color.white.opacity(0.25)
        }
    }
    
    private func coreFill(_ state: ConstellationNodeState) -> Color {
        switch state {
        case .activated: return activeClassColor
        case .available: return Theme.warning
        case .locked: return Color(hex: "4B5563")
        }
    }
    
    private func nodeFillHalo(_ state: ConstellationNodeState, selected: Bool) -> Color {
        switch state {
        case .activated: return activeClassColor.opacity(selected ? 0.25 : 0.15)
        case .available: return Theme.warning.opacity(selected ? 0.28 : 0.18)
        case .locked: return Color.clear
        }
    }
    
    private func lockReason(for node: ConstellationNode) -> String {
        if !isParentActivated(node) {
            return "Unlock the previous star on this path first."
        }
        let nextIndex = totalStatPointsSpent + 1
        if node.index > nextIndex {
            return "Spend SP on earlier stars first (next: #\(nextIndex))."
        }
        if character.statPoints <= 0 {
            return "No SP available. Level up to earn stat points."
        }
        return "This star is not ready yet."
    }
    
    private func allocatePoint(for node: ConstellationNode) {
        guard state(for: node) == .available else {
            spendFeedback = lockReason(for: node)
            return
        }
        guard character.statPoints > 0 else {
            spendFeedback = "No SP available."
            return
        }
        isUpgrading = true
        spendFeedback = nil
        
        var updatedChar = character
        updatedChar.allocateStatPoint(stat: node.stat)
        firebaseService.syncCharacter(updatedChar)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isUpgrading = false
            selectedNodeIndex = node.index
            spendFeedback = "+\(node.stat) allocated"
        }
    }
}

struct LineView: Shape {
    var from: CGPoint
    var to: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        
        path.move(to: CGPoint(x: midX + from.x, y: midY + from.y))
        path.addLine(to: CGPoint(x: midX + to.x, y: midY + to.y))
        return path
    }
}

struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
