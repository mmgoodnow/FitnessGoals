import SwiftUI
import Charts

struct WeekdayAverageChartView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        CardView(title: "Average by Day of Week") {
            Chart(vm.weekdayData) { point in
                BarMark(
                    x: .value("Day", point.label),
                    y: .value("Avg Miles", point.avgMiles)
                )
                .foregroundStyle(.teal.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
        }
    }
}
