import SwiftUI
import Charts

struct PaceAnalysisView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var excludedPointIDs = Set<UUID>()

    private var allPacePoints: [DashboardViewModel.WorkoutTrendPoint] {
        vm.allTimeWorkoutTrends.filter { $0.paceMinPerMile != nil }
    }

    private var points: [DashboardViewModel.WorkoutTrendPoint] {
        allPacePoints.filter { !excludedPointIDs.contains($0.id) }
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

    private var heartRateRange: ClosedRange<Double>? {
        let values = points.compactMap(\.heartRate)
        guard let min = values.min(), let max = values.max() else { return nil }
        return min ... max
    }

    var body: some View {
        CardView(
            title: "Workout Pace",
            systemImage: "chart.dots.scatter",
            accentColor: .blue
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if scatterData.isEmpty {
                    VStack(spacing: 8) {
                        Text(excludedPointIDs.isEmpty ? "No pace data" : "All selected workouts excluded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)

                        if !excludedPointIDs.isEmpty {
                            resetButton
                        }
                    }
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
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { value in
                                            excludeNearestPoint(
                                                to: value.location,
                                                proxy: proxy,
                                                geometry: geometry
                                            )
                                        }
                                )
                        }
                    }
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

                    heartRateLegend
                }
            }
        }
    }

    @ViewBuilder
    private var heartRateLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !excludedPointIDs.isEmpty {
                    Text("\(excludedPointIDs.count) excluded")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    resetButton
                }
            }

            if let range = heartRateRange {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: (0...8).map { heartRateColor(normalized: Double($0) / 8.0) },
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 8)

                HStack {
                    Text("\(Int(range.lowerBound.rounded())) bpm")
                    Spacer(minLength: 8)
                    Text("Heart rate")
                    Spacer(minLength: 8)
                    Text("\(Int(range.upperBound.rounded())) bpm")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else if points.contains(where: { $0.heartRate == nil }) {
                Label {
                    Text("No HR")
                } icon: {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var resetButton: some View {
        Button {
            excludedPointIDs.removeAll()
        } label: {
            Label("Show all", systemImage: "arrow.counterclockwise")
                .font(.caption2)
        }
    }

    private func color(for point: DashboardViewModel.WorkoutTrendPoint) -> Color {
        guard let hr = point.heartRate,
              let normalized = normalizedHeartRate(hr) else {
            return .secondary.opacity(0.45)
        }
        return heartRateColor(normalized: normalized)
    }

    private func symbolSize(for point: DashboardViewModel.WorkoutTrendPoint) -> CGFloat {
        point.heartRate == nil ? 18 : 28
    }

    private func excludeNearestPoint(
        to location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotAnchor]
        let plotLocation = CGPoint(
            x: location.x - plotFrame.origin.x,
            y: location.y - plotFrame.origin.y
        )

        guard plotFrame.contains(location) else { return }

        let nearest = scatterData.compactMap { item -> (id: UUID, distance: CGFloat)? in
            guard let xPosition = proxy.position(forX: item.point.date),
                  let yPosition = proxy.position(forY: item.yVal) else {
                return nil
            }

            let dx = xPosition - plotLocation.x
            let dy = yPosition - plotLocation.y
            return (item.point.id, sqrt(dx * dx + dy * dy))
        }
        .min { $0.distance < $1.distance }

        if let nearest, nearest.distance <= 28 {
            excludedPointIDs.insert(nearest.id)
        }
    }

    private func normalizedHeartRate(_ bpm: Double) -> Double? {
        guard let range = heartRateRange else { return nil }
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0.5 }
        return min(max((bpm - range.lowerBound) / span, 0), 1)
    }

    private func heartRateColor(normalized value: Double) -> Color {
        let clamped = min(max(value, 0), 1)
        let hue = 250.0 - (220.0 * clamped)
        return Color.oklch(lightness: 0.72, chroma: 0.16, hue: hue)
    }

    private func formatPace(_ minPerMile: Double) -> String {
        let minutes = Int(minPerMile)
        let seconds = Int((minPerMile - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private extension Color {
    static func oklch(lightness l: Double, chroma c: Double, hue h: Double, opacity: Double = 1) -> Color {
        let hueRadians = h * .pi / 180
        let a = c * cos(hueRadians)
        let b = c * sin(hueRadians)

        let lPrime = l + 0.3963377774 * a + 0.2158037573 * b
        let mPrime = l - 0.1055613458 * a - 0.0638541728 * b
        let sPrime = l - 0.0894841775 * a - 1.2914855480 * b

        let lCube = lPrime * lPrime * lPrime
        let mCube = mPrime * mPrime * mPrime
        let sCube = sPrime * sPrime * sPrime

        let redLinear = 4.0767416621 * lCube - 3.3077115913 * mCube + 0.2309699292 * sCube
        let greenLinear = -1.2684380046 * lCube + 2.6097574011 * mCube - 0.3413193965 * sCube
        let blueLinear = -0.0041960863 * lCube - 0.7034186147 * mCube + 1.7076147010 * sCube

        return Color(
            red: srgbChannel(redLinear),
            green: srgbChannel(greenLinear),
            blue: srgbChannel(blueLinear),
            opacity: opacity
        )
    }

    private static func srgbChannel(_ linear: Double) -> Double {
        let encoded: Double
        if linear <= 0.0031308 {
            encoded = 12.92 * linear
        } else {
            encoded = 1.055 * pow(linear, 1.0 / 2.4) - 0.055
        }
        return min(max(encoded, 0), 1)
    }
}
