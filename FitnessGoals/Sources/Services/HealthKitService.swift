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
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchWorkouts(sport: SportType, year: Int) async throws -> [Workout] {
        let calendar = Calendar.current
        var startComps = DateComponents()
        startComps.year = year; startComps.month = 1; startComps.day = 1
        let start = calendar.date(from: startComps)!
        var endComps = DateComponents()
        endComps.year = year + 1; endComps.month = 1; endComps.day = 1
        let end = calendar.date(from: endComps)!

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: sport.hkWorkoutType),
            HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate),
        ])

        let hkWorkouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            store.execute(query)
        }

        var workouts = hkWorkouts.map(Workout.init)
        // Fetch average HR for each workout concurrently
        await withTaskGroup(of: (UUID, Double?).self) { group in
            for hw in hkWorkouts {
                group.addTask {
                    let hr = try? await self.fetchAvgHeartRate(for: hw)
                    return (hw.uuid, hr)
                }
            }
            var hrMap: [UUID: Double] = [:]
            for await (id, hr) in group {
                if let hr { hrMap[id] = hr }
            }
            for i in workouts.indices {
                workouts[i].avgHeartRate = hrMap[workouts[i].id]
            }
        }
        return workouts
    }

    private func fetchAvgHeartRate(for workout: HKWorkout) async throws -> Double? {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                let bpm = stats?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    /// Returns the 95th percentile instantaneous HR across all samples, as a robust max HR estimate.
    func fetchAllTimeMaxHeartRate() async throws -> Double? {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            store.execute(query)
        }
        guard !samples.isEmpty else { return nil }
        let bpms = samples
            .map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
            .sorted()
        let idx = Int(Double(bpms.count - 1) * 0.95)
        return bpms[idx] * 1.03  // ~3% buffer to approximate true max above p95
    }

    func fetchWorkoutsMultiYear(sport: SportType, years: [Int]) async throws -> [Int: [Workout]] {
        var result: [Int: [Workout]] = [:]
        for year in years {
            result[year] = try await fetchWorkouts(sport: sport, year: year)
        }
        return result
    }
}
