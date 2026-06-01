import Foundation
import HealthKit
import CoreLocation

@MainActor
class HealthKitService: ObservableObject {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKSeriesType.workoutRoute(),
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Returns raw HKWorkout objects (no HR enrichment) — used for route queries.
    func fetchHKWorkouts(year: Int) async throws -> [HKWorkout] {
        let calendar = Calendar.current
        var startComps = DateComponents()
        startComps.year = year; startComps.month = 1; startComps.day = 1
        let start = calendar.date(from: startComps)!
        var endComps = DateComponents()
        endComps.year = year + 1; endComps.month = 1; endComps.day = 1
        let end = calendar.date(from: endComps)!
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
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

    func fetchWorkouts(year: Int) async throws -> [Workout] {
        let calendar = Calendar.current
        var startComps = DateComponents()
        startComps.year = year; startComps.month = 1; startComps.day = 1
        let start = calendar.date(from: startComps)!
        var endComps = DateComponents()
        endComps.year = year + 1; endComps.month = 1; endComps.day = 1
        let end = calendar.date(from: endComps)!

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
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
                predicate: HKQuery.predicateForWorkouts(with: .running),
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

    func fetchWorkoutsMultiYear(years: [Int]) async throws -> [Int: [Workout]] {
        var result: [Int: [Workout]] = [:]
        for year in years {
            result[year] = try await fetchWorkouts(year: year)
        }
        return result
    }

    // MARK: - Route-based best effort splits

    struct FullRouteData {
        let coordinates: [CLLocationCoordinate2D]
        // [distanceMeters: best-split segment coordinates], one entry per qualifying distance
        let segmentsByDistance: [Double: [CLLocationCoordinate2D]]
        // [distanceMeters: split seconds]
        let splitsByDistance: [Double: TimeInterval]
    }

    /// Fetches the route once and computes split times + highlight segments for every
    /// distance the workout covers. Lets the detail view switch highlights without refetching.
    func fetchFullRouteData(for hkWorkout: HKWorkout, distances: [Double]) async -> FullRouteData {
        let locations = (try? await fetchFilteredLocations(for: hkWorkout)) ?? []
        let coords = locations.map { $0.coordinate }
        guard locations.count >= 2 else {
            return FullRouteData(coordinates: coords, segmentsByDistance: [:], splitsByDistance: [:])
        }
        let splits = bestSplits(locations: locations, distances: distances)
        var segments: [Double: [CLLocationCoordinate2D]] = [:]
        for dist in distances where splits[dist] != nil {
            let segment = bestSplitSegment(locations: locations, distance: dist)
            if segment.count > 1 { segments[dist] = segment.map { $0.coordinate } }
        }
        return FullRouteData(coordinates: coords, segmentsByDistance: segments, splitsByDistance: splits)
    }

    /// Returns best split time (seconds) for each requested distance (meters),
    /// computed by sliding a window along the GPS route.
    /// Returns nil for distances the workout doesn't cover.
    func fetchRouteSplits(
        for hkWorkout: HKWorkout,
        distances: [Double]
    ) async throws -> [Double: TimeInterval] {
        let locations = try await fetchFilteredLocations(for: hkWorkout)
        guard locations.count >= 2 else { return [:] }
        return bestSplits(locations: locations, distances: distances)
    }

    // MARK: - Shared route helpers

    private func fetchFilteredLocations(for hkWorkout: HKWorkout) async throws -> [CLLocation] {
        let routeType = HKSeriesType.workoutRoute()
        let routeSamples: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
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
        }
        guard let route = routeSamples.first else { return [] }

        var locations: [CLLocation] = []
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                if let error { continuation.resume(throwing: error); return }
                if let newLocations { locations.append(contentsOf: newLocations) }
                if done { continuation.resume() }
            }
            store.execute(query)
        }
        locations.sort { $0.timestamp < $1.timestamp }
        return locations
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
            // For each right, shrink from the left to the *smallest* window that still
            // covers targetDist. We only ever measure windows that genuinely span the
            // full distance — never extrapolate a short segment up to the target.
            for right in 1 ..< locations.count {
                while left + 1 < right, cumDist[right] - cumDist[left + 1] >= targetDist {
                    left += 1
                }
                let windowDist = cumDist[right] - cumDist[left]
                guard windowDist >= targetDist else { continue }
                let windowTime = locations[right].timestamp.timeIntervalSince(locations[left].timestamp)
                guard windowTime > 1 else { continue }
                // Scale down from the (slightly-over) window to exactly targetDist.
                let scaledTime = windowTime * (targetDist / windowDist)
                if scaledTime < best { best = scaledTime }
            }
            if best < .infinity { results[targetDist] = best }
        }
        return results
    }

    /// Returns the subset of locations corresponding to the fastest window for a single distance.
    private func bestSplitSegment(locations: [CLLocation], distance targetDist: Double) -> [CLLocation] {
        var cumDist = [Double](repeating: 0, count: locations.count)
        for i in 1 ..< locations.count {
            cumDist[i] = cumDist[i - 1] + locations[i].distance(from: locations[i - 1])
        }
        guard (cumDist.last ?? 0) >= targetDist else { return [] }

        var bestTime: TimeInterval = .infinity
        var bestLeft = 0, bestRight = 0
        var left = 0

        for right in 1 ..< locations.count {
            while left + 1 < right, cumDist[right] - cumDist[left + 1] >= targetDist { left += 1 }
            let windowDist = cumDist[right] - cumDist[left]
            guard windowDist >= targetDist else { continue }
            let windowTime = locations[right].timestamp.timeIntervalSince(locations[left].timestamp)
            guard windowTime > 1 else { continue }
            let scaledTime = windowTime * (targetDist / windowDist)
            if scaledTime < bestTime {
                bestTime = scaledTime
                bestLeft = left
                bestRight = right
            }
        }
        guard bestTime < .infinity, bestRight > bestLeft else { return [] }
        return Array(locations[bestLeft ... bestRight])
    }
}
