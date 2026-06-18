import SwiftUI

// Custom shapes for programmatic emblem backgrounds
struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: width, y: height * 0.2))
        path.addQuadCurve(to: CGPoint(x: width * 0.9, y: height * 0.7), control: CGPoint(x: width * 0.95, y: height * 0.45))
        path.addQuadCurve(to: CGPoint(x: width / 2, y: height), control: CGPoint(x: width * 0.7, y: height * 0.95))
        path.addQuadCurve(to: CGPoint(x: width * 0.1, y: height * 0.7), control: CGPoint(x: width * 0.3, y: height * 0.95))
        path.addQuadCurve(to: CGPoint(x: 0, y: height * 0.2), control: CGPoint(x: width * 0.05, y: height * 0.45))
        path.closeSubpath()
        return path
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width / 2, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height / 2))
        path.closeSubpath()
        return path
    }
}

struct OctagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let side = w * 0.2929
        
        path.move(to: CGPoint(x: side, y: 0))
        path.addLine(to: CGPoint(x: w - side, y: 0))
        path.addLine(to: CGPoint(x: w, y: side))
        path.addLine(to: CGPoint(x: w, y: h - side))
        path.addLine(to: CGPoint(x: w - side, y: h))
        path.addLine(to: CGPoint(x: side, y: h))
        path.addLine(to: CGPoint(x: 0, y: h - side))
        path.addLine(to: CGPoint(x: 0, y: side))
        path.closeSubpath()
        return path
    }
}

struct TeardropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addCurve(to: CGPoint(x: w, y: h * 0.7), control1: CGPoint(x: w * 0.8, y: h * 0.3), control2: CGPoint(x: w, y: h * 0.5))
        path.addArc(center: CGPoint(x: w / 2, y: h * 0.7), radius: w / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(to: CGPoint(x: w / 2, y: 0), control1: CGPoint(x: 0, y: h * 0.5), control2: CGPoint(x: w * 0.2, y: h * 0.3))
        path.closeSubpath()
        return path
    }
}

struct ClanEmblemView: View {
    let emblem: String
    var size: CGFloat = 56
    var isSelected: Bool = false
    
    var body: some View {
        ZStack {
            // Background Shape & Gradient
            emblemBackground
                .frame(width: size, height: size)
                .shadow(color: shadowColor, radius: isSelected ? 8 : 4)
                .glow(color: isSelected ? (emblemColors.first ?? Theme.primary).opacity(0.6) : Color.clear, radius: 8)
            
            // Icon
            Image(systemName: iconName)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
        }
        .frame(width: size, height: size)
    }
    
    // Renders the background shape with specific gradients & strokes
    @ViewBuilder
    private var emblemBackground: some View {
        if emblem == "shield.fill" {
            ShieldShape()
                .fill(LinearGradient(colors: emblemColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(ShieldShape().stroke(borderGradient, lineWidth: 1.5))
        } else if emblem == "bolt.fill" {
            DiamondShape()
                .fill(LinearGradient(colors: emblemColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(DiamondShape().stroke(borderGradient, lineWidth: 1.5))
        } else if emblem == "crown.fill" {
            OctagonShape()
                .fill(LinearGradient(colors: emblemColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(OctagonShape().stroke(borderGradient, lineWidth: 1.5))
        } else if emblem == "drop.fill" {
            TeardropShape()
                .fill(LinearGradient(colors: emblemColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(TeardropShape().stroke(borderGradient, lineWidth: 1.5))
        } else if emblem == "leaf.fill" {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: emblemColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).stroke(borderGradient, lineWidth: 1.5))
        } else if emblem == "heart.fill" {
            Circle()
                .fill(LinearGradient(colors: emblemColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(borderGradient, lineWidth: 1.5))
        } else if emblem == "flame.fill" {
            // Flame uses a slightly rounded hexagon or pentagon/circle
            Circle()
                .fill(LinearGradient(colors: emblemColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(borderGradient, lineWidth: 1.5))
        } else {
            // default wand or any other
            Circle()
                .fill(LinearGradient(colors: emblemColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(borderGradient, lineWidth: 1.5))
        }
    }
    
    private var iconName: String {
        switch emblem {
        case "shield.fill": return "shield.fill"
        case "flame.fill": return "flame.fill"
        case "bolt.fill": return "bolt.fill"
        case "crown.fill": return "crown.fill"
        case "leaf.fill": return "leaf.fill"
        case "drop.fill": return "drop.fill"
        case "heart.fill": return "heart.fill"
        case "wand.and.stars", "wand.fill": return "wand.and.stars"
        default: return "shield.fill"
        }
    }
    
    private var emblemColors: [Color] {
        switch emblem {
        case "shield.fill":
            return [Color(hex: "6B7280"), Color(hex: "1F2937")] // Slate Steel
        case "flame.fill":
            return [Color(hex: "F97316"), Color(hex: "DC2626")] // Flame Orange to Red
        case "bolt.fill":
            return [Color(hex: "FACC15"), Color(hex: "D97706")] // Bright Spark to Amber
        case "crown.fill":
            return [Color(hex: "C084FC"), Color(hex: "6D28D9")] // Amethyst Purple to Royal Violet
        case "leaf.fill":
            return [Color(hex: "34D399"), Color(hex: "047857")] // Mint to Forest Green
        case "drop.fill":
            return [Color(hex: "60A5FA"), Color(hex: "1D4ED8")] // Sky to Deep Ocean Blue
        case "heart.fill":
            return [Color(hex: "F472B6"), Color(hex: "BE185D")] // Rose Pink to Crimson
        case "wand.and.stars", "wand.fill":
            return [Color(hex: "38BDF8"), Color(hex: "4338CA")] // Magic Cyan to Indigo
        default:
            return [Theme.primary, Theme.accent]
        }
    }
    
    private var shadowColor: Color {
        let baseColor = emblemColors.first ?? Color.black
        return isSelected ? baseColor.opacity(0.7) : Color.black.opacity(0.35)
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.6), Color.white.opacity(0.1), Color.black.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
