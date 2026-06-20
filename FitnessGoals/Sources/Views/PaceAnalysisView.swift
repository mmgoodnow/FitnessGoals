import SwiftUI
import Charts

struct PaceAnalysisView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var selectedZone: HRZone? = nil  // nil = all zones

    private var data: [DashboardViewModel.YearPacePoint] {
        if let zone = selectedZone {
            return vm.paceAnalysisData(for: zone)
        }
        return vm.paceAnalysisData
    }

    private var hasData: Bool {
        data.contains { $0.avgPaceSecondsPerMeter != nil }
    }

    private var availableZones: [HRZone] {
        HRZone.allCases.filter { zone in
            vm.paceAnalysisData(for: zone).contains { $0.avgPaceSecondsPerMeter != nil }
        }
    }

    private var availableZoneIDs: [Int] {
        availableZones.map(\.id)
    }

    // Negate pace values so faster = higher bar (reversed y axis without crashing)
    private var chartData: [(point: DashboardViewModel.YearPacePoint, yVal: Double)] {
        data.compactMap { p in
            guard let pace = p.avgPaceSecondsPerMeter else { return nil }
            let minPerMile = pace * 1609.344 / 60.0
            return (p, -minPerMile)
        }
    }

    private var domain: ClosedRange<Double> {
        let vals = chartData.map { $0.yVal }
        guard !vals.isEmpty else { return 0 ... 1 }
        let mn = vals.min()!
        let mx = vals.max()!
        let pad = max(mx - mn, 0.5) * 0.15
        return (mn - pad) ... (mx + pad)
    }

    private var maxSampleMiles: Double {
        chartData.map { $0.point.totalMiles }.max() ?? 0
    }

    var body: some View {
        CardView(title: "Year-over-Year Pace",
                 systemImage: "chart.bar.xaxis",
                 accentColor: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                // Zone picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ZonePill(label: "All", color: .blue, selected: selectedZone == nil) {
                            selectedZone = nil
                        }
                        ForEach(availableZones) { zone in
                            ZonePill(
                                label: zone.name,
                                color: zone.color,
                                selected: selectedZone == zone
                            ) {
                                selectedZone = zone
                            }
                        }
                    }
                }

                if selectedZone != nil {
                    let maxHR = vm.estimatedMaxHR
                    let zone = selectedZone!
                    let lo = Int(zone.bpmRange(maxHR: maxHR).lowerBound)
                    let hi = Int(zone.bpmRange(maxHR: maxHR).upperBound)
                    Text("Avg HR \(lo)–\(hi) bpm · Est. max HR \(Int(maxHR)) bpm")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !hasData {
                    Text("No data for this zone")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Chart(chartData, id: \.point.id) { item in
                            let isCurrent = item.point.year == Calendar.current.component(.year, from: Date())
                            let barColor = selectedZone?.color ?? .blue
                            let opacity = sampleOpacity(for: item.point.totalMiles)

                            BarMark(
                                x: .value("Year", String(item.point.year)),
                                y: .value("Min/mi", item.yVal),
                                width: .ratio(0.5)
                            )
                            .foregroundStyle(
                                isCurrent
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [barColor.opacity(opacity * 0.7), barColor.opacity(opacity)],
                                        startPoint: .bottom, endPoint: .top))
                                    : AnyShapeStyle(barColor.opacity(opacity))
                            )
                            .cornerRadius(6)
                            .annotation(position: .top) {
                                let pos = -item.yVal
                                let m = Int(pos); let s = Int((pos - Double(m)) * 60)
                                Text(String(format: "%d:%02d", m, s))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartYScale(domain: domain)
                        .chartYAxis {
                            AxisMarks(position: .trailing) { val in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                AxisValueLabel {
                                    if let v = val.as(Double.self) {
                                        let pos = -v
                                        let m = Int(pos); let s = Int((pos - Double(m)) * 60)
                                        Text(String(format: "%d:%02d", m, s)).font(.caption2)
                                    }
                                }
                            }
                        }
                        .frame(height: 180).clipped()

                        Text("Darker bars are based on more miles.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .onAppear {
            resetUnavailableSelectedZone()
        }
        .onChange(of: availableZoneIDs) { _, _ in
            resetUnavailableSelectedZone()
        }
    }

    private func resetUnavailableSelectedZone() {
        if let selectedZone, !availableZones.contains(selectedZone) {
            self.selectedZone = nil
        }
    }

    private func sampleOpacity(for miles: Double) -> Double {
        guard maxSampleMiles > 0 else { return 0.35 }
        return 0.25 + 0.75 * min(max(miles / maxSampleMiles, 0), 1)
    }
}

private struct ZonePill: View {
    let label: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? color : Color(uiColor: .tertiarySystemFill), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
    }
}
