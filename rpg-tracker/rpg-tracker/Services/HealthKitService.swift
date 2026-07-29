import Foundation
import HealthKit
import Combine

struct HealthSyncResult {
    let steps: Int
    let activeCalories: Int
    let workoutMinutes: Int
    
    let xpGained: Int
    let energyGained: Int
    let goldGained: Int
    let damageDealt: Int
}

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    @Published var isAuthorized: Bool = false
    @Published var isSyncing: Bool = false
    
    private let healthStore = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKObjectType.workoutType()
        ]
    }
    
    private init() {
        Task { await refreshAuthorizationStatus() }
    }
    
    var isAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    /// HealthKit does not expose read authorization status directly. We treat the user as connected
    /// after they have completed the authorization prompt (`.unnecessary` request status).
    func refreshAuthorizationStatus() async {
        guard isAvailable else {
            isAuthorized = false
            return
        }

        let status = await withCheckedContinuation { (continuation: CheckedContinuation<HKAuthorizationRequestStatus, Never>) in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
                continuation.resume(returning: status)
            }
        }

        isAuthorized = status == .unnecessary
    }
    
    func requestAuthorization() async throws {
        guard isAvailable else { throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"]) }
        
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        await refreshAuthorizationStatus()
    }
    
    func syncHealthData(since lastSync: Date?) async throws -> HealthSyncResult {
        guard isAuthorized else { throw NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not authorized"]) }
        
        self.isSyncing = true
        defer { self.isSyncing = false }
        
        // If no last sync, fetch for today only to prevent giving 10 years of XP
        let startDate = lastSync ?? Calendar.current.startOfDay(for: Date())
        let endDate = Date()
        
        guard startDate < endDate else {
            return HealthSyncResult(steps: 0, activeCalories: 0, workoutMinutes: 0, xpGained: 0, energyGained: 0, goldGained: 0, damageDealt: 0)
        }
        
        async let steps = fetchSum(for: .stepCount, unit: .count(), start: startDate, end: endDate)
        async let calories = fetchSum(for: .activeEnergyBurned, unit: .kilocalorie(), start: startDate, end: endDate)
        async let workoutMins = fetchWorkoutMinutes(start: startDate, end: endDate)
        
        let totalSteps = try await steps
        let totalCalories = try await calories
        let totalMins = try await workoutMins
        
        // Rules:
        // 10 steps = 1 XP
        // 1 kcal = 5 XP + 1 Energy
        // 1 min workout = 10 XP + 5 Energy + 1 Gold
        
        let xpGained = Int(totalSteps / 10.0) + Int(totalCalories * 5.0) + (totalMins * 10)
        let energyGained = Int(totalCalories) + (totalMins * 5)
        let goldGained = totalMins
        let damageDealt = Int(totalSteps) + (Int(totalCalories) * 10)
        
        return HealthSyncResult(
            steps: Int(totalSteps),
            activeCalories: Int(totalCalories),
            workoutMinutes: totalMins,
            xpGained: xpGained,
            energyGained: energyGained,
            goldGained: goldGained,
            damageDealt: damageDealt
        )
    }
    
    private func fetchSum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let quantityType = HKQuantityType(identifier)
        let samplePredicate = HKSamplePredicate.quantitySample(type: quantityType, predicate: predicate)
        
        let query = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum)
        let result = try await query.result(for: healthStore)
        return result?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
    }
    
    private func fetchWorkoutMinutes(start: Date, end: Date) async throws -> Int {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        
        let workouts = try await descriptor.result(for: healthStore)
        let totalDuration = workouts.reduce(0.0) { $0 + $1.duration }
        return Int(totalDuration / 60.0)
    }
}
