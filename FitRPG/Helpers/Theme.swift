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
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground.opacity(0.8))
            )
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
}
