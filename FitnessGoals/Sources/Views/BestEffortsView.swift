import SwiftUI
import Charts

struct BestEffortsView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var selectedDistanceID: String = "5k"

    private var efforts: [DashboardViewModel.BestEffort] { vm.bestEfforts }
    private var progression: [DashboardViewModel.BestEffortPoint] {
        vm.bestEffortProgression(for: selectedDistanceID)
    }

    var body: some View {
        CardView(title: "Best Efforts", systemImage: "trophy.fill", accentColor: .yellow) {
            if efforts.isEmpty {
                Text("No data").font(.caption).foregroundStyle(.secondary)
            } else {
                // Distance pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DashboardViewModel.bestEffortDistances) { dist in
                            let hasBest = efforts.contains { $0.id == dist.id }
                            Button {
                                selectedDistanceID = dist.id
                            } label: {
                                Text(dist.label)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectedDistanceID == dist.id ? Color.yellow : Color.secondary.opacity(0.15))
                                    .foregroundStyle(selectedDistanceID == dist.id ? Color.black : (hasBest ? .primary : .secondary))
                                    .clipShape(Capsule())
                            }
                            .disabled(!hasBest)
                        }
                    }
                }
                .padding(.bottom, 4)

                // Best time for selected distance
                if let best = efforts.first(where: { $0.id == selectedDistanceID }) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formatTime(best.time))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(best.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatPace(best.time, meters: best.meters))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Progression chart
                if progression.count > 1 {
                    Divider()
                    Text("Progression")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)

                    let prs = progression.filter { $0.isBest }
                    let domain = progressionDomain()

                    Chart {
                        // All efforts faded
                        ForEach(progression) { pt in
                            PointMark(
                                x: .value("Date", pt.date),
                                y: .value("Time", pt.time)
                            )
                            .foregroundStyle(Color.yellow.opacity(0.25))
                            .symbolSize(12)
                        }
                        // PR step line
                        ForEach(prs) { pt in
                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Time", pt.time)
                            )
                            .foregroundStyle(Color.yellow)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.stepStart)

                            PointMark(
                                x: .value("Date", pt.date),
                                y: .value("Time", pt.time)
                            )
                            .foregroundStyle(Color.yellow)
                            .symbolSize(40)
                        }
                    }
                    .chartScrollableAxes([]).chartGesture { _ in DragGesture(minimumDistance: .infinity) }
                    .chartYScale(domain: domain)
                    .chartYAxis {
                        AxisMarks(position: .trailing) { val in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            AxisValueLabel {
                                if let t = val.as(Double.self) {
                                    Text(formatTime(t)).font(.caption2)
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
                    .frame(height: 140).clipped()

                    Text("Estimated from avg pace — not split-based")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func progressionDomain() -> ClosedRange<Double> {
        let times = progression.map { $0.time }
        guard let mn = times.min(), let mx = times.max(), mn < mx else {
            let t = progression.first?.time ?? 0
            return (t * 0.95) ... (t * 1.05)
        }
        let pad = (mx - mn) * 0.1
        return (mn - pad) ... (mx + pad)
    }
}

private func formatTime(_ seconds: TimeInterval) -> String {
    let s = Int(seconds)
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, sec)
    } else {
        return String(format: "%d:%02d", m, sec)
    }
}

private func formatPace(_ time: TimeInterval, meters: Double) -> String {
    let secPerMeter = time / meters
    let secPerMile = secPerMeter * 1609.34
    let m = Int(secPerMile) / 60
    let s = Int(secPerMile) % 60
    return String(format: "%d:%02d /mi", m, s)
}
