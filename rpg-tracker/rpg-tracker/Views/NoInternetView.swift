import SwiftUI

struct NoInternetView: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var showRetryFlash = false

    var body: some View {
        ZStack {
            backgroundLayer
            VStack(spacing: 0) {
                Spacer()
                iconSection
                    .padding(.bottom, 40)
                titleSection
                    .padding(.bottom, 44)
                statusCard
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)
                retryButton
                    .padding(.horizontal, 32)
                Spacer()
                Text("Waiting for connection...")
                    .font(.caption2)
                    .foregroundColor(Color(white: 0.3))
                    .tracking(1)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseScale = 1.6
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.10)
                .ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color(red: 0.6, green: 0.1, blue: 0.1).opacity(isAnimating ? 0.22 : 0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)
        }
    }

    private var iconSection: some View {
        ZStack {
            Circle()
                .stroke(Color.red.opacity(0.12), lineWidth: 2)
                .frame(width: 180, height: 180)
                .scaleEffect(pulseScale)

            Circle()
                .stroke(Color.red.opacity(0.22), lineWidth: 1.5)
                .frame(width: 130, height: 130)
                .scaleEffect(max(1.0, pulseScale * 0.85))

            Circle()
                .fill(Color(red: 0.15, green: 0.05, blue: 0.05))
                .frame(width: 100, height: 100)
                .overlay(Circle().stroke(Color.red.opacity(0.4), lineWidth: 1.5))

            Image(systemName: "wifi.slash")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.35, blue: 0.35),
                                 Color(red: 0.8, green: 0.1, blue: 0.1)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: .red.opacity(0.6), radius: 12)
        }
    }

    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("NO CONNECTION")
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(colors: [.white, Color(white: 0.75)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .tracking(4)
                .shadow(color: .red.opacity(0.3), radius: 8)

            Text("RPG Fitness requires an internet\nconnection to sync your battles,\nprogress, and clan data.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 40)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .foregroundColor(.red.opacity(0.8))
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text("Network Status")
                    .font(.caption2)
                    .foregroundColor(Color(white: 0.45))
                    .tracking(1)
                Text("Disconnected")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red.opacity(0.9))
            }

            Spacer()

            HStack(spacing: 3) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red.opacity(isAnimating ? 0.25 : 0.1))
                        .frame(width: 5, height: CGFloat(8 + i * 5))
                        .animation(
                            .easeInOut(duration: 0.5).delay(Double(i) * 0.12).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.2), lineWidth: 1))
        )
    }

    private var retryButton: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.15)) { showRetryFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation { showRetryFlash = false }
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold))
                Text("RETRY CONNECTION")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(1.5)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(retryButtonBackground)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.35), lineWidth: 1))
            .shadow(color: .red.opacity(0.2), radius: 12)
        }
    }

    private var retryButtonBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                showRetryFlash
                    ? AnyShapeStyle(Color.red.opacity(0.5))
                    : AnyShapeStyle(LinearGradient(
                        colors: [Color(red: 0.55, green: 0.05, blue: 0.05),
                                 Color(red: 0.35, green: 0.02, blue: 0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            )
    }
}

#Preview {
    NoInternetView()
}
