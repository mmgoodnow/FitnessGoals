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
    @Published var hrPercentiles: [Double: HealthKitService.HRPercentileResult] = [:]
    @Published var selectedHRPercentile: Double = 0.999

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
            selectedHRPercentile = settings.hrPercentile
        }
    }

    func saveSettings() {
        let settings = GoalSettings(sportType: sport.rawValue, yearlyGoalMiles: yearlyGoalMiles, hrPercentile: selectedHRPercentile)
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
            async let percentiles = healthKit.fetchWorkoutHRPercentiles([0.99, 0.999, 0.9999])
            workouts = try await current
            historicalWorkouts = try await historical
            hrPercentiles = try await percentiles
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

    /// Weekly mileage needed over the remaining weeks to finish exactly at goal.
    var weeklyMilesNeeded: Double {
        let weeksRemaining = Double(daysRemaining) / 7.0
        guard weeksRemaining > 0 else { return 0 }
        return max(yearlyGoalMiles - totalMiles, 0) / weeksRemaining
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
        trendPoints(from: workouts)
    }

    var allTimeWorkoutTrends: [WorkoutTrendPoint] {
        let all = historicalWorkouts.values.flatMap { $0 } + workouts
        return trendPoints(from: all)
    }

    private func trendPoints(from source: [Workout]) -> [WorkoutTrendPoint] {
        source
            .filter { $0.distance > 800 }
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

    // MARK: - Best efforts

    struct BestEffortDistance: Identifiable {
        let id: String
        let label: String
        let meters: Double
    }

    static let bestEffortDistances: [BestEffortDistance] = [
        .init(id: "1mi",   label: "1 mi",        meters: 1609.34),
        .init(id: "5k",    label: "5K",           meters: 5000),
        .init(id: "10k",   label: "10K",          meters: 10000),
        .init(id: "half",  label: "Half Marathon", meters: 21097.5),
        .init(id: "full",  label: "Marathon",      meters: 42195),
    ]

    struct BestEffort: Identifiable {
        let id: String          // distance id
        let label: String
        let meters: Double
        let time: TimeInterval  // estimated finish time at avg pace
        let date: Date
        let workoutID: UUID
    }

    /// All-time best effort (fastest avg pace) for each standard distance,
    /// using workouts that are at least that distance.
    var bestEfforts: [BestEffort] {
        let all = (historicalWorkouts.values.flatMap { $0 } + workouts)
            .filter { $0.paceSecondsPerMeter != nil }
        return Self.bestEffortDistances.compactMap { dist in
            let candidates = all.filter { $0.distance >= dist.meters }
            guard let best = candidates.min(by: { $0.paceSecondsPerMeter! < $1.paceSecondsPerMeter! }),
                  let pace = best.paceSecondsPerMeter else { return nil }
            return BestEffort(
                id: dist.id,
                label: dist.label,
                meters: dist.meters,
                time: pace * dist.meters,
                date: best.startDate,
                workoutID: best.id
            )
        }
    }

    struct BestEffortPoint: Identifiable {
        let id: UUID        // workout id
        let date: Date
        let time: TimeInterval
        let isBest: Bool    // true if this is the all-time best at time of workout
    }

    /// Progression of best efforts over time for a given distance.
    func bestEffortProgression(for distanceID: String) -> [BestEffortPoint] {
        guard let dist = Self.bestEffortDistances.first(where: { $0.id == distanceID }) else { return [] }
        let all = (historicalWorkouts.values.flatMap { $0 } + workouts)
            .filter { $0.distance >= dist.meters && $0.paceSecondsPerMeter != nil }
            .sorted { $0.startDate < $1.startDate }
        var best: Double = .infinity
        return all.map { w in
            let t = w.paceSecondsPerMeter! * dist.meters
            let isBest = t < best
            if isBest { best = t }
            return BestEffortPoint(id: w.id, date: w.startDate, time: t, isBest: isBest)
        }
    }

    // MARK: - Most recent workout

    var mostRecentWorkout: Workout? {
        workouts.max(by: { $0.startDate < $1.startDate })
    }

    // MARK: - Max HR estimation

    var estimatedMaxHR: Double {
        hrPercentiles[selectedHRPercentile]?.bpm ?? 190
    }

    func setHRPercentile(_ p: Double) {
        selectedHRPercentile = p
        saveSettings()
    }

    // MARK: - Year-over-year pace analysis

    struct YearPacePoint: Identifiable {
        let id: String
        let year: Int
        let zone: HRZone?      // nil = all zones
        let avgPaceSecondsPerMeter: Double?
        let totalMiles: Double
    }

    /// All years available across current + historical data.
    private var allYears: [Int] {
        historicalWorkouts.keys.sorted() + [currentYear]
    }

    private func workouts(for year: Int) -> [Workout] {
        year == currentYear ? workouts : (historicalWorkouts[year] ?? [])
    }

    /// YoY pace for all workouts (no zone filter).
    var paceAnalysisData: [YearPacePoint] {
        allYears.map { year in
            let ws = workouts(for: year).filter { $0.distance > 400 }
            let totalMeters = ws.reduce(0.0) { $0 + $1.distance }
            let totalSeconds = ws.reduce(0.0) { $0 + $1.duration }
            return YearPacePoint(
                id: "\(year)-all",
                year: year,
                zone: nil,
                avgPaceSecondsPerMeter: totalMeters > 0 ? totalSeconds / totalMeters : nil,
                totalMiles: Formatters.miles(totalMeters)
            )
        }
    }

    /// YoY pace filtered to a specific HR zone.
    func paceAnalysisData(for zone: HRZone) -> [YearPacePoint] {
        let maxHR = estimatedMaxHR
        return allYears.map { year in
            let ws = workouts(for: year).filter { w in
                guard w.distance > 400, let hr = w.avgHeartRate else { return false }
                return HRZone.zone(for: hr, maxHR: maxHR) == zone
            }
            let totalMeters = ws.reduce(0.0) { $0 + $1.distance }
            let totalSeconds = ws.reduce(0.0) { $0 + $1.duration }
            return YearPacePoint(
                id: "\(year)-z\(zone.rawValue)",
                year: year,
                zone: zone,
                avgPaceSecondsPerMeter: totalMeters > 0 ? totalSeconds / totalMeters : nil,
                totalMiles: Formatters.miles(totalMeters)
            )
        }
    }
}
