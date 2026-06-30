import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

enum BackgroundType: String, Codable {
    case general = "rpg_bg_wilderness"
    case village = "bg_village"
    case castle = "bg_castle"
    case forest = "bg_green_forest"
    case mountain = "bg_valley_mountains"
    
    // New DND/RPG themed backgrounds for the main navigation tabs
    case tavern = "bg_tavern"
    case arena = "bg_arena"
    case trainingRuins = "bg_training_ruins"
    case clanHall = "bg_clan_hall"
    case shop = "bg_shop"
}

struct AnimatedBackgroundView: View {
    let backgroundType: BackgroundType
    
    @State private var cloudOffset1: CGFloat = -100
    @State private var cloudOffset2: CGFloat = -200
    @State private var windOpacity: Double = 0.2
    @State private var treeSway: Double = 0.0
    @State private var lampPulse: Bool = false
    @State private var fogOffset: CGFloat = -450
    @State private var spotlightAngle: Double = -5
    
    init(backgroundType: BackgroundType = .general) {
        self.backgroundType = backgroundType
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base background image loaded from project assets or bundle path
                if let uiImage = loadProjectImage() {
                    Image(platformImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    // Fallback to beautiful radial gradient representing the aurora sky
                    ZStack {
                        Theme.background
                        
                        RadialGradient(
                            colors: [Theme.accent.opacity(0.35), Theme.primary.opacity(0.15), Color.clear],
                            center: .top,
                            startRadius: 0,
                            endRadius: 500
                        )
                        
                        // Starry points
                        StarsOverlay()
                    }
                }
                
                // Castle dark vignette overlay
                if backgroundType == .castle {
                    RadialGradient(
                        colors: [Color.clear, Color.black.opacity(0.7)],
                        center: .center,
                        startRadius: 200,
                        endRadius: 600
                    )
                    .ignoresSafeArea()
                }
                
                // Village sun rays overlay
                if backgroundType == .village {
                    GeometryReader { sunGeo in
                        ZStack {
                            ForEach(0..<3) { idx in
                                Path { path in
                                    path.move(to: CGPoint(x: sunGeo.size.width * 0.1, y: 0))
                                    path.addLine(to: CGPoint(x: sunGeo.size.width * (0.2 + CGFloat(idx) * 0.25), y: sunGeo.size.height))
                                    path.addLine(to: CGPoint(x: sunGeo.size.width * (0.35 + CGFloat(idx) * 0.25), y: sunGeo.size.height))
                                    path.closeSubpath()
                                }
                                .fill(Color.white.opacity(0.04))
                            }
                        }
                    }
                    .ignoresSafeArea()
                }
                
                // Tavern warm lamp flickering overlays (highly optimized, uses hardware-accelerated opacity pulse)
                if backgroundType == .tavern {
                    RadialGradient(
                        colors: [Color(hex: "F59E0B").opacity(lampPulse ? 0.22 : 0.12), Color.clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 260
                    )
                    .ignoresSafeArea()
                    
                    RadialGradient(
                        colors: [Color(hex: "EF4444").opacity(lampPulse ? 0.10 : 0.05), Color.clear],
                        center: .topTrailing,
                        startRadius: 10,
                        endRadius: 180
                    )
                    .ignoresSafeArea()
                }
                
                // Clan Hall soft glowing candle spots
                if backgroundType == .clanHall {
                    ForEach(0..<3) { idx in
                        RadialGradient(
                            colors: [Color(hex: "FCD34D").opacity(lampPulse ? 0.25 : 0.12), Color.clear],
                            center: UnitPoint(x: 0.25 + CGFloat(idx) * 0.25, y: 0.35 + CGFloat(idx % 2) * 0.08),
                            startRadius: 4,
                            endRadius: 60
                        )
                    }
                    .ignoresSafeArea()
                }
                
                // Horizontally moving fog banks for Mountain event
                if backgroundType == .mountain {
                    LinearGradient(
                        colors: [Color.white.opacity(0.0), Color.white.opacity(0.06), Color.white.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 100)
                    .offset(x: fogOffset, y: geo.size.height * 0.45)
                    .blur(radius: 15)
                }
                
                // Sweeping spotlights for Gladiator Arena
                if backgroundType == .arena {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: geo.size.width * 0.35, y: geo.size.height))
                        path.addLine(to: CGPoint(x: geo.size.width * 0.50, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Color.white.opacity(0.04), Color.clear], startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(spotlightAngle), anchor: .topLeading)
                    .ignoresSafeArea()
                    
                    Path { path in
                        path.move(to: CGPoint(x: geo.size.width, y: 0))
                        path.addLine(to: CGPoint(x: geo.size.width * 0.65, y: geo.size.height))
                        path.addLine(to: CGPoint(x: geo.size.width * 0.50, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Color.white.opacity(0.04), Color.clear], startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(-spotlightAngle * 0.8), anchor: .topTrailing)
                    .ignoresSafeArea()
                }
                
                // Overlay 1: Floating Clouds (village, general, mountain only)
                if backgroundType == .general || backgroundType == .village || backgroundType == .mountain {
                    Group {
                        CloudShape()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 200, height: 80)
                            .offset(x: cloudOffset1, y: geo.size.height * 0.15)
                        
                        CloudShape()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 300, height: 110)
                            .offset(x: cloudOffset2, y: geo.size.height * 0.22)
                    }
                }
                
                // Overlay 2: Wind Streaks (animated line paths - general, castle, mountain)
                if backgroundType == .general || backgroundType == .castle || backgroundType == .mountain {
                    Path { path in
                        path.move(to: CGPoint(x: 50, y: geo.size.height * 0.3))
                        path.addQuadCurve(to: CGPoint(x: geo.size.width - 50, y: geo.size.height * 0.35), control: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.25))
                        
                        path.move(to: CGPoint(x: -20, y: geo.size.height * 0.45))
                        path.addQuadCurve(to: CGPoint(x: geo.size.width + 20, y: geo.size.height * 0.48), control: CGPoint(x: geo.size.width * 0.6, y: geo.size.height * 0.42))
                    }
                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                    .opacity(windOpacity)
                }
                
