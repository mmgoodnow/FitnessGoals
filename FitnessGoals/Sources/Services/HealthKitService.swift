import Foundation
import HealthKit
import CoreLocation

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
            HKSeriesType.workoutRoute(),
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Returns raw HKWorkout objects (no HR enrichment) — used for route queries.
    func fetchHKWorkouts(sport: SportType, year: Int) async throws -> [HKWorkout] {
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
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(), predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            store.execute(query)
        }
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

    struct HRPercentileResult {
        let bpm: Double      // value at this percentile × 1.03 fudge
        let samplesAbove: Int  // number of raw samples above this percentile
    }

    /// Fetches all instantaneous HR samples during workouts and computes requested percentiles.
    func fetchWorkoutHRPercentiles(_ percentiles: [Double]) async throws -> [Double: HRPercentileResult] {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let workoutSamples: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: NSCompoundPredicate(orPredicateWithSubpredicates: [
                    HKQuery.predicateForWorkouts(with: .running),
                    HKQuery.predicateForWorkouts(with: .cycling),
                ]),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            store.execute(query)
        }
        guard !workoutSamples.isEmpty else { return [:] }

        let workoutPredicate = NSCompoundPredicate(orPredicateWithSubpredicates:
            workoutSamples.map {
                HKQuery.predicateForSamples(withStart: $0.startDate, end: $0.endDate, options: .strictStartDate)
            }
        )

        let hrSamples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: workoutPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            store.execute(query)
        }
        guard !hrSamples.isEmpty else { return [:] }

        let bpms = hrSamples
            .map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
            .sorted()
        let n = bpms.count

        var result: [Double: HRPercentileResult] = [:]
        for p in percentiles {
            let idx = Int(Double(n - 1) * p)
            let value = bpms[idx] * 1.03
            let samplesAbove = n - 1 - idx
            result[p] = HRPercentileResult(bpm: value, samplesAbove: samplesAbove)
        }
        return result
    }

    func fetchWorkoutsMultiYear(sport: SportType, years: [Int]) async throws -> [Int: [Workout]] {
        var result: [Int: [Workout]] = [:]
        for year in years {
            result[year] = try await fetchWorkouts(sport: sport, year: year)
        }
        return result
    }

    // MARK: - Route-based best effort splits

    /// Fetches the GPS coordinates for a workout route (for map display).
    func fetchRouteCoordinates(for hkWorkout: HKWorkout) async -> [CLLocationCoordinate2D] {
        let routeType = HKSeriesType.workoutRoute()
        let routeSamples: [HKWorkoutRoute] = (try? await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: HKQuery.predicateForObjects(from: hkWorkout),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples as? [HKWorkoutRoute] ?? [])
            }
            store.execute(query)
        }) ?? []
        guard let route = routeSamples.first else { return [] }

        var locations: [CLLocation] = []
        try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                if let error { continuation.resume(throwing: error); return }
                if let newLocations { locations.append(contentsOf: newLocations) }
                if done { continuation.resume() }
            }
            store.execute(query)
        }
        return locations.sorted { $0.timestamp < $1.timestamp }.map { $0.coordinate }
    }

    /// Returns best split time (seconds) for each requested distance (meters),
    /// computed by sliding a window along the GPS route.
    /// Returns nil for distances the workout doesn't cover.
    func fetchRouteSplits(
        for hkWorkout: HKWorkout,
        distances: [Double]
    ) async throws -> [Double: TimeInterval] {
        // 1. Find the workout route
        let routeType = HKSeriesType.workoutRoute()
        let routeSamples: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let pred = HKQuery.predicateForObjects(from: hkWorkout)
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: pred,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples as? [HKWorkoutRoute] ?? [])
            }
            store.execute(query)
        }
        guard let route = routeSamples.first else { return [:] }

        // 2. Stream all CLLocation points from the route
        var locations: [CLLocation] = []
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                if let error { continuation.resume(throwing: error); return }
                if let newLocations { locations.append(contentsOf: newLocations) }
                if done { continuation.resume() }
            }
            store.execute(query)
        }
        guard locations.count >= 2 else { return [:] }

        // Sort by timestamp (should already be sorted, but be safe)
        locations.sort { $0.timestamp < $1.timestamp }

        // Filter out GPS points that imply superhuman speed between consecutive samples.
        // 10 m/s ≈ 6:26/mi — faster than any human road race record.
        let filtered = filterSuperspeedPoints(locations, maxSpeedMS: 10.0)

        // 3. Sliding window: for each target distance find the fastest window
        return bestSplits(locations: filtered, distances: distances)
    }

    /// Removes points where the speed from the previous retained point exceeds maxSpeedMS.
    /// Uses a greedy forward pass — if a point is too fast, drop it and check the next.
    private func filterSuperspeedPoints(_ locations: [CLLocation], maxSpeedMS: Double) -> [CLLocation] {
        guard !locations.isEmpty else { return [] }
        var result: [CLLocation] = [locations[0]]
        for loc in locations.dropFirst() {
            let prev = result.last!
            let dt = loc.timestamp.timeIntervalSince(prev.timestamp)
            let dist = loc.distance(from: prev)
            guard dt > 0 else { continue }
            let speed = dist / dt
            if speed <= maxSpeedMS {
                result.append(loc)
            }
            // else: drop this point — it implies car/teleport speed
        }
        return result
    }

    /// Pure computation — walks locations with a two-pointer sliding window.
    private func bestSplits(locations: [CLLocation], distances: [Double]) -> [Double: TimeInterval] {
        // Build cumulative distance array
        var cumDist = [Double](repeating: 0, count: locations.count)
        for i in 1 ..< locations.count {
            cumDist[i] = cumDist[i - 1] + locations[i].distance(from: locations[i - 1])
        }
        let totalDist = cumDist.last ?? 0

        var results: [Double: TimeInterval] = [:]
        for targetDist in distances {
            guard totalDist >= targetDist else { continue }
            var best: TimeInterval = .infinity
            var left = 0
            for right in 1 ..< locations.count {
                // Advance left until window is just under targetDist
                while cumDist[right] - cumDist[left] > targetDist {
                    left += 1
                }
                let windowDist = cumDist[right] - cumDist[left]
                if windowDist > 0 {
                    let windowTime = locations[right].timestamp.timeIntervalSince(locations[left].timestamp)
                    guard windowTime > 1 else { continue }  // skip zero/negative timestamps
                    // Scale to exact target distance
                    let scaledTime = windowTime * (targetDist / windowDist)
                    if scaledTime > 1 && scaledTime < best { best = scaledTime }
                }
            }
            if best < .infinity { results[targetDist] = best }
        }
        return results
    }
}
