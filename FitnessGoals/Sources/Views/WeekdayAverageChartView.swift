import SwiftUI
import Charts

struct WeekdayFrequencyChartView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        CardView(title: "Runs by Day of Week", systemImage: "checkmark.circle", accentColor: .teal) {
            Chart(vm.weekdayData) { point in
                BarMark(
                    x: .value("Day", point.label),
                    y: .value("Runs", point.runCount),
                    width: .ratio(0.5)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.teal, .mint], startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(4)
            }
            .chartScrollableAxes([]).chartGesture { _ in DragGesture(minimumDistance: .infinity) }
            .chartYAxis {
                AxisMarks(position: .trailing) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        Text("\(val.as(Int.self) ?? 0)").font(.caption2)
                    }
                }
            }
            .frame(height: 140).clipped()
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
                    y: .value("Avg Miles", point.avgMilesWhenRan),
                    width: .ratio(0.5)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.indigo, .purple], startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(4)
            }
            .chartScrollableAxes([]).chartGesture { _ in DragGesture(minimumDistance: .infinity) }
            .chartYAxis {
                AxisMarks(position: .trailing) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        Text(String(format: "%.1f", val.as(Double.self) ?? 0)).font(.caption2)
                    }
                }
            }
            .frame(height: 140).clipped()
        }
    }
}
