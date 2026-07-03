import WidgetKit
import SwiftUI
import ActivityKit

@main
struct FitRPGWidgetBundle: WidgetBundle {
    var body: some Widget {
        CharacterProgressWidget()
        FitRPGLiveActivity()
    }
}

extension View {
    @ViewBuilder func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            self.background(backgroundView)
        }
    }
}

struct CharacterProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> CharacterProgressEntry {
        CharacterProgressEntry(date: Date(), level: 5, xp: 250, nextLevelXp: 500, gold: 120, className: "MAGE", color: .blue)
    }

    func getSnapshot(in context: Context, completion: @escaping (CharacterProgressEntry) -> Void) {
        let entry = CharacterProgressEntry(date: Date(), level: 5, xp: 250, nextLevelXp: 500, gold: 120, className: "MAGE", color: .blue)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CharacterProgressEntry>) -> Void) {
        // AppGroup user defaults should be used here, but we will use placeholders until configured
        let entry = CharacterProgressEntry(
            date: Date(),
            level: 1,
            xp: 0,
            nextLevelXp: 100,
            gold: 0,
            className: "HERO",
            color: .green
        )
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct CharacterProgressEntry: TimelineEntry {
    let date: Date
    let level: Int
    let xp: Int
    let nextLevelXp: Int
    let gold: Int
    let className: String
    let color: Color
}

struct CharacterProgressWidgetEntryView : View {
    var entry: CharacterProgressProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LEVEL \(entry.level) \(entry.className)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.6))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(entry.color)
                        .frame(width: CGFloat(entry.xp) / CGFloat(max(1, entry.nextLevelXp)) * geo.size.width)
                }
            }
            .frame(height: 10)
            
            Text("\(entry.xp) / \(entry.nextLevelXp) XP")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            HStack(spacing: 4) {
                Image(systemName: "centsign.circle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
                Text("\(entry.gold) GOLD")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }
            .padding(.top, 4)
        }
        .padding()
        .widgetBackground(Color(red: 0.1, green: 0.1, blue: 0.15))
    }
}

struct CharacterProgressWidget: Widget {
    let kind: String = "CharacterProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CharacterProgressProvider()) { entry in
            CharacterProgressWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Character Progress")
        .description("Track your RPG Fitness character's level and XP.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
