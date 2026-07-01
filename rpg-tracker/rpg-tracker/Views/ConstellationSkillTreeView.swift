import SwiftUI

struct ConstellationNode: Identifiable, Hashable {
    let id = UUID()
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
    
    @State private var selectedNode: ConstellationNode? = nil
    @State private var pulseScale: CGFloat = 1.0
    @State private var starOffset: CGFloat = 0.0
    @State private var dashPhase: CGFloat = 0.0
    @State private var twinkle = false
    @State private var isUpgrading = false
    
    // Twinkling stars cache
    @State private var backgroundStars: [TwinklingStar] = []
    
    private var character: Character {
        firebaseService.currentCharacter ?? Character(id: "local", username: "Hero", selectedClass: .swordsman)
    }
    
    // Generate class specific constellation nodes
    private var nodes: [ConstellationNode] {
        switch character.selectedClass {
        case .archer:
            return [
                ConstellationNode(name: "Root Core", stat: "DEX", x: 0, y: 100, description: "Celestial core of the Archer's Path. Unlocks initial attributes.", index: 0),
                ConstellationNode(name: "Flex String", stat: "DEX", x: -60, y: 40, description: "Increases Dexterity for higher accuracy and speed. +1 DEX.", index: 1),
                ConstellationNode(name: "Wind Shear", stat: "DEX", x: -110, y: -20, description: "Ultimate velocity. Arrows cut through wind resistance. +1 DEX.", index: 2),
                ConstellationNode(name: "Iron Grip", stat: "STR", x: 60, y: 40, description: "Strengthens draw weight for armor penetration. +1 STR.", index: 3),
                ConstellationNode(name: "Heavy Arrow", stat: "STR", x: 110, y: -20, description: "Devastating kinetic impact. Explodes on target shield. +1 STR.", index: 4),
                ConstellationNode(name: "Starlight Sight", stat: "VIT", x: 0, y: -20, description: "Sharpened focus and health. Grants permanent vitality. +1 VIT.", index: 5),
                ConstellationNode(name: "Phoenix Arrow", stat: "INT", x: 0, y: -100, description: "Enchant arrows with holy fire. Grants bonus magic intelligence. +1 INT.", index: 6)
            ]
        case .mage:
            return [
                ConstellationNode(name: "Staff Base", stat: "INT", x: 0, y: 110, description: "The base of magical alignment. Anchor for celestial power.", index: 0),
                ConstellationNode(name: "Focus Gem", stat: "INT", x: 0, y: 40, description: "Amplifies magical focus and spell power. +1 INT.", index: 1),
                ConstellationNode(name: "Mana Ring", stat: "INT", x: 0, y: -30, description: "Deep reserve of celestial energy for quick castings. +1 INT.", index: 2),
                ConstellationNode(name: "Runic Shield", stat: "VIT", x: -50, y: 10, description: "Enchanted defensive ward that absorbs incoming physical hits. +1 VIT.", index: 3),
                ConstellationNode(name: "Swift Cast", stat: "DEX", x: 50, y: 10, description: "Speeds up elemental execution and staff swings. +1 DEX.", index: 4),
                ConstellationNode(name: "Cosmic Sigil", stat: "INT", x: 0, y: -100, description: "Channels stellar space magic to double basic spells. +1 INT.", index: 5)
            ]
        case .swordsman:
            return [
                ConstellationNode(name: "Blade Hilt", stat: "STR", x: 0, y: 110, description: "The core anchor of physical power. Base sword node.", index: 0),
                ConstellationNode(name: "Heavy Strike", stat: "STR", x: 0, y: 40, description: "Adds weight to broadsword blows, bypassing armor. +1 STR.", index: 1),
                ConstellationNode(name: "Starlight Guard", stat: "VIT", x: -55, y: 20, description: "Shield wall from falling stardust, raising health. +1 VIT.", index: 2),
                ConstellationNode(name: "Sun Crest", stat: "VIT", x: 55, y: 20, description: "Sunlight warmth heals your soul. Permanently raises vitality. +1 VIT.", index: 3),
                ConstellationNode(name: "Engraved Runes", stat: "INT", x: 0, y: -30, description: "Runes carved on the blade, adding elemental magic damage. +1 INT.", index: 4),
                ConstellationNode(name: "Vortex Slash", stat: "STR", x: 0, y: -100, description: "Strikedown with double heavy swings, creating a whirlwind. +1 STR.", index: 5)
            ]
        case .healer:
            return [
                ConstellationNode(name: "Ankh Core", stat: "VIT", x: 0, y: 100, description: "Holy alignment for self recovery. Foundation of life.", index: 0),
                ConstellationNode(name: "Solar Flare", stat: "VIT", x: 0, y: 30, description: "Light warmth increases health and aura pool. +1 VIT.", index: 1),
                ConstellationNode(name: "Aura Wing L", stat: "INT", x: -60, y: -10, description: "Divine light heals companions continuously. +1 INT.", index: 2),
                ConstellationNode(name: "Aura Wing R", stat: "INT", x: 60, y: -10, description: "Stellar pulse targets raid boss vulnerabilities. +1 INT.", index: 3),
                ConstellationNode(name: "Sacred Relic", stat: "DEX", x: 0, y: -45, description: "Relic increases agility and movement speeds. +1 DEX.", index: 4),
                ConstellationNode(name: "Divine Arch", stat: "VIT", x: 0, y: -110, description: "Ultimate celestial armor, shielding entire party. +1 VIT.", index: 5)
            ]
        }
    }
    
