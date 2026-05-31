import SwiftUI
import Charts

struct WeekdayFrequencyChartView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        CardView(title: "Run Frequency by Day", systemImage: "checkmark.circle", accentColor: .teal) {
            Chart(vm.weekdayData) { point in
                BarMark(
                    x: .value("Day", point.label),
                    y: .value("Frequency", point.runFrequency)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.teal, .mint], startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(4)
            }
            .chartYScale(domain: 0 ... 1)
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 0.25, 0.5, 0.75, 1.0]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text(String(format: "%.0f%%", v * 100)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 140)
        }
    }
}

struct WeekdayDistanceChartView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        CardView(title: "Avg Distance When Running", systemImage: "ruler", accentColor: .indigo) {
            Chart(vm.weekdayData.filter { $0.avgMilesWhenRan > 0 }) { point in
                BarMark(
                    x: .value("Day", point.label),
                    y: .value("Avg Miles", point.avgMilesWhenRan)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.indigo, .purple], startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        Text(String(format: "%.1f", val.as(Double.self) ?? 0)).font(.caption2)
                    }
                }
            }
            .frame(height: 140)
        }
    }
}
