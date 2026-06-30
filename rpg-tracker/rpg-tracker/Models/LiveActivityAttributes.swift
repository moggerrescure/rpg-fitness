import Foundation
import ActivityKit

public struct FitRPGLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var repCount: Int
        public var bossCurrentHP: Int
        public var bossMaxHP: Int
        public var endDate: Date
        
        public init(repCount: Int, bossCurrentHP: Int, bossMaxHP: Int, endDate: Date) {
            self.repCount = repCount
            self.bossCurrentHP = bossCurrentHP
            self.bossMaxHP = bossMaxHP
            self.endDate = endDate
        }
    }
    
    public var bossName: String?
    public var bossImage: String?
    public var exerciseName: String
    
    public init(bossName: String?, bossImage: String?, exerciseName: String) {
        self.bossName = bossName
        self.bossImage = bossImage
        self.exerciseName = exerciseName
    }
}
