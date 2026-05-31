import SwiftUI
import Charts

struct PaceAnalysisView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        CardView(title: "Year-over-Year \(vm.sport.usesPace ? "Pace" : "Speed")") {
            if vm.paceAnalysisData.allSatisfy({ $0.avgPaceSecondsPerMeter == nil }) {
                Text("No historical data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(vm.paceAnalysisData) { point in
                    if let pace = point.avgPaceSecondsPerMeter {
                        if vm.sport.usesPace {
                            // pace: lower is faster — display as min/mile
                            let minPerMile = pace * 1609.344 / 60.0
                            LineMark(
                                x: .value("Year", point.year),
                                y: .value("Min/mi", minPerMile)
                            )
                            .symbol(.circle)
                            .foregroundStyle(.blue)
                            PointMark(
                                x: .value("Year", point.year),
                                y: .value("Min/mi", minPerMile)
                            )
                            .foregroundStyle(.blue)
                        } else {
                            let mph = (1.0 / pace) * 2.23694
                            LineMark(
                                x: .value("Year", point.year),
                                y: .value("mph", mph)
                            )
                            .symbol(.circle)
                            .foregroundStyle(.blue)
                            PointMark(
                                x: .value("Year", point.year),
                                y: .value("mph", mph)
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel { Text(String(value.as(Int.self) ?? 0)) }
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if vm.sport.usesPace, let v = value.as(Double.self) {
                                let m = Int(v)
                                let s = Int((v - Double(m)) * 60)
                                Text(String(format: "%d:%02d", m, s))
                            } else if let v = value.as(Double.self) {
                                Text(String(format: "%.1f", v))
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 200)

                // Volume bars overlay
                Chart(vm.paceAnalysisData) { point in
                    BarMark(
                        x: .value("Year", point.year),
                        y: .value("Miles", point.totalMiles)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                    .cornerRadius(4)
                }
                .chartXAxis(.hidden)
                .frame(height: 80)
                .padding(.top, 8)

                Text("Volume (mi)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
