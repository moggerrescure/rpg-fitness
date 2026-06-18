import SwiftUI

struct AnimatedBackgroundView: View {
    @State private var cloudOffset1: CGFloat = -100
    @State private var cloudOffset2: CGFloat = -200
    @State private var windOpacity: Double = 0.2
    @State private var leafRotation: Double = 0
    @State private var leafOffset = CGPoint(x: -50, y: 100)
    @State private var treeSway: Double = 0.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base background image loaded from project assets or bundle path
                if let uiImage = loadProjectImage() {
                    Image(uiImage: uiImage)
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
                
                // Overlay 1: Floating Clouds
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
                
                // Overlay 2: Wind Streaks (animated line paths)
                Path { path in
                    path.move(to: CGPoint(x: 50, y: geo.size.height * 0.3))
                    path.addQuadCurve(to: CGPoint(x: geo.size.width - 50, y: geo.size.height * 0.35), control: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.25))
                    
                    path.move(to: CGPoint(x: -20, y: geo.size.height * 0.45))
                    path.addQuadCurve(to: CGPoint(x: geo.size.width + 20, y: geo.size.height * 0.48), control: CGPoint(x: geo.size.width * 0.6, y: geo.size.height * 0.42))
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                .opacity(windOpacity)
                
                // Overlay 3: Blowing Leaves / Particles
                ForEach(0..<6) { index in
                    LeafParticle(
                        color: index % 2 == 0 ? Theme.archerColor : Theme.healerColor,
                        speed: Double(index + 1) * 0.8,
                        screenSize: geo.size
                    )
                }
                
                // Overlay 4: Swaying Vector Pine Trees (silhouettes in bottom corners)
                HStack {
                    // Left tree
                    PineTreeShape()
                        .fill(Color(hex: "060B11").opacity(0.95))
                        .frame(width: 80, height: 160)
                        .rotationEffect(.degrees(treeSway), anchor: .bottom)
                        .offset(y: 10)
                    
                    Spacer()
                    
                    // Right tree (larger)
                    PineTreeShape()
                        .fill(Color(hex: "060B11").opacity(0.95))
                        .frame(width: 110, height: 220)
                        .rotationEffect(.degrees(-treeSway * 0.8), anchor: .bottom)
                        .offset(y: 10)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
        }
    }
    
    private func loadProjectImage() -> UIImage? {
        // First try to load from main app bundle (if user compiled assets)
        if let bundleImage = UIImage(named: "rpg_bg_wilderness") {
            return bundleImage
        }
        // Second try to load from the absolute path where we copied it (very useful for dev simulator loading!)
        let path = "/Users/ilakazdan/Documents/fitness-rpg/FitRPG/Assets/rpg_bg_wilderness.png"
        return UIImage(contentsOfFile: path)
    }
    
    private func startAnimations() {
        // Slow float for clouds
        withAnimation(Animation.linear(duration: 45).repeatForever(autoreverses: false)) {
            cloudOffset1 = 400
        }
        withAnimation(Animation.linear(duration: 60).repeatForever(autoreverses: false)) {
            cloudOffset2 = 500
        }
        
        // Wind gusts pulsation
        withAnimation(Animation.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            windOpacity = 0.4
        }
        
        // Pine trees swaying back and forth
        withAnimation(Animation.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            treeSway = 1.8 // Sway angle in degrees
        }
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
        // Simple layered triangle tree representation
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

// Particle elements drifting diagonally across screen
struct LeafParticle: View {
    let color: Color
    let speed: Double
    let screenSize: CGSize
    
    @State private var xOffset: CGFloat = CGFloat.random(in: -50...300)
    @State private var yOffset: CGFloat = CGFloat.random(in: -50...400)
    @State private var rotation: Double = Double.random(in: 0...360)
    
    var body: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: CGFloat.random(in: 8...14)))
            .foregroundColor(color.opacity(0.4))
            .rotationEffect(.degrees(rotation))
            .position(x: xOffset, y: yOffset)
            .onAppear {
                withAnimation(Animation.linear(duration: 12.0 / speed).repeatForever(autoreverses: false)) {
                    xOffset = screenSize.width + 50
                    yOffset = yOffset + CGFloat.random(in: 100...250)
                    rotation = rotation + 360
                }
            }
    }
}

// Star dots drawer
struct StarsOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                for _ in 0..<35 {
                    let x = CGFloat.random(in: 0...geo.size.width)
                    let y = CGFloat.random(in: 0...geo.size.height * 0.4)
                    let size = CGFloat.random(in: 1...2.5)
                    path.addEllipse(in: CGRect(x: x, y: y, width: size, height: size))
                }
            }
            .fill(Color.white.opacity(0.45))
        }
    }
}
