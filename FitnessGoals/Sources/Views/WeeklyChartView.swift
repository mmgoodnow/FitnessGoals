import SwiftUI
import Charts

struct WeeklyChartView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        CardView(title: "Weekly Distance", systemImage: "calendar.badge.clock", accentColor: .indigo) {
            Chart(vm.weeklyData) { point in
                BarMark(
                    x: .value("Week", point.week),
                    y: .value("Miles", point.miles),
                    width: 4
                )
                .foregroundStyle(
                    LinearGradient(colors: [.indigo, .blue],
                                   startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(3)
            }
            .allowsHitTesting(false)
            .chartXScale(domain: 1 ... 52)
            .chartXAxis {
                AxisMarks(values: [1, 13, 26, 39, 52]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        let map = [1: "Jan", 13: "Apr", 26: "Jul", 39: "Oct", 52: "Dec"]
                        Text(map[val.as(Int.self) ?? 0] ?? "").font(.caption2)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel { Text("\(val.as(Int.self) ?? 0)").font(.caption2) }
                }
            }
            .frame(height: 150).clipped()
        }
    }
}
