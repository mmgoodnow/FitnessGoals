import SwiftUI
import Charts

struct ProgressChartView: View {
    @EnvironmentObject var vm: DashboardViewModel

    // Actual points only (no nils), sampled every 3 days
    private var actualPoints: [(day: Int, miles: Double)] {
        vm.progressData
            .compactMap { p -> (Int, Double)? in
                guard let a = p.actual, p.day % 3 == 0 || p.day == vm.dayOfYear else { return nil }
                return (p.day, a)
            }
    }

    // Target sampled every 14 days + endpoints
    private var targetPoints: [(day: Int, miles: Double)] {
        vm.progressData
            .filter { $0.day % 14 == 0 || $0.day == 1 || $0.day == vm.daysInYear }
            .map { ($0.day, $0.target) }
    }

    var body: some View {
        CardView(title: "Cumulative Progress", systemImage: "chart.line.uptrend.xyaxis", accentColor: .blue) {
            Chart {
                // Target line
                ForEach(targetPoints, id: \.day) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Target", point.miles),
                        series: .value("Series", "Target")
                    )
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .interpolationMethod(.linear)
                }

                // Actual area + line
                ForEach(actualPoints, id: \.day) { point in
                    AreaMark(
                        x: .value("Day", point.day),
                        y: .value("Miles", point.miles),
                        series: .value("Series", "Actual")
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.blue.opacity(0.25), .blue.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Miles", point.miles),
                        series: .value("Series", "Actual")
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.monotone)
                }
            }
            .chartScrollableAxes([]).chartGesture { _ in DragGesture(minimumDistance: .infinity) }
            .chartXScale(domain: 1 ... vm.daysInYear)
            .chartYScale(domain: 0 ... vm.yearlyGoalMiles)
            .chartXAxis {
                AxisMarks(values: [1, 91, 182, 274, 365]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        let map = [1: "Jan", 91: "Apr", 182: "Jul", 274: "Oct", 365: "Dec"]
                        Text(map[val.as(Int.self) ?? 0] ?? "")
                            .font(.caption2)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        Text("\(val.as(Int.self) ?? 0)")
                            .font(.caption2)
                    }
                }
            }
            .frame(height: 180).clipped()
        }
    }
}
