import SwiftUI
import Charts

struct ProgressChartView: View {
    @EnvironmentObject var vm: DashboardViewModel

    // Downsample to every 7th day for performance
    var sampled: [DashboardViewModel.ProgressPoint] {
        vm.progressData.filter { $0.day % 7 == 0 || $0.day == vm.dayOfYear }
    }

    var body: some View {
        CardView(title: "Cumulative Progress") {
            Chart {
                ForEach(sampled) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Target", point.target)
                    )
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(dash: [4, 4]))

                    if let actual = point.actual {
                        LineMark(
                            x: .value("Day", point.day),
                            y: .value("Actual", actual)
                        )
                        .foregroundStyle(.blue)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: [1, 91, 182, 274, 365]) { value in
                    AxisValueLabel {
                        let labels = ["Jan", "Apr", "Jul", "Oct", "Dec"]
                        let idx = [1, 91, 182, 274, 365].firstIndex(of: value.as(Int.self) ?? 0) ?? 0
                        Text(labels[min(idx, labels.count - 1)])
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel { Text("\(value.as(Int.self) ?? 0)") }
                    AxisGridLine()
                }
            }
            .frame(height: 200)
        }
    }
}
