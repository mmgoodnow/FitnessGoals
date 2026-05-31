import Foundation
import HealthKit

struct Workout: Identifiable {
    let id: UUID
    let startDate: Date
    let distance: Double  // meters
    let duration: TimeInterval  // seconds
    let workoutType: HKWorkoutActivityType

    var paceSecondsPerMeter: Double? {
        guard distance > 0 else { return nil }
        return duration / distance
    }
}

extension Workout {
    init(hkWorkout: HKWorkout) {
        self.id = hkWorkout.uuid
        self.startDate = hkWorkout.startDate
        self.distance = hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0
        self.duration = hkWorkout.duration
        self.workoutType = hkWorkout.workoutActivityType
    }
}
