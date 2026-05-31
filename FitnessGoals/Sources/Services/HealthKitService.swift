import Foundation
import HealthKit

@MainActor
class HealthKitService: ObservableObject {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(for sport: SportType) async throws {
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchWorkouts(sport: SportType, year: Int) async throws -> [Workout] {
        let calendar = Calendar.current
        var startComps = DateComponents()
        startComps.year = year
        startComps.month = 1
        startComps.day = 1
        let start = calendar.date(from: startComps)!
        var endComps = DateComponents()
        endComps.year = year + 1
        endComps.month = 1
        endComps.day = 1
        let end = calendar.date(from: endComps)!

        let predicate = HKQuery.predicateForWorkouts(with: sport.hkWorkoutType)
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: compound,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout] ?? []).map(Workout.init)
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    func fetchWorkoutsMultiYear(sport: SportType, years: [Int]) async throws -> [Int: [Workout]] {
        var result: [Int: [Workout]] = [:]
        for year in years {
            result[year] = try await fetchWorkouts(sport: sport, year: year)
        }
        return result
    }
}
