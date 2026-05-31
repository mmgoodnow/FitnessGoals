import Foundation

/// Persistent cache mapping workout UUID → (distanceID → best split seconds).
/// Stored as JSON in the app's Caches directory so it survives app restarts
/// but can be cleared by the OS under disk pressure.
final class BestEffortCache {
    static let shared = BestEffortCache()

    // [workoutUUID: [distanceID: seconds]]
    private var store: [String: [String: Double]] = [:]
    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("best_effort_cache.json")
        load()
    }

    func splits(for workoutID: UUID) -> [String: Double]? {
        store[workoutID.uuidString]
    }

    func hasCached(_ workoutID: UUID) -> Bool {
        store[workoutID.uuidString] != nil
    }

    func store(splits: [String: Double], for workoutID: UUID) {
        // Filter out zero/bogus times before caching
        let clean = splits.filter { $0.value > 1 }
        store[workoutID.uuidString] = clean
        save()
    }

    /// Remove cache entries that contain any zero times (from a previous buggy fetch).
    func purgeZeroEntries() {
        let before = store.count
        store = store.filter { _, splits in splits.values.allSatisfy { $0 > 1 } }
        if store.count != before { save() }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data)
        else { return }
        store = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
