import SwiftUI

struct Theme {
    // Curated dark-mode theme colors
    static let background = Color(hex: "0B0E14") // Sleek deep space dark blue/black
    static let cardBackground = Color(hex: "171C26") // Lighter card background
    static let secondaryCard = Color(hex: "232B3A")
    
    // Core Brand / Class Colors
    static let primary = Color(hex: "3B82F6") // Radiant blue
    static let accent = Color(hex: "6366F1") // Indigo
    
    // Class-specific hues
    static let archerColor = Color(hex: "10B981") // Emerald green
    static let mageColor = Color(hex: "8B5CF6") // Mystical Purple
    static let swordsmanColor = Color(hex: "EF4444") // Crimson Red
    static let healerColor = Color(hex: "F59E0B") // Amber gold
    
    // Status Colors
    static let success = Color(hex: "10B981")
    static let danger = Color(hex: "EF4444")
    static let warning = Color(hex: "F59E0B")
    static let info = Color(hex: "3B82F6")
    
    // Neutral Text Colors
    static let textPrimary = Color(hex: "F9FAFB") // Off-white
    static let textSecondary = Color(hex: "9CA3AF") // Gray 400
    static let textMuted = Color(hex: "6B7280") // Gray 500
    
    // Border / Outline
    static let border = Color(hex: "1F2937").opacity(0.6)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Custom Premium Modifiers
struct GlassmorphicCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct Glow: ViewModifier {
    var color: Color
    var radius: CGFloat = 8
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius / 2, x: 0, y: 0)
    }
}

extension View {
    func glassmorphicCard() -> some View {
        self.modifier(GlassmorphicCard())
    }
    
    func glow(color: Color, radius: CGFloat = 8) -> some View {
        self.modifier(Glow(color: color, radius: radius))
    }
    
    func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        return self.navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }
    
    func hideNavigationBar() -> some View {
        #if os(iOS)
        return self.navigationBarHidden(true)
        #else
        return self
        #endif
    }
}

// Satisfying tactile click bounce button style
struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.0))
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// Custom Pill-style Segmented Picker with animatable class-colored highlights
struct PillSegmentPicker: View {
    @Binding var selection: Int
    let items: [String]
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { idx in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selection = idx
                    }
                }) {
                    Text(items[idx])
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(selection == idx ? Color.black : Theme.textSecondary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if selection == idx {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(accentColor)
                                        .glow(color: accentColor.opacity(0.4), radius: 6)
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// TOUCH-REACTIVE 3D TILT EFFECT MODIFIER
public struct TiltCardModifier: ViewModifier {
    public var maxTiltAngle: Double = 15
    @State private var dragOffset: CGSize = .zero
    
    public init(maxTiltAngle: Double = 15) {
        self.maxTiltAngle = maxTiltAngle
    }
    
    public func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(Double(dragOffset.width / 15)),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .rotation3DEffect(
                .degrees(Double(-dragOffset.height / 15)),
                axis: (x: 1.0, y: 0.0, z: 0.0)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(.interactiveSpring()) {
                            let w = max(-maxTiltAngle * 15, min(maxTiltAngle * 15, value.translation.width))
                            let h = max(-maxTiltAngle * 15, min(maxTiltAngle * 15, value.translation.height))
                            dragOffset = CGSize(width: w, height: h)
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                            dragOffset = .zero
                        }
                    }
            )
    }
}

extension View {
    public func tilt(maxAngle: Double = 15) -> some View {
        self.modifier(TiltCardModifier(maxTiltAngle: maxAngle))
    }
}

// MARK: - D&D Corner Border Frame Modifier

struct DndBorderModifier: ViewModifier {
    let color: Color
    let length: CGFloat
    let lineWidth: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Path { path in
                        // Top-Left corner
                        path.move(to: CGPoint(x: 0, y: length))
                        path.addLine(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: length, y: 0))
                        
                        // Top-Right corner
                        path.move(to: CGPoint(x: geo.size.width - length, y: 0))
                        path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                        path.addLine(to: CGPoint(x: geo.size.width, y: length))
                        
                        // Bottom-Right corner
                        path.move(to: CGPoint(x: geo.size.width, y: geo.size.height - length))
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.addLine(to: CGPoint(x: geo.size.width - length, y: geo.size.height))
                        
                        // Bottom-Left corner
                        path.move(to: CGPoint(x: length, y: geo.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geo.size.height - length))
                    }
                    .stroke(color, lineWidth: lineWidth)
                }
            )
    }
}

extension View {
    func dndBorder(color: Color = Color(hex: "D97706"), length: CGFloat = 14, lineWidth: CGFloat = 1.5) -> some View {
        self.modifier(DndBorderModifier(color: color, length: length, lineWidth: lineWidth))
    }
}


