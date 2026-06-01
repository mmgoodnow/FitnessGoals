import Foundation

struct GoalSettings: Codable {
    var yearlyGoalMiles: Double
    var hrPercentile: Double = 0.999

    static let defaultSettings = GoalSettings(yearlyGoalMiles: 500)
}
