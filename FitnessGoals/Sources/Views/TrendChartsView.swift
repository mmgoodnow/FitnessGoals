import SwiftUI
import Charts

// Pace over time (this year, per workout)
struct PaceTrendView: View {
    @EnvironmentObject var vm: DashboardViewModel

    private var points: [DashboardViewModel.WorkoutTrendPoint] {
        vm.workoutTrends.filter { $0.paceMinPerMile != nil }
    }

    var body: some View {
        CardView(title: "Pace This Year", systemImage: "stopwatch", accentColor: .orange) {
            if points.isEmpty {
                Text("No data").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(points) { p in
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("Min/mi", p.paceMinPerMile!)
                    )
                    .foregroundStyle(.orange.opacity(0.7))
                    .symbolSize(30)

                    if points.count > 1 {
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("Min/mi", p.paceMinPerMile!)
                        )
                        .foregroundStyle(.orange.opacity(0.3))
                        .interpolationMethod(.monotone)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                let m = Int(v); let s = Int((v - Double(m)) * 60)
                                Text(String(format: "%d:%02d", m, s)).font(.caption2)
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(reversed: true))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.caption2)
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
        vm.workoutTrends.filter { $0.heartRate != nil }
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
                .chartYAxis {
                    AxisMarks(position: .trailing) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel {
                            Text("\(val.as(Int.self) ?? 0) bpm").font(.caption2)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.caption2)
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
        vm.workoutTrends.filter { $0.vo2 != nil }
    }

    var body: some View {
        CardView(title: "Est. VO₂ This Year", systemImage: "lungs.fill", accentColor: .purple) {
            if points.isEmpty {
                Text("No data").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(points) { p in
                    AreaMark(
                        x: .value("Date", p.date),
                        y: .value("VO₂", p.vo2!)
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
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.caption2)
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
