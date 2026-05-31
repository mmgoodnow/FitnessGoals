import Foundation

struct GoalSettings: Codable {
    var sportType: String
    var yearlyGoalMiles: Double
    var hrPercentile: Double = 0.999

    static let defaultSettings = GoalSettings(sportType: "Running", yearlyGoalMiles: 500)
}