                // Overlay 3: Blowing Leaves / Particles (Custom by type)
                CanvasParticleOverlay(type: backgroundType, screenSize: geo.size)
                
                // Overlay 4: Swaying Vector Pine Trees (silhouettes in bottom corners - forest/general/castle/mountain)
                if backgroundType != .village {
                    HStack {
                        // Left tree
                        PineTreeShape()
                            .fill(Color(hex: backgroundType == .castle ? "1F0F0F" : "060B11").opacity(0.95))
                            .frame(width: 80, height: 160)
                            .rotationEffect(.degrees(treeSway), anchor: .bottom)
                            .offset(y: 10)
                        
                        Spacer()
                        
                        // Right tree (larger)
                        PineTreeShape()
                            .fill(Color(hex: backgroundType == .castle ? "1F0F0F" : "060B11").opacity(0.95))
                            .frame(width: 110, height: 220)
                            .rotationEffect(.degrees(-treeSway * 0.8), anchor: .bottom)
                            .offset(y: 10)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
        }
    }
    
    private func loadProjectImage() -> PlatformImage? {
        let name = backgroundType.rawValue
        if let bundleImage = PlatformImage(named: name) {
            return bundleImage
        }
        let path = "/Users/ilakazdan/Documents/fitness-rpg /rpg-tracker/rpg-tracker/Assets/\(name).png"
        return PlatformImage(contentsOfFile: path)
    }
    
    private func startAnimations() {
        // Slow float for clouds
        withAnimation(Animation.linear(duration: 45).repeatForever(autoreverses: false)) {
            cloudOffset1 = 450
        }
        withAnimation(Animation.linear(duration: 60).repeatForever(autoreverses: false)) {
            cloudOffset2 = 550
        }
        
        // Wind gusts pulsation
        withAnimation(Animation.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            windOpacity = 0.4
        }
        
        // Pine trees swaying back and forth
        withAnimation(Animation.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            treeSway = 1.8 // Sway angle in degrees
        }
        
        withAnimation(Animation.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            lampPulse = true
        }
        withAnimation(Animation.linear(duration: 28).repeatForever(autoreverses: false)) {
            fogOffset = 500
        }
        withAnimation(Animation.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
            spotlightAngle = 8
        }
    }
}

// Seed structure for stateless Canvas particles
struct ParticleSeed {
    let index: Int
    let initialXPercent: CGFloat
    let initialYPercent: CGFloat
    let speedXPercent: CGFloat
    let speedYPercent: CGFloat
    let size: CGSize
    let color: Color
    let glowRadius: CGFloat
    let isLeaf: Bool
    let isRounded: Bool
    let opacitySeed: Double
}

