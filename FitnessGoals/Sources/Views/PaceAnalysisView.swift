import SwiftUI
import Charts

struct PaceAnalysisView: View {
    @EnvironmentObject var vm: DashboardViewModel

    private var hasData: Bool {
        vm.paceAnalysisData.contains { $0.avgPaceSecondsPerMeter != nil }
    }

    var body: some View {
        CardView(title: "Year-over-Year \(vm.sport.usesPace ? "Pace" : "Speed")",
                 systemImage: "chart.line.uptrend.xyaxis.circle.fill",
                 accentColor: .blue) {
            if !hasData {
                Text("No historical data available")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(vm.paceAnalysisData) { point in
                    if let pace = point.avgPaceSecondsPerMeter {
                        let yVal = vm.sport.usesPace
                            ? pace * 1609.344 / 60.0
                            : (1.0 / pace) * 2.23694

                        BarMark(
                            x: .value("Year", String(point.year)),
                            y: .value(vm.sport.usesPace ? "Min/mi" : "mph", yVal)
                        )
                        .foregroundStyle(
                            point.year == Calendar.current.component(.year, from: Date())
                                ? AnyShapeStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top))
                                : AnyShapeStyle(.secondary.opacity(0.4))
                        )
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            if vm.sport.usesPace {
                                let m = Int(yVal); let s = Int((yVal - Double(m)) * 60)
                                Text(String(format: "%d:%02d", m, s))
                                    .font(.caption2).foregroundStyle(.secondary)
                            } else {
                                Text(String(format: "%.1f", yVal))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis(vm.sport.usesPace ? .automatic : .automatic)
                .chartYScale(domain: .automatic(reversed: vm.sport.usesPace))
                .chartYAxis {
                    AxisMarks(position: .trailing) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel {
                            if vm.sport.usesPace, let v = val.as(Double.self) {
                                let m = Int(v); let s = Int((v - Double(m)) * 60)
                                Text(String(format: "%d:%02d", m, s)).font(.caption2)
                            } else if let v = val.as(Double.self) {
                                Text(String(format: "%.1f", v)).font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }
}
