import SwiftUI

struct CameraTrackingView: View {
    @StateObject private var viewModel: CameraTrackingVM
    @Environment(\.dismiss) private var dismiss
    
    init(selectedClass: CharacterClass) {
        _viewModel = StateObject(wrappedValue: CameraTrackingVM(selectedClass: selectedClass))
    }
    
    var body: some View {
        ZStack {
            // Camera feed backdrop (black placeholder or simulated space)
            Color.black
                .ignoresSafeArea()
            
            // Neon space grid background when simulating
            if viewModel.isSimulatorMode {
                SimulatedCameraFeed(points: viewModel.skeletonPoints, lines: viewModel.skeletonLines)
            } else {
                // Real camera placeholder
                VStack {
                    Spacer()
                    Image(systemName: "camera.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.textMuted)
                    Text("Camera Feed Active")
                        .font(.headline)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 8)
                    Text("Align your entire body in frame")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                    Spacer()
                }
                
                // Draw real skeleton keypoints overlay if detected
                GeometryReader { geo in
                    ZStack {
                        ForEach(viewModel.skeletonLines) { line in
                            Path { path in
                                path.move(to: CGPoint(x: line.start.x * geo.size.width, y: line.start.y * geo.size.height))
                                path.addLine(to: CGPoint(x: line.end.x * geo.size.width, y: line.end.y * geo.size.height))
                            }
                            .stroke(viewModel.selectedClass.themeColor, lineWidth: 4)
                            .glow(color: viewModel.selectedClass.themeColor.opacity(0.8), radius: 6)
                        }
                        
                        ForEach(viewModel.skeletonPoints) { pt in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .position(x: pt.point.x * geo.size.width, y: pt.point.y * geo.size.height)
                                .shadow(color: viewModel.selectedClass.themeColor, radius: 4)
                        }
                    }
                }
            }
            
            // HUD Overlay Controls
            VStack {
                // Top controls bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Exercise indicator
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(viewModel.selectedClass.themeColor)
                        Text(viewModel.selectedClass.primaryExercise.uppercased())
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    // Mode Toggle (Simulator vs Camera)
                    Toggle("Sim", isOn: $viewModel.isSimulatorMode)
                        .toggleStyle(ButtonToggleStyle(color: viewModel.selectedClass.themeColor))
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Live Feedback Prompt
                HStack(spacing: 12) {
                    Circle()
                        .fill(viewModel.isPersonDetected || viewModel.isSimulatorMode ? Theme.success : Theme.danger)
                        .frame(width: 10, height: 10)
                        .glow(color: viewModel.isPersonDetected || viewModel.isSimulatorMode ? Theme.success : Theme.danger)
                    
                    Text(viewModel.feedbackMessage)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(viewModel.isCorrectForm ? Color.black.opacity(0.6) : Theme.danger.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(viewModel.isCorrectForm ? Theme.border : Theme.danger, lineWidth: 1)
                )
                .padding(.top, 16)
                
                Spacer()
                
                // Huge reps display
                VStack(spacing: 0) {
                    Text("\(viewModel.repCount)")
                        .font(.system(size: 96, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: viewModel.selectedClass.themeColor.opacity(0.6), radius: 15)
                    
                    Text("REPS COMPLETED")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textSecondary)
                        .tracking(3)
                }
                
                Spacer()
                
                // Bottom control actions
                if viewModel.isSimulatorMode {
                    Button(action: {
                        viewModel.simulateRep()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("SIMULATE REPETITION")
                                .fontWeight(.bold)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 32)
                        .background(viewModel.selectedClass.themeColor)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                        .shadow(color: viewModel.selectedClass.themeColor.opacity(0.5), radius: 10, y: 5)
                    }
                    .padding(.bottom, 30)
                } else {
                    // Guidance state info for physical setup
                    VStack(spacing: 8) {
                        Text("Ensure whole body is visible")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("Avoid shadows & backlit environments")
                            .font(.caption2)
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// Simulated skeletal line drawer
struct SimulatedCameraFeed: View {
    let points: [JointPoint]
    let lines: [BoneLine]
    
    var body: some View {
        ZStack {
            // Neon starry space grid background
            Theme.background
                .ignoresSafeArea()
            
            // Ambient glow backdrops
            RadialGradient(
                colors: [Theme.accent.opacity(0.15), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            // Grid lines overlay
            GeometryReader { geo in
                Path { path in
                    let gridSpacing: CGFloat = 40
                    for x in stride(from: 0, to: geo.size.width, by: gridSpacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: 0, to: geo.size.height, by: gridSpacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Theme.border.opacity(0.3), lineWidth: 0.5)
            }
            
            // Render simulated avatar bones
            GeometryReader { geo in
                ZStack {
                    ForEach(lines) { line in
                        Path { path in
                            path.move(to: CGPoint(x: line.start.x * geo.size.width, y: line.start.y * geo.size.height))
                            path.addLine(to: CGPoint(x: line.end.x * geo.size.width, y: line.end.y * geo.size.height))
                        }
                        .stroke(Theme.primary, lineWidth: 5)
                        .glow(color: Theme.primary.opacity(0.6), radius: 8)
                    }
                    
                    ForEach(points) { pt in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .position(x: pt.point.x * geo.size.width, y: pt.point.y * geo.size.height)
                            .shadow(color: Theme.primary, radius: 6)
                    }
                }
            }
        }
    }
}

// Custom button style toggle setup
struct ButtonToggleStyle: ToggleStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack {
                Image(systemName: configuration.isOn ? "cpu.fill" : "camera.fill")
                Text(configuration.isOn ? "SIM" : "LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isOn ? color : Color.black.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}

struct CameraTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        CameraTrackingView(selectedClass: .swordsman)
    }
}
