import SwiftUI
import Charts

struct WeekdayAverageChartView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        CardView(title: "Avg by Day of Week", systemImage: "chart.bar.fill", accentColor: .teal) {
            Chart(vm.weekdayData) { point in
                BarMark(
                    x: .value("Day", point.label),
                    y: .value("Avg Miles", point.avgMiles)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.teal, .mint],
                                   startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel { Text(String(format: "%.1f", val.as(Double.self) ?? 0)).font(.caption2) }
                }
            }
            .frame(height: 150)
        }
    }
}
