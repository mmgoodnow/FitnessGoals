import SwiftUI
import Charts

private enum Lookback: String, CaseIterable {
    case thisYear = "This Year"
    case allTime  = "All Time"
}

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

// Centered rolling average over `window` points (shrinks at edges)
private func rollingAverage<T>(_ points: [T], window: Int, value: (T) -> Double) -> [Double] {
    let half = window / 2
    return points.indices.map { i in
        let lo = max(0, i - half)
        let hi = min(points.count - 1, i + half)
        let slice = points[lo ... hi]
        return slice.map(value).reduce(0, +) / Double(slice.count)
    }
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

private struct XAxisMarks: ChartContent {
    let lookback: Lookback

    var body: some ChartContent {
        // just a placeholder — xAxis is applied as a modifier
        LineMark(x: .value("x", 0), y: .value("y", 0)).opacity(0)
    }
}

// MARK: - Pace

struct PaceTrendView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var lookback: Lookback = .thisYear

    private var allPoints: [DashboardViewModel.WorkoutTrendPoint] {
        lookback == .thisYear ? vm.workoutTrends : vm.allTimeWorkoutTrends
    }

    private var points: [DashboardViewModel.WorkoutTrendPoint] {
        let raw = allPoints.filter { $0.paceMinPerMile != nil }
        return removeOutliers(raw) { $0.paceMinPerMile! }
    }

    private var negatedPoints: [(point: DashboardViewModel.WorkoutTrendPoint, negPace: Double)] {
        points.map { ($0, -$0.paceMinPerMile!) }
    }

    private var smoothedNegPace: [Double] {
        rollingAverage(points, window: 20) { -$0.paceMinPerMile! }
    }

    private var domain: ClosedRange<Double> {
        cleanDomain(points.map { -$0.paceMinPerMile! })
    }

    var body: some View {
        CardView(title: "Pace", systemImage: "stopwatch", accentColor: .orange) {
            LookbackPicker(selection: $lookback)

            if points.isEmpty {
                Text("No data").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(negatedPoints, id: \.point.id) { item in
                        PointMark(
                            x: .value("Date", item.point.date),
                            y: .value("Min/mi", item.negPace)
                        )
                        .foregroundStyle(.orange.opacity(lookback == .allTime ? 0.25 : 0.7))
                        .symbolSize(lookback == .allTime ? 15 : 30)
                    }
                    if lookback == .thisYear && points.count > 1 {
                        ForEach(negatedPoints, id: \.point.id) { item in
                            LineMark(
                                x: .value("Date", item.point.date),
                                y: .value("Min/mi", item.negPace)
                            )
                            .foregroundStyle(.orange.opacity(0.3))
                            .interpolationMethod(.monotone)
                        }
                    }
                    if lookback == .allTime {
                        ForEach(Array(zip(points, smoothedNegPace)), id: \.0.id) { pt, val in
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Min/mi", val)
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)
                        }
                    }
                }
                .chartScrollableAxes([]).chartGesture { _ in DragGesture(minimumDistance: .infinity) }
                .chartYScale(domain: domain)
                .chartYAxis {
                    AxisMarks(position: .trailing) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                let pos = -v
                                let m = Int(pos); let s = Int((pos - Double(m)) * 60)
                                Text(String(format: "%d:%02d", m, s)).font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: xAxisStride) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel(format: xAxisFormat).font(.caption2)
                    }
                }
                .frame(height: 160).clipped()
            }
        }
    }

    private var xAxisStride: AxisMarkValues {
        lookback == .thisYear
            ? .stride(by: .month, count: 2)
            : .stride(by: .year, count: 1)
    }

    private var xAxisFormat: Date.FormatStyle {
        lookback == .thisYear
            ? .dateTime.month(.abbreviated)
            : .dateTime.year()
    }
}

// MARK: - Heart Rate