// Optimized Canvas-based Particle Overlay (stateless rendering)
struct CanvasParticleOverlay: View {
    let type: BackgroundType
    let screenSize: CGSize
    
    private let seeds: [ParticleSeed]
    
    init(type: BackgroundType, screenSize: CGSize) {
        self.type = type
        self.screenSize = screenSize
        
        var tempSeeds: [ParticleSeed] = []
        for i in 0..<12 {
            let speedMult = Double(i % 4 + 1) * 0.7
            
            // Deterministic sizes based on index
            let pSize: CGSize
            switch type {
            case .forest, .trainingRuins:
                let s = CGFloat(4 + (i % 5))
                pSize = CGSize(width: s, height: s)
            case .castle, .clanHall:
                pSize = CGSize(width: CGFloat(3 + (i % 3)), height: CGFloat(5 + (i % 5)))
            case .village:
                let s = CGFloat(7 + (i % 6))
                pSize = CGSize(width: s, height: s)
            case .mountain, .arena:
                let s = CGFloat(3 + (i % 4))
                pSize = CGSize(width: s, height: s)
            case .general, .tavern, .shop:
                let s = CGFloat(8 + (i % 6))
                pSize = CGSize(width: s, height: s)
            }
            
            let color: Color
            let glowRadius: CGFloat
            var isLeaf = false
            var isRounded = false
            
            switch type {
            case .forest:
                color = (i % 2 == 0) ? Color(hex: "10B981") : Color(hex: "3B82F6")
                glowRadius = 6
            case .castle:
                color = (i % 2 == 0) ? Theme.danger : Theme.warning
                glowRadius = 4
                isRounded = true
            case .village:
                color = Color(hex: "F472B6")
                glowRadius = 0
                isLeaf = true
            case .mountain:
                color = Color(hex: "F59E0B")
                glowRadius = 4
            case .general:
                color = (i % 2 == 0) ? Theme.archerColor : Theme.healerColor
                glowRadius = 0
                isLeaf = true
            case .tavern:
                color = (i % 2 == 0) ? Color(hex: "F59E0B") : Color(hex: "EF4444")
                glowRadius = 5
                isRounded = true
            case .arena:
                color = (i % 2 == 0) ? Color(hex: "F59E0B") : Color(hex: "D97706")
                glowRadius = 4
            case .trainingRuins:
                color = (i % 2 == 0) ? Color(hex: "10B981") : Color(hex: "34D399")
                glowRadius = 6
                isLeaf = true
            case .clanHall:
                color = (i % 2 == 0) ? Color(hex: "F59E0B") : Color(hex: "60A5FA")
                glowRadius = 7
            case .shop:
                color = (i % 2 == 0) ? Color(hex: "F59E0B") : Color(hex: "60A5FA")
                glowRadius = 6
                isRounded = true
            }
            
            let speedX: CGFloat
            let speedY: CGFloat
            switch type {
            case .castle, .clanHall, .shop:
                speedX = 0.02
                speedY = -0.05
            case .tavern:
                speedX = 0.03
                speedY = -0.08
            case .arena:
                speedX = 0.08
                speedY = -0.18
            case .forest, .trainingRuins:
                speedX = 0.05
                speedY = 0.05
            default:
                speedX = 0.12
                speedY = 0.08
            }
            
            tempSeeds.append(ParticleSeed(
                index: i,
                initialXPercent: CGFloat(Double((i * 17 + 23) % 100) / 100.0),
                initialYPercent: CGFloat(Double((i * 13 + 37) % 100) / 100.0),
                speedXPercent: CGFloat(speedMult * speedX),
                speedYPercent: CGFloat(speedMult * speedY),
                size: pSize,
                color: color,
                glowRadius: glowRadius,
                isLeaf: isLeaf,
                isRounded: isRounded,
                opacitySeed: Double(0.4 + Double(i % 5) * 0.1)
            ))
        }
        self.seeds = tempSeeds
    }
    
