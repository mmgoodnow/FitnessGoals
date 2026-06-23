import SwiftUI
import Charts

struct PaceAnalysisView: View {
    @EnvironmentObject var vm: DashboardViewModel

    private var points: [DashboardViewModel.WorkoutTrendPoint] {
        vm.allTimeWorkoutTrends.filter { $0.paceMinPerMile != nil }
    }

    private var scatterData: [(point: DashboardViewModel.WorkoutTrendPoint, yVal: Double)] {
        points.map { point in
            (point, -point.paceMinPerMile!)
        }
    }

    private var domain: ClosedRange<Double> {
        let vals = scatterData.map { $0.yVal }
        guard !vals.isEmpty else { return 0 ... 1 }
        let mn = vals.min()!
        let mx = vals.max()!
        let pad = max(mx - mn, 0.5) * 0.12
        return (mn - pad) ... (mx + pad)
    }

    private var availableZones: [HRZone] {
        let zones = points.compactMap { point -> HRZone? in
            guard let hr = point.heartRate else { return nil }
            return HRZone.zone(for: hr, maxHR: vm.estimatedMaxHR)
        }
        return HRZone.allCases.filter { zones.contains($0) }
    }

    var body: some View {
        CardView(
            title: "Workout Pace",
            systemImage: "chart.dots.scatter",
            accentColor: .blue
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if scatterData.isEmpty {
                    Text("No pace data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    Chart(scatterData, id: \.point.id) { item in
                        PointMark(
                            x: .value("Date", item.point.date),
                            y: .value("Min/mi", item.yVal)
                        )
                        .foregroundStyle(color(for: item.point))
                        .symbolSize(symbolSize(for: item.point))
                    }
                    .chartScrollableAxes([])
                    .chartGesture { _ in DragGesture(minimumDistance: .infinity) }
                    .chartYScale(domain: domain)
                    .chartYAxis {
                        AxisMarks(position: .trailing) { val in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            AxisValueLabel {
                                if let v = val.as(Double.self) {
                                    Text(formatPace(-v)).font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .year, count: 1)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            AxisValueLabel(format: .dateTime.year()).font(.caption2)
                        }
                    }
                    .frame(height: 360)
                    .clipped()

                    zoneLegend
                }
            }
        }
    }

    private var zoneLegend: some View {
        HStack(spacing: 8) {
            ForEach(availableZones) { zone in
                Label {
                    Text(zone.shortName)
                } icon: {
                    Circle()
                        .fill(zone.color)
                        .frame(width: 8, height: 8)
                }
            }

            if points.contains(where: { $0.heartRate == nil }) {
                Label {
                    Text("No HR")
                } icon: {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func color(for point: DashboardViewModel.WorkoutTrendPoint) -> Color {
        guard let hr = point.heartRate,
              let zone = HRZone.zone(for: hr, maxHR: vm.estimatedMaxHR) else {
            return .secondary.opacity(0.45)
        }
        return zone.color
    }

    private func symbolSize(for point: DashboardViewModel.WorkoutTrendPoint) -> CGFloat {
        point.heartRate == nil ? 18 : 28
    }

    private func formatPace(_ minPerMile: Double) -> String {
        let minutes = Int(minPerMile)
        let seconds = Int((minPerMile - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}
