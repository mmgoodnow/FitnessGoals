import Foundation
import HealthKit

struct Workout: Identifiable {
    let id: UUID
    let startDate: Date
    let distance: Double  // meters
    let duration: TimeInterval  // seconds
    let workoutType: HKWorkoutActivityType
    var avgHeartRate: Double?  // bpm, filled in after fetch

    var paceSecondsPerMeter: Double? {
        guard distance > 0 else { return nil }
        return duration / distance
    }

    // Jack Daniels VO2 estimate from pace (ml/kg/min)
    var estimatedVO2: Double? {
        guard let spm = paceSecondsPerMeter, spm > 0 else { return nil }
        let metersPerMin = 60.0 / spm
        // ACSM running equation
        let vo2 = 0.2 * metersPerMin + 0.9 * metersPerMin * 0.01 + 3.5
        return vo2
    }
}

extension Workout {
    init(hkWorkout: HKWorkout) {
        self.id = hkWorkout.uuid
        self.startDate = hkWorkout.startDate
        self.distance = hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0
        self.duration = hkWorkout.duration
        self.workoutType = hkWorkout.workoutActivityType
        self.avgHeartRate = nil
    }
}