    // Connect lines
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
    
    var body: some View {
        ZStack {
            // Space gradient
            RadialGradient(
                colors: [Color(hex: "080B18"), Color(hex: "020306")],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Twinkling Starfield in background
            ZStack {
                ForEach(backgroundStars) { star in
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size, height: star.size)
                        .offset(x: star.x, y: star.y)
                        .opacity(twinkle ? Double.random(in: 0.15...0.7) : 0.4)
                }
            }
            .onAppear {
                generateStars()
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    twinkle.toggle()
                }
            }
            
            // Nebula ambient radial glow
            RadialGradient(
                colors: [activeClassColor.opacity(0.08), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header navigation bar
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
                    
                    // Available Upgrade Points
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
                
                // Stat status HUD
                HStack(spacing: 12) {
                    hudStatCard(title: "STR", value: character.baseStrength, color: Theme.swordsmanColor, systemIcon: "figure.strength.strength")
                    hudStatCard(title: "DEX", value: character.baseDexterity, color: Theme.archerColor, systemIcon: "figure.run")
                    hudStatCard(title: "INT", value: character.baseIntelligence, color: Theme.mageColor, systemIcon: "sparkles")
                    hudStatCard(title: "VIT", value: character.baseVitality, color: Theme.healerColor, systemIcon: "heart.fill")
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                Spacer()
                
                // Map Area
                ZStack {
                    // Giant background weapon class emblem
                    Image(systemName: classEmblemIconName)
                        .font(.system(size: 160))
                        .foregroundColor(activeClassColor.opacity(0.04))
                        .glow(color: activeClassColor.opacity(0.1), radius: 15)
                        .blur(radius: 2)
                    
                    // 1. Draw glowing constellation lines
                    ForEach(lineConnections, id: \.0) { connection in
                        let start = nodes.first(where: { $0.index == connection.0 })!
                        let end = nodes.first(where: { $0.index == connection.1 })!
                        let isUnlocked = isNodeUnlocked(start) && isNodeUnlocked(end)
                        
                        // Background line
                        LineView(from: CGPoint(x: start.x, y: start.y), to: CGPoint(x: end.x, y: end.y))
                            .stroke(
                                isUnlocked ? activeClassColor.opacity(0.4) : Color.white.opacity(0.08),
                                style: StrokeStyle(lineWidth: isUnlocked ? 2.0 : 1.0, lineCap: .round)
                            )
                        
                        // Flying energy pulse line on top of unlocked lines
                        if isUnlocked {
                            LineView(from: CGPoint(x: start.x, y: start.y), to: CGPoint(x: end.x, y: end.y))
                                .stroke(
                                    activeClassColor,
                                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [10, 25], dashPhase: dashPhase)
                                )
                                .glow(color: activeClassColor.opacity(0.6), radius: 4)
                        }
                    }
                    
                    // 2. Draw Interactive nodes
                    ForEach(nodes) { node in
                        let isUnlocked = isNodeUnlocked(node)
                        let isSelected = selectedNode?.id == node.id
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedNode = node
                            }
                        }) {
                            ZStack {
                                // Pulsing star halo for unlocked/selected stars
                                if isUnlocked || isSelected {
                                    Circle()
                                        .fill(activeClassColor.opacity(isSelected ? 0.25 : 0.15))
                                        .frame(width: isSelected ? 52 : 40, height: isSelected ? 52 : 40)
                                        .scaleEffect(pulseScale)
                                    
                                    // Expanding ripple rings
                                    Circle()
                                        .stroke(activeClassColor.opacity(0.35), lineWidth: 0.5)
                                        .frame(width: isSelected ? 40 : 30)
                                        .scaleEffect(pulseScale * 1.1)
                                }
                                
                                // Outer core ring
                                Circle()
                                    .stroke(
                                        isSelected ? activeClassColor : (isUnlocked ? activeClassColor.opacity(0.7) : Color.white.opacity(0.25)),
                                        lineWidth: isSelected ? 2.5 : 1.5
                                    )
                                    .frame(width: isSelected ? 30 : 22, height: isSelected ? 30 : 22)
                                    .glow(color: isUnlocked ? activeClassColor.opacity(0.65) : Color.clear, radius: 5)
                                
                                // Star core
                                Circle()
                                    .fill(isUnlocked ? activeClassColor : Color(hex: "4B5563"))
                                    .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
                                    .glow(color: isUnlocked ? .white.opacity(0.8) : Color.clear, radius: 3)
                            }
                        }
                        .offset(x: node.x, y: node.y)
                    }
                }
                .frame(width: 320, height: 320)
                
