import Foundation
import ActivityKit

@MainActor
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()
    
    private init() {}
    
    private var activeActivity: Activity<FitRPGLiveActivityAttributes>? = nil
    
    public func startLiveActivity(
        bossName: String?,
        bossImage: String?,
        exerciseName: String,
        initialReps: Int,
        bossCurrentHP: Int,
        bossMaxHP: Int,
        endDate: Date
    ) {
        // End any active activity first
        let currentActivity = activeActivity
        if currentActivity != nil {
            Task {
                await endLiveActivity()
            }
        }
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled.")
            return
        }
        
        let attributes = FitRPGLiveActivityAttributes(
            bossName: bossName,
            bossImage: bossImage,
            exerciseName: exerciseName
        )
        
        let initialContentState = FitRPGLiveActivityAttributes.ContentState(
            repCount: initialReps,
            bossCurrentHP: bossCurrentHP,
            bossMaxHP: bossMaxHP,
            endDate: endDate
        )
        
        let activityContent = ActivityContent(
            state: initialContentState,
            staleDate: nil,
            relevanceScore: 100
        )
        
        do {
            activeActivity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            print("Successfully requested Live Activity: \(activeActivity?.id ?? "nil")")
        } catch {
            print("Error requesting Live Activity: \(error.localizedDescription)")
        }
    }
    
    public func updateLiveActivity(
        repCount: Int,
        bossCurrentHP: Int,
        bossMaxHP: Int,
        endDate: Date
    ) {
        guard let activity = activeActivity else { return }
        
        let updatedContentState = FitRPGLiveActivityAttributes.ContentState(
            repCount: repCount,
            bossCurrentHP: bossCurrentHP,
            bossMaxHP: bossMaxHP,
            endDate: endDate
        )
        
        let activityContent = ActivityContent(
            state: updatedContentState,
            staleDate: nil,
            relevanceScore: 100
        )
        
        Task {
            await activity.update(activityContent)
        }
    }
    
    public func endLiveActivity() async {
        guard let activity = activeActivity else { return }
        
        let finalContentState = activity.content.state
        let finalContent = ActivityContent(state: finalContentState, staleDate: nil)
        
        await activity.end(finalContent, dismissalPolicy: .immediate)
        activeActivity = nil
        print("Live Activity ended.")
    }
}
