import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var historicalWorkouts: [Int: [Workout]] = [:]
    @Published var isLoading = false
    @Published var error: String?
    @Published var sport: SportType = .running
    @Published var yearlyGoalMiles: Double = 500

    private let healthKit = HealthKitService()
    private let currentYear = Calendar.current.component(.year, from: Date())

    private let settingsKey = "goalSettings"

    init() {
        loadSettings()
    }

    // MARK: - Settings persistence

    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(GoalSettings.self, from: data) {
            sport = SportType(rawValue: settings.sportType) ?? .running
            yearlyGoalMiles = settings.yearlyGoalMiles
        }
    }

    func saveSettings() {
        let settings = GoalSettings(sportType: sport.rawValue, yearlyGoalMiles: yearlyGoalMiles)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    // MARK: - Data loading

    func load() async {
        guard healthKit.isAvailable else {
            error = "HealthKit is not available on this device."
            return
        }
        isLoading = true
        error = nil
        do {
            try await healthKit.requestAuthorization(for: sport)
            async let current = healthKit.fetchWorkouts(sport: sport, year: currentYear)
            let years = (currentYear - 4 ..< currentYear).map { $0 }
            async let historical = healthKit.fetchWorkoutsMultiYear(sport: sport, years: years)
            workouts = try await current
            historicalWorkouts = try await historical
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func changeSport(_ newSport: SportType) {
        sport = newSport
        yearlyGoalMiles = newSport.defaultGoalMiles
        saveSettings()
        Task { await load() }
    }

    func setGoal(_ miles: Double) {
        yearlyGoalMiles = miles
        saveSettings()
    }

    // MARK: - Computed stats

    var totalDistanceMeters: Double {
        workouts.reduce(0) { $0 + $1.distance }
    }

    var totalMiles: Double {
        Formatters.miles(totalDistanceMeters)
    }

    var progressFraction: Double {
        min(totalMiles / yearlyGoalMiles, 1.0)
    }

    var dayOfYear: Int {
        Formatters.dayOfYear(Date())
    }

    var daysInYear: Int {
        let isLeap = (currentYear % 4 == 0 && currentYear % 100 != 0) || currentYear % 400 == 0
        return isLeap ? 366 : 365
    }

    var daysRemaining: Int {
        max(daysInYear - dayOfYear, 0)
    }

    var targetMilesToDate: Double {
        yearlyGoalMiles * Double(dayOfYear) / Double(daysInYear)
    }

    var milesAheadBehind: Double {
        totalMiles - targetMilesToDate
    }

    var requiredDailyMiles: Double {
        guard daysRemaining > 0 else { return 0 }
        return max(yearlyGoalMiles - totalMiles, 0) / Double(daysRemaining)
    }

    var weeklyAverageMiles: Double {
        guard dayOfYear > 0 else { return 0 }
        return totalMiles / (Double(dayOfYear) / 7.0)
    }

    // MARK: - Weekly chart data

    struct WeekPoint: Identifiable {
        let id: Int
        let week: Int
        let miles: Double
    }

    var weeklyData: [WeekPoint] {
        var byWeek: [Int: Double] = [:]
        for w in workouts {
            let week = Formatters.weekOfYear(w.startDate)
            byWeek[week, default: 0] += Formatters.miles(w.distance)
        }
        return byWeek.map { WeekPoint(id: $0.key, week: $0.key, miles: $0.value) }
            .sorted { $0.week < $1.week }
    }

    // MARK: - Cumulative progress chart

    struct ProgressPoint: Identifiable {
        let id: Int
        let day: Int
        let actual: Double?
        let target: Double
    }

    var progressData: [ProgressPoint] {
        var cumulative = 0.0
        var byDay: [Int: Double] = [:]
        for w in workouts {
            let day = Formatters.dayOfYear(w.startDate)
            byDay[day, default: 0] += Formatters.miles(w.distance)
        }
        var points: [ProgressPoint] = []
        for day in 1 ... daysInYear {
            if let miles = byDay[day] { cumulative += miles }
            let target = yearlyGoalMiles * Double(day) / Double(daysInYear)
            let actual: Double? = day <= dayOfYear ? cumulative : nil
            points.append(ProgressPoint(id: day, day: day, actual: actual, target: target))
        }
        return points
    }

    // MARK: - Weekday average chart

    struct WeekdayPoint: Identifiable {
        let id: Int
        let label: String
        let runCount: Int
        let runFrequency: Double   // fraction of that weekday's occurrences where I ran
        let avgMilesWhenRan: Double  // avg distance on days I did run
    }

    var weekdayData: [WeekdayPoint] {
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var totals = [Double](repeating: 0, count: 7)
        var runCounts = [Int](repeating: 0, count: 7)
        var calendarCounts = [Int](repeating: 0, count: 7)
        let calendar = Calendar.current
        var yearStart = DateComponents()
        yearStart.year = currentYear; yearStart.month = 1; yearStart.day = 1
        let start = calendar.date(from: yearStart)!
        for offset in 0 ..< dayOfYear {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            calendarCounts[Formatters.weekdayIndex(day)] += 1
        }
        for w in workouts {
            let i = Formatters.weekdayIndex(w.startDate)
            totals[i] += Formatters.miles(w.distance)
            runCounts[i] += 1
        }
        return (0..<7).map { i in
            WeekdayPoint(
                id: i,
                label: labels[i],
                runCount: runCounts[i],
                runFrequency: calendarCounts[i] > 0 ? Double(runCounts[i]) / Double(calendarCounts[i]) : 0,
                avgMilesWhenRan: runCounts[i] > 0 ? totals[i] / Double(runCounts[i]) : 0
            )
        }
    }

    // MARK: - Per-workout trend data (pace, HR, VO2)

    struct WorkoutTrendPoint: Identifiable {
        let id: UUID
        let date: Date
        let paceMinPerMile: Double?
        let heartRate: Double?
        let vo2: Double?
    }

    var workoutTrends: [WorkoutTrendPoint] {
        workouts
            .filter { $0.distance > 800 }  // skip very short efforts
            .sorted { $0.startDate < $1.startDate }
            .map { w in
                let paceMinPerMile: Double?
                if let spm = w.paceSecondsPerMeter {
                    paceMinPerMile = spm * 1609.344 / 60.0
                } else {
                    paceMinPerMile = nil
                }
                return WorkoutTrendPoint(
                    id: w.id,
                    date: w.startDate,
                    paceMinPerMile: paceMinPerMile,
                    heartRate: w.avgHeartRate,
                    vo2: w.estimatedVO2
                )
            }
    }

    // MARK: - Year-over-year pace analysis

    struct YearPacePoint: Identifiable {
        let id: Int
        let year: Int
        let avgPaceSecondsPerMeter: Double?
        let totalMiles: Double
    }

    var paceAnalysisData: [YearPacePoint] {
        let allYears = historicalWorkouts.keys.sorted() + [currentYear]
        return allYears.map { year in
            let ws = year == currentYear ? workouts : (historicalWorkouts[year] ?? [])
            let filtered = ws.filter { $0.distance > 400 }
            let totalMeters = filtered.reduce(0.0) { $0 + $1.distance }
            let totalSeconds = filtered.reduce(0.0) { $0 + $1.duration }
            return YearPacePoint(
                id: year,
                year: year,
                avgPaceSecondsPerMeter: totalMeters > 0 ? totalSeconds / totalMeters : nil,
                totalMiles: Formatters.miles(totalMeters)
            )
        }
    }
}
