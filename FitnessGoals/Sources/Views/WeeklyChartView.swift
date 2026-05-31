import SwiftUI
import Charts

struct WeeklyChartView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        CardView(title: "Weekly Distance") {
            Chart(vm.weeklyData) { point in
                BarMark(
                    x: .value("Week", point.week),
                    y: .value("Miles", point.miles)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: stride(from: 1, through: 52, by: 13).map { $0 }) { value in
                    AxisValueLabel {
                        if let week = value.as(Int.self) {
                            let labels = ["Jan", "Apr", "Jul", "Oct"]
                            let idx = [1, 14, 27, 40].firstIndex(where: { week >= $0 }) ?? 0
                            Text(labels[min(idx, 3)])
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }
}