                Spacer()
                
                // Bottom Node Details card
                if let node = selectedNode {
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
                            
                            // Allocation status indicator
                            Text(isNodeUnlocked(node) ? "ACTIVATED" : "UNLOCKED")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(isNodeUnlocked(node) ? Theme.success : Theme.textMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isNodeUnlocked(node) ? Theme.success.opacity(0.12) : Theme.secondaryCard)
                                .cornerRadius(6)
                        }
                        
                        Text(node.description)
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(2)
                            .lineLimit(2)
                        
                        if !isNodeUnlocked(node) {
                            Button(action: { allocatePoint(for: node) }) {
                                HStack {
                                    Spacer()
                                    if isUpgrading {
                                        ProgressView()
                                            .tint(.black)
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("SPEND 1 STAT POINT")
                                    }
                                    Spacer()
                                }
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.vertical, 14)
                                .background(character.statPoints > 0 ? Theme.warning : Color.gray)
                                .cornerRadius(12)
                                .shadow(color: character.statPoints > 0 ? Theme.warning.opacity(0.4) : Color.clear, radius: 8)
                            }
                            .buttonStyle(TactileButtonStyle())
                            .disabled(character.statPoints == 0 || isUpgrading)
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
                    // Default helper text
                    Text("Select a star node to allocate attribute points")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                        .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            // Animate flying dash phase lines
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
    
    private func isNodeUnlocked(_ node: ConstellationNode) -> Bool {
        // Base starting core node is always unlocked
        if node.index == 0 { return true }
        
        // Node is unlocked if user base stat has been increased past default of 10
        switch node.stat {
        case "STR": return character.baseStrength > 10 + (node.index / 2)
        case "DEX": return character.baseDexterity > 10 + (node.index / 2)
        case "INT": return character.baseIntelligence > 10 + (node.index / 2)
        case "VIT": return character.baseVitality > 10 + (node.index / 2)
        default: return false
        }
    }
    
    private func allocatePoint(for node: ConstellationNode) {
        guard character.statPoints > 0 else { return }
        isUpgrading = true
        
        var updatedChar = character
        updatedChar.allocateStatPoint(stat: node.stat)
        
        // Save to cloud Firestore
        firebaseService.syncCharacter(updatedChar)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isUpgrading = false
            // Automatically refresh selection highlight
            selectedNode = node
        }
    }
}

// Custom Line drawing view connecting nodes
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

// Custom blur view representable
struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
