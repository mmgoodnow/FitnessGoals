import Foundation
import HealthKit

enum SportType: String, CaseIterable, Identifiable {
    case running = "Running"
    case cycling = "Cycling"

    var id: String { rawValue }

    var hkWorkoutType: HKWorkoutActivityType {
        switch self {
        case .running: return .running
        case .cycling: return .cycling
        }
    }

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        }
    }

    var defaultGoalMiles: Double {
        switch self {
        case .running: return 500
        case .cycling: return 2000
        }
    }

    var quickGoals: [Double] {
        switch self {
        case .running: return [100, 250, 500, 750, 1000]
        case .cycling: return [1000, 2000, 3000, 5000, 8000]
        }
    }

    var usesPace: Bool { self == .running }
}
