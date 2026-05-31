import SwiftUI
import Charts

struct BestEffortsView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var selectedDistanceID: String = "5k"

    private var efforts: [DashboardViewModel.BestEffort] {
        DashboardViewModel.bestEffortDistances.compactMap { vm.bestEffortsByDistance[$0.id] }
    }

    private var progression: [DashboardViewModel.BestEffortPoint] {
        vm.bestEffortProgressions[selectedDistanceID] ?? []
    }

    var body: some View {
        CardView(title: "Best Efforts", systemImage: "trophy.fill", accentColor: .yellow) {
            // Distance pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DashboardViewModel.bestEffortDistances) { dist in
                        let hasBest = vm.bestEffortsByDistance[dist.id] != nil
                        Button {
                            selectedDistanceID = dist.id
                        } label: {
                            Text(dist.label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedDistanceID == dist.id ? Color.yellow : Color.secondary.opacity(0.15))
                                .foregroundStyle(selectedDistanceID == dist.id ? Color.black : (hasBest ? Color.primary : Color.secondary))
                                .clipShape(Capsule())
                        }
                        .disabled(!hasBest && !vm.bestEffortsLoading)
                    }
                }
            }
            .padding(.bottom, 4)

            if vm.bestEffortsLoading && efforts.isEmpty {
                VStack(spacing: 8) {
                    ProgressView(value: vm.bestEffortsProgress)
                        .tint(.yellow)
                    Text("Analysing routes… \(Int(vm.bestEffortsProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if let best = vm.bestEffortsByDistance[selectedDistanceID] {
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

                if vm.bestEffortsLoading {
                    HStack(spacing: 6) {
                        ProgressView(value: vm.bestEffortsProgress).tint(.yellow)
                        Text("\(Int(vm.bestEffortsProgress * 100))%")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                if progression.count > 1 {
                    Divider()
                    Text("Progression")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)

                    let prs = progression.filter { $0.isBest }
                    let domain = progressionDomain(progression)

                    Chart {
                        ForEach(progression) { pt in
                            PointMark(
                                x: .value("Date", pt.date),
                                y: .value("Time", pt.time)
                            )
                            .foregroundStyle(Color.yellow.opacity(0.25))
                            .symbolSize(12)
                        }
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
                }
            } else if !vm.bestEffortsLoading {
                Text("No workouts long enough for \(DashboardViewModel.bestEffortDistances.first { $0.id == selectedDistanceID }?.label ?? selectedDistanceID)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func progressionDomain(_ pts: [DashboardViewModel.BestEffortPoint]) -> ClosedRange<Double> {
        let times = pts.map { $0.time }
        guard let mn = times.min(), let mx = times.max(), mn < mx else {
            let t = pts.first?.time ?? 0
            return (t * 0.95) ... (t * 1.05)
        }
        let pad = (mx - mn) * 0.1
        return (mn - pad) ... (mx + pad)
    }
}

func formatTime(_ seconds: TimeInterval) -> String {
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

func formatPace(_ time: TimeInterval, meters: Double) -> String {
    let secPerMeter = time / meters
    let secPerMile = secPerMeter * 1609.34
    let m = Int(secPerMile) / 60
    let s = Int(secPerMile) % 60
    return String(format: "%d:%02d /mi", m, s)
}
