import Foundation

struct GoalSettings: Codable {
    var sportType: String
    var yearlyGoalMiles: Double

    static let defaultSettings = GoalSettings(sportType: "Running", yearlyGoalMiles: 500)
}