struct HeartRateTrendView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var lookback: Lookback = .thisYear

    private var allPoints: [DashboardViewModel.WorkoutTrendPoint] {
        lookback == .thisYear ? vm.workoutTrends : vm.allTimeWorkoutTrends
    }

    private var points: [DashboardViewModel.WorkoutTrendPoint] {
        let raw = allPoints.filter { $0.heartRate != nil }
        return removeOutliers(raw) { $0.heartRate! }
    }

    private var smoothedHR: [Double] {
        rollingAverage(points, window: 20) { $0.heartRate! }
    }

    private var domain: ClosedRange<Double> {
        cleanDomain(points.map { $0.heartRate! })
    }

    var body: some View {
        CardView(title: "Avg Heart Rate", systemImage: "heart.fill", accentColor: .red) {
            LookbackPicker(selection: $lookback)

            if points.isEmpty {
                Text("No heart rate data").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(points) { p in
                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("BPM", p.heartRate!)
                        )
                        .foregroundStyle(.red.opacity(lookback == .allTime ? 0.25 : 0.7))
                        .symbolSize(lookback == .allTime ? 15 : 30)
                    }
                    if lookback == .thisYear && points.count > 1 {
                        ForEach(points) { p in
                            LineMark(
                                x: .value("Date", p.date),
                                y: .value("BPM", p.heartRate!)
                            )
                            .foregroundStyle(.red.opacity(0.3))
                            .interpolationMethod(.monotone)
                        }
                    }
                    if lookback == .allTime {
                        ForEach(Array(zip(points, smoothedHR)), id: \.0.id) { pt, val in
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("BPM", val)
                            )
                            .foregroundStyle(.red)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)
                        }
                    }
                }
                .chartScrollableAxes([]).chartGesture { _ in DragGesture(minimumDistance: .infinity) }
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
                    AxisMarks(values: xAxisStride) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel(format: xAxisFormat).font(.caption2)
                    }
                }
                .frame(height: 160).clipped()
            }
        }
    }

    private var xAxisStride: AxisMarkValues {
        lookback == .thisYear
            ? .stride(by: .month, count: 2)
            : .stride(by: .year, count: 1)
    }

    private var xAxisFormat: Date.FormatStyle {
        lookback == .thisYear
            ? .dateTime.month(.abbreviated)
            : .dateTime.year()
    }
}

// MARK: - VO2

struct VO2TrendView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var lookback: Lookback = .thisYear

    private var allPoints: [DashboardViewModel.WorkoutTrendPoint] {
        lookback == .thisYear ? vm.workoutTrends : vm.allTimeWorkoutTrends
    }

    private var points: [DashboardViewModel.WorkoutTrendPoint] {
        let raw = allPoints.filter { $0.vo2 != nil }
        return removeOutliers(raw) { $0.vo2! }
    }

    private var smoothedVO2: [Double] {
        rollingAverage(points, window: 20) { $0.vo2! }
    }

    private var domain: ClosedRange<Double> {
        cleanDomain(points.map { $0.vo2! })
    }

    var body: some View {
        CardView(title: "Est. VO₂", systemImage: "lungs.fill", accentColor: .purple) {
            LookbackPicker(selection: $lookback)

            if points.isEmpty {
                Text("No data").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart {
                    if lookback == .thisYear {
                        ForEach(points) { p in
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
                    } else {
                        ForEach(points) { p in
                            PointMark(
                                x: .value("Date", p.date),
                                y: .value("VO₂", p.vo2!)
                            )
                            .foregroundStyle(.purple.opacity(0.25))
                            .symbolSize(15)
                        }
                        ForEach(Array(zip(points, smoothedVO2)), id: \.0.id) { pt, val in
                            AreaMark(
                                x: .value("Date", pt.date),
                                yStart: .value("Base", domain.lowerBound),
                                yEnd: .value("VO₂", val)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.purple.opacity(0.2), .purple.opacity(0.02)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .interpolationMethod(.monotone)
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("VO₂", val)
                            )
                            .foregroundStyle(.purple)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)
                        }
                    }
                }
                .chartScrollableAxes([]).chartGesture { _ in DragGesture(minimumDistance: .infinity) }
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
                    AxisMarks(values: xAxisStride) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel(format: xAxisFormat).font(.caption2)
                    }
                }
                .frame(height: 160).clipped()

                Text("Estimated from pace via ACSM equation (ml/kg/min)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var xAxisStride: AxisMarkValues {
        lookback == .thisYear
            ? .stride(by: .month, count: 2)
            : .stride(by: .year, count: 1)
    }

    private var xAxisFormat: Date.FormatStyle {
        lookback == .thisYear
            ? .dateTime.month(.abbreviated)
            : .dateTime.year()
    }
}

// MARK: - Shared picker

private struct LookbackPicker: View {
    @Binding var selection: Lookback

    var body: some View {
        Picker("Lookback", selection: $selection) {
            ForEach(Lookback.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 8)
    }
}
