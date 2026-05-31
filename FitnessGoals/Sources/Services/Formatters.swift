import Foundation

enum Formatters {
    static func miles(_ meters: Double) -> Double {
        meters / 1609.344
    }

    static func formatMiles(_ meters: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f mi", miles(meters))
    }

    static func formatPace(_ secondsPerMeter: Double) -> String {
        let secondsPerMile = secondsPerMeter * 1609.344
        let minutes = Int(secondsPerMile) / 60
        let seconds = Int(secondsPerMile) % 60
        return String(format: "%d:%02d /mi", minutes, seconds)
    }

    static func formatSpeed(_ secondsPerMeter: Double) -> String {
        guard secondsPerMeter > 0 else { return "— mph" }
        let metersPerSecond = 1.0 / secondsPerMeter
        let mph = metersPerSecond * 2.23694
        return String(format: "%.1f mph", mph)
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    static func dayOfYear(_ date: Date) -> Int {
        Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    static func weekOfYear(_ date: Date) -> Int {
        Calendar.current.component(.weekOfYear, from: date)
    }

    static func weekdayIndex(_ date: Date) -> Int {
        // 0 = Monday
        let raw = Calendar.current.component(.weekday, from: date)
        return (raw + 5) % 7
    }
}
