import SwiftUI
import Charts

struct BestEffortsView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var selectedDistanceID: String = "5k"
    @State private var tappedPoint: DashboardViewModel.BestEffortPoint? = nil

    private var efforts: [DashboardViewModel.BestEffort] {
        DashboardViewModel.bestEffortDistances.compactMap { vm.bestEffortsByDistance[$0.id] }
    }

    private var progression: [DashboardViewModel.BestEffortPoint] {
        vm.bestEffortProgressions[selectedDistanceID] ?? []
    }

    private var prs: [DashboardViewModel.BestEffortPoint] {
        progression.filter { $0.isBest }
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
                    HStack {
                        Text("Progression")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("Tap a PR dot to exclude")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)

                    let domain = progressionDomain(progression)

                    Chart {
                        ForEach(progression) { pt in
                            PointMark(x: .value("Date", pt.date), y: .value("Time", pt.time))
                                .foregroundStyle(Color.yellow.opacity(0.25))
                                .symbolSize(12)
                        }
                        ForEach(prs) { pt in
                            prLineContent(pt)
                        }
                    }
                    .chartScrollableAxes([])
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onTapGesture { location in
                                    handleChartTap(location: location, proxy: proxy, geo: geo)
                                }
                        }
                    }
                    .frame(height: 140).clipped()
                    .sheet(item: $tappedPoint) { pt in
                        WorkoutDetailView(workoutID: pt.id)
                            .environmentObject(vm)
                    }
                }
            } else if !vm.bestEffortsLoading {
                Text("No workouts long enough for \(DashboardViewModel.bestEffortDistances.first { $0.id == selectedDistanceID }?.label ?? selectedDistanceID)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ChartContentBuilder
    private func prLineContent(_ pt: DashboardViewModel.BestEffortPoint) -> some ChartContent {
        let isTapped = tappedPoint?.id == pt.id
        LineMark(x: .value("Date", pt.date), y: .value("Time", pt.time))
            .foregroundStyle(Color.yellow)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.stepStart)
        PointMark(x: .value("Date", pt.date), y: .value("Time", pt.time))
            .foregroundStyle(isTapped ? Color.red : Color.yellow)
            .symbolSize(isTapped ? 80 : 50)
    }

    private func handleChartTap(location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let date: Date = proxy.value(atX: location.x - geo.frame(in: .local).minX),
              let time: Double = proxy.value(atY: location.y - geo.frame(in: .local).minY)
        else { return }
        let nearest = prs.min {
            distanceToPoint($0, date: date, time: time, proxy: proxy, geo: geo) <
            distanceToPoint($1, date: date, time: time, proxy: proxy, geo: geo)
        }
        if let nearest, distanceToPoint(nearest, date: date, time: time, proxy: proxy, geo: geo) < 30 {
            tappedPoint = nearest
        }
    }

    private func distanceToPoint(
        _ pt: DashboardViewModel.BestEffortPoint,
        date: Date, time: Double,
        proxy: ChartProxy, geo: GeometryProxy
    ) -> CGFloat {
        let frame = geo.frame(in: .local)
        guard let px = proxy.position(forX: pt.date),
              let py = proxy.position(forY: pt.time) else { return .infinity }
        let tx = proxy.position(forX: date) ?? 0
        let ty = proxy.position(forY: time) ?? 0
        let dx = (px + frame.minX) - (tx + frame.minX)
        let dy = (py + frame.minY) - (ty + frame.minY)
        return sqrt(dx * dx + dy * dy)
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
