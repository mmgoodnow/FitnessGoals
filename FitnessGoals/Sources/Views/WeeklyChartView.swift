import SwiftUI
import Charts

struct WeeklyChartView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        CardView(title: "Weekly Distance", systemImage: "calendar.badge.clock", accentColor: .indigo) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let totals = vm.weeklyDistanceTotals(asOf: context.date)
                HStack(spacing: 16) {
                    distanceSummary("This week", miles: totals.current)
                    distanceSummary("Last week", miles: totals.previous)
                    distanceSummary("Last 7 days", miles: totals.rolling)
                }
            }
            ActivityCalendarView()
            Divider()
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
            .chartScrollableAxes([]).chartGesture { _ in DragGesture(minimumDistance: .infinity) }
            .chartXScale(domain: chartDateRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 3)) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        if let date = val.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated)).font(.caption2)
                        }
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

    private var chartDateRange: ClosedRange<Date> {
        let year = Formatters.weekCalendar.dateInterval(of: .year, for: Date())!
        return Formatters.startOfWeek(year.start)...year.end
    }

    private func distanceSummary(_ title: String, miles: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f mi", miles))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
