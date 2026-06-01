import Foundation

/// Persistent cache mapping workout UUID → (distanceID → best split seconds).
/// Stored as JSON in the app's Caches directory so it survives app restarts
/// but can be cleared by the OS under disk pressure.
final class BestEffortCache {
    static let shared = BestEffortCache()

    /// Bump this whenever the set of target distances changes — invalidates all cached entries.
    static let currentVersion = 6

    private struct Payload: Codable {
        var version: Int
        var splits: [String: [String: Double]]
    }

    // [workoutUUID: [distanceID: seconds]]
    private var store: [String: [String: Double]] = [:]
    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("best_effort_cache_v2.json")
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


    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.version == Self.currentVersion
        else { return }  // wrong version → start fresh
        store = payload.splits
    }

    private func save() {
        let payload = Payload(version: Self.currentVersion, splits: store)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
