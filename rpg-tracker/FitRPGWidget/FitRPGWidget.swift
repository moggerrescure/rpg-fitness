import WidgetKit
import SwiftUI
import ActivityKit

@main
struct FitRPGWidgetBundle: WidgetBundle {
    var body: some Widget {
        FitRPGLiveActivity()
    }
}

struct FitRPGLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FitRPGLiveActivityAttributes.self) { context in
            // Lock Screen UI
            LiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.strengthtraining.functional")
                                .foregroundColor(.green)
                            Text(context.attributes.exerciseName.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("\(context.state.repCount)")
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("REPS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        if let bossName = context.attributes.bossName {
                            Text(bossName.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                            Spacer()
                            Text("\(context.state.bossCurrentHP) HP")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        } else {
                            Text("TRAINING")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                            Spacer()
                            Text("PRACTICE")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        if context.state.bossMaxHP > 0 {
                            let hpProgress = Double(context.state.bossCurrentHP) / Double(context.state.bossMaxHP)
                            ProgressView(value: max(0, min(1, hpProgress)))
                                .tint(.red)
                                .background(Color.red.opacity(0.2))
                        }
                        HStack {
                            Text("Time remaining:")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(context.state.endDate, style: .timer)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.functional")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                    Text("\(context.state.repCount)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                }
            } compactTrailing: {
                if context.state.bossMaxHP > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                        let hpPercent = Int((Double(context.state.bossCurrentHP) / Double(context.state.bossMaxHP)) * 100)
                        Text("\(hpPercent)%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    }
                } else {
                    Text("FIT")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.green)
                }
            } minimal: {
                Text("\(context.state.repCount)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
            }
        }
    }
}

struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<FitRPGLiveActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.exerciseName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    Text("\(context.state.repCount)")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text("REPS COMPLETED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let bossName = context.attributes.bossName {
                        Text(bossName.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                        Text("\(context.state.bossCurrentHP) / \(context.state.bossMaxHP)")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("BOSS HEALTH")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    } else {
                        Text("TRAINING ACTIVE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Text("FREE MODE")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            }
            
            if context.state.bossMaxHP > 0 {
                let hpProgress = Double(context.state.bossCurrentHP) / Double(context.state.bossMaxHP)
                ProgressView(value: max(0, min(1, hpProgress)))
                    .tint(.red)
                    .background(Color.red.opacity(0.15))
            }
        }
        .padding(16)
        .background(Color(red: 0.08, green: 0.09, blue: 0.13))
    }
}
