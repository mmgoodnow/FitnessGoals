import SwiftUI
import Charts

// IQR-based outlier removal + domain padding — always returns lo <= hi
private func cleanDomain(_ values: [Double], pad: Double = 0.10) -> ClosedRange<Double> {
    guard values.count >= 2 else {
        let v = values.first ?? 0
        let delta = max(abs(v) * 0.1, 1)
        return (v - delta) ... (v + delta)
    }
    let sorted = values.sorted()
    let q1 = sorted[sorted.count / 4]
    let q3 = sorted[sorted.count * 3 / 4]
    let iqr = q3 - q1
    let lo = q1 - 1.5 * iqr
    let hi = q3 + 1.5 * iqr
    let inliers = values.filter { $0 >= lo && $0 <= hi }
    let mn = inliers.min() ?? sorted.first!
    let mx = inliers.max() ?? sorted.last!
    let span = max(mx - mn, 1)
    return (mn - span * pad) ... (mx + span * pad)
}

private func removeOutliers<T>(_ points: [T], value: (T) -> Double) -> [T] {
    guard points.count >= 4 else { return points }
    let vals = points.map(value).sorted()
    let q1 = vals[vals.count / 4]
    let q3 = vals[vals.count * 3 / 4]
    let iqr = q3 - q1
    let lo = q1 - 1.5 * iqr
    let hi = q3 + 1.5 * iqr
    return points.filter { value($0) >= lo && value($0) <= hi }
}

// Pace over time (this year, per workout)
struct PaceTrendView: View {
    @EnvironmentObject var vm: DashboardViewModel

    private var points: [DashboardViewModel.WorkoutTrendPoint] {
        let raw = vm.workoutTrends.filter { $0.paceMinPerMile != nil }
        return removeOutliers(raw) { $0.paceMinPerMile! }
    }

    // Negate pace so faster (smaller) values appear higher on chart
    private var negatedPoints: [(point: DashboardViewModel.WorkoutTrendPoint, negPace: Double)] {
        points.map { ($0, -$0.paceMinPerMile!) }
    }

    private var domain: ClosedRange<Double> {
        let d = cleanDomain(points.map { -$0.paceMinPerMile! })
        return d
    }

    var body: some View {
        CardView(title: "Pace This Year", systemImage: "stopwatch", accentColor: .orange) {
            if points.isEmpty {
                Text("No data").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(negatedPoints, id: \.point.id) { item in
                    PointMark(
                        x: .value("Date", item.point.date),
                        y: .value("Min/mi", item.negPace)
                    )
                    .foregroundStyle(.orange.opacity(0.7))
                    .symbolSize(30)

                    if points.count > 1 {
                        LineMark(
                            x: .value("Date", item.point.date),
                            y: .value("Min/mi", item.negPace)
                        )
                        .foregroundStyle(.orange.opacity(0.3))
                        .interpolationMethod(.monotone)
                    }
                }
                .chartYScale(domain: domain)
                .chartYAxis {
                    AxisMarks(position: .trailing) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel {
                            // val is negative; display as positive pace
                            if let v = val.as(Double.self) {
                                let pos = -v
                                let m = Int(pos); let s = Int((pos - Double(m)) * 60)
                                Text(String(format: "%d:%02d", m, s)).font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel(format: .dateTime.month(.abbreviated)).font(.caption2)
                    }
                }
                .frame(height: 160)
            }
        }
    }
}

// Heart rate over time (this year, per workout)
struct HeartRateTrendView: View {
    @EnvironmentObject var vm: DashboardViewModel

    private var points: [DashboardViewModel.WorkoutTrendPoint] {
        let raw = vm.workoutTrends.filter { $0.heartRate != nil }
        return removeOutliers(raw) { $0.heartRate! }
    }

    private var domain: ClosedRange<Double> {
        cleanDomain(points.map { $0.heartRate! })
    }

    var body: some View {
        CardView(title: "Avg Heart Rate This Year", systemImage: "heart.fill", accentColor: .red) {
            if points.isEmpty {
                Text("No heart rate data").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(points) { p in
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("BPM", p.heartRate!)
                    )
                    .foregroundStyle(.red.opacity(0.7))
                    .symbolSize(30)

                    if points.count > 1 {
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("BPM", p.heartRate!)
                        )
                        .foregroundStyle(.red.opacity(0.3))
                        .interpolationMethod(.monotone)
                    }
                }
                .chartYScale(domain: domain)
                .chartYAxis {
                    AxisMarks(position: .trailing) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel {
                            Text("\(val.as(Int.self) ?? 0)").font(.caption2)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel(format: .dateTime.month(.abbreviated)).font(.caption2)
                    }
                }
                .frame(height: 160)
            }
        }
    }
}

// Estimated VO2 over time (this year, per workout)
struct VO2TrendView: View {
    @EnvironmentObject var vm: DashboardViewModel

    private var points: [DashboardViewModel.WorkoutTrendPoint] {
        let raw = vm.workoutTrends.filter { $0.vo2 != nil }
        return removeOutliers(raw) { $0.vo2! }
    }

    private var domain: ClosedRange<Double> {
        cleanDomain(points.map { $0.vo2! })
    }

    var body: some View {
        CardView(title: "Est. VO₂ This Year", systemImage: "lungs.fill", accentColor: .purple) {
            if points.isEmpty {
                Text("No data").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(points) { p in
                    AreaMark(
                        x: .value("Date", p.date),
                        yStart: .value("Base", domain.lowerBound),
                        yEnd: .value("VO₂", p.vo2!)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.purple.opacity(0.3), .purple.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("VO₂", p.vo2!)
                    )
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                }
                .chartYScale(domain: domain)
                .chartYAxis {
                    AxisMarks(position: .trailing) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel {
                            Text(String(format: "%.0f", val.as(Double.self) ?? 0)).font(.caption2)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel(format: .dateTime.month(.abbreviated)).font(.caption2)
                    }
                }
                .frame(height: 160)

                Text("Estimated from pace via ACSM equation (ml/kg/min)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