    var body: some View {
        #if targetEnvironment(simulator)
        // Completely stateless static drawing for Xcode Simulator to bypass redraw lag
        Canvas { context, size in
            drawParticles(in: &context, size: size, time: 0)
        }
        .ignoresSafeArea()
        #else
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                drawParticles(in: &context, size: size, time: time)
            }
        }
        .ignoresSafeArea()
        #endif
    }
    
    private func drawParticles(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for seed in seeds {
            // Linear movement over time with wrap-around boundaries
            let elapsed = CGFloat(time.truncatingRemainder(dividingBy: 10000))
            let moveX = seed.speedXPercent * 120 * elapsed
            let moveY = seed.speedYPercent * 120 * elapsed
            
            let startX = seed.initialXPercent * size.width
            let startY = seed.initialYPercent * size.height
            
            var x = (startX + moveX).truncatingRemainder(dividingBy: size.width + 60) - 30
            var y = (startY + moveY).truncatingRemainder(dividingBy: size.height + 60) - 30
            
            // Specific direction wrap-around overrides
            if y < -30 {
                y = size.height + 30 - (abs(y + 30).truncatingRemainder(dividingBy: size.height + 60))
            }
            if x < -30 {
                x = size.width + 30 - (abs(x + 30).truncatingRemainder(dividingBy: size.width + 60))
            }
            
            let rect = CGRect(x: x, y: y, width: seed.size.width, height: seed.size.height)
            
            context.drawLayer { ctx in
                // Oscillate opacity slightly to create dynamic twinkling
                let wave = sin(time * 2.0 + Double(seed.index)) * 0.15
                ctx.opacity = max(0.2, min(0.95, seed.opacitySeed + wave))
                
                if seed.glowRadius > 0 {
                    ctx.addFilter(.shadow(color: seed.color, radius: seed.glowRadius, x: 0, y: 0))
                }
                
                if seed.isLeaf {
                    var path = Path()
                    path.addEllipse(in: rect)
                    ctx.fill(path, with: .color(seed.color))
                } else {
                    var path = Path()
                    if seed.isRounded {
                        path.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
                    } else {
                        path.addEllipse(in: rect)
                    }
                    ctx.fill(path, with: .color(seed.color))
                }
            }
        }
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: platformImage)
        #endif
    }
}

extension View {
    func loadLocalAvatar(named name: String) -> PlatformImage? {
        let resolvedName = name == "avatar_swordsman" ? "avatar_knight" : name
        if let bundleImage = PlatformImage(named: resolvedName) {
            return bundleImage
        }
        let path = "/Users/ilakazdan/Documents/fitness-rpg /rpg-tracker/rpg-tracker/Assets/\(resolvedName).png"
        return PlatformImage(contentsOfFile: path)
    }
}


// Custom Vector shapes for rendering HUD animation layers
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 0.2), control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.4))
        path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.minY), control: CGPoint(x: rect.minX + rect.width * 0.45, y: rect.minY + rect.height * 0.1))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.minX + rect.width * 0.85, y: rect.minY + rect.height * 0.3))
        path.closeSubpath()
        return path
    }
}

struct PineTreeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.5, y: 0)) // peak
        path.addLine(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.4))
        path.addLine(to: CGPoint(x: rect.width * 0.35, y: rect.height * 0.4))
        
        path.addLine(to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.75))
        path.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.height * 0.75))
        
        // trunk
        path.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width * 0.6, y: rect.height))
        
        path.addLine(to: CGPoint(x: rect.width * 0.6, y: rect.height * 0.75))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.75))
        
        path.addLine(to: CGPoint(x: rect.width * 0.65, y: rect.height * 0.4))
        path.addLine(to: CGPoint(x: rect.width * 0.85, y: rect.height * 0.4))
        
        path.closeSubpath()
        return path
    }
}

// Optimized Star dots drawer (caches static positions to eliminate drawing lag)
struct StarsOverlay: View {
    @State private var starPoints: [CGPoint] = []
    @State private var starSizes: [CGFloat] = []
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                for index in 0..<starPoints.count {
                    guard index < starSizes.count else { break }
                    let pt = starPoints[index]
                    let size = starSizes[index]
                    let scaledX = pt.x * geo.size.width
                    let scaledY = pt.y * geo.size.height * 0.4
                    path.addEllipse(in: CGRect(x: scaledX, y: scaledY, width: size, height: size))
                }
            }
            .fill(Color.white.opacity(0.45))
            .onAppear {
                if starPoints.isEmpty {
                    var points: [CGPoint] = []
                    var sizes: [CGFloat] = []
                    for _ in 0..<35 {
                        points.append(CGPoint(x: CGFloat.random(in: 0.01...0.99), y: CGFloat.random(in: 0.01...0.99)))
                        sizes.append(CGFloat.random(in: 1...2.5))
                    }
                    self.starPoints = points
                    self.starSizes = sizes
                }
            }
        }
    }
}
