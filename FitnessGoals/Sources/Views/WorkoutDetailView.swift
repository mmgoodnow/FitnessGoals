import SwiftUI
import MapKit
import CoreLocation

/// Wraps a workout UUID so it can drive a `.sheet(item:)` presentation.
struct WorkoutDetailTarget: Identifiable {
    let id: UUID
}

struct WorkoutDetailView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    let workoutID: UUID

    @State private var routeData: HealthKitService.FullRouteData = .init(coordinates: [], segmentsByDistance: [:], splitsByDistance: [:])
    @State private var loadingRoute = true
    @State private var selectedDistance: Double? = nil
    @State private var routeAnimationID = 0

    private var workout: Workout? { vm.workout(for: workoutID) }
    private var isExcluded: Bool { vm.excludedWorkoutIDs.contains(workoutID) }

    /// Qualifying distances for this workout, in ascending order.
    private var splitRows: [DashboardViewModel.BestEffortDistance] {
        DashboardViewModel.bestEffortDistances.filter { routeData.splitsByDistance[$0.meters] != nil }
    }

    private var highlightCoords: [CLLocationCoordinate2D] {
        guard let d = selectedDistance else { return [] }
        return routeData.segmentsByDistance[d] ?? []
    }

    private var animationDuration: TimeInterval {
        guard let duration = workout?.duration else { return 8 }
        return min(max(duration / 180, 6), 14)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pinned map header — stays visible while the list scrolls.
            mapHeader
                .frame(height: 340)
                .ignoresSafeArea(edges: .top)

            List {
                    if !splitRows.isEmpty {
                        Section {
                            ForEach(splitRows) { dist in
                                splitRow(dist)
                            }
                        } header: {
                            Text("Best Efforts")
                        } footer: {
                            Text("Tap a distance to highlight its fastest segment on the map.")
                        }
                    }

                    Section("Workout") {
                        if let w = workout {
                            DetailRow(label: "Date", value: w.startDate.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                            DetailRow(label: "Time", value: w.startDate.formatted(.dateTime.hour().minute()))
                            DetailRow(label: "Distance", value: Formatters.formatMiles(w.distance))
                            DetailRow(label: "Duration", value: Formatters.formatDuration(w.duration))
                            if let spm = w.paceSecondsPerMeter {
                                DetailRow(label: "Avg Pace", value: Formatters.formatPace(spm))
                            }
                            if let hr = w.avgHeartRate {
                                DetailRow(label: "Avg Heart Rate", value: String(format: "%.0f bpm", hr))
                            }
                        }
                    }

                    Section {
                        Button(role: isExcluded ? nil : .destructive) {
                            vm.toggleExcluded(workoutID)
                            dismiss()
                        } label: {
                            Label(
                                isExcluded ? "Remove Exclusion" : "Exclude from Best Efforts",
                                systemImage: isExcluded ? "checkmark.circle" : "xmark.circle"
                            )
                        }
                        .foregroundStyle(isExcluded ? .green : .red)
                    } footer: {
                        if isExcluded {
                            Text("This workout is currently excluded from best effort calculations.")
                        } else {
                            Text("Excludes this workout from best effort calculations. Useful for GPS artifacts or accidental recordings.")
                        }
                    }
                }
        }
        .task {
            routeData = await vm.fetchFullRouteData(for: workoutID)
            loadingRoute = false
        }
    }


    @ViewBuilder
    private var mapHeader: some View {
        if routeData.coordinates.count > 1 {
            ZStack(alignment: .bottomTrailing) {
                RouteMapView(
                    coordinates: routeData.coordinates,
                    splitCoordinates: highlightCoords,
                    animationID: routeAnimationID,
                    animationDuration: animationDuration
                )

                Button {
                    routeAnimationID += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Replay route animation")
                .padding(16)
            }
        } else if loadingRoute {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .overlay { ProgressView() }
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .overlay {
                    Label("No route data", systemImage: "map.slash")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
        }
    }

    @ViewBuilder
    private func splitRow(_ dist: DashboardViewModel.BestEffortDistance) -> some View {
        let time = routeData.splitsByDistance[dist.meters] ?? 0
        let isSelected = selectedDistance == dist.meters
        let ranking = vm.rank(forSplit: time, distanceID: dist.id)
        Button {
            // Tapping the selected row deselects it (clears the map highlight).
            selectedDistance = isSelected ? nil : dist.meters
        } label: {
            HStack {
                Image(systemName: isSelected ? "mappin.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .yellow : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dist.label)
                        .foregroundStyle(.primary)
                    if let ranking {
                        Text("\(ordinal(ranking.rank)) fastest of \(ranking.total)")
                            .font(.caption2)
                            .foregroundStyle(ranking.rank == 1 ? .yellow : .secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(time))
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(isSelected ? .yellow : .primary)
                    Text(formatPace(time, meters: dist.meters))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Route map

// Tag polylines so the renderer knows which color to use
private class TaggedPolyline: MKPolyline {
    enum Kind { case full, animated, split }
    var kind: Kind = .full
}

struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let splitCoordinates: [CLLocationCoordinate2D]
    let animationID: Int
    let animationDuration: TimeInterval

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isScrollEnabled = true
        map.isZoomEnabled = true
        map.isRotateEnabled = true
        map.isPitchEnabled = false
        map.showsCompass = true
        map.pointOfInterestFilter = .excludingAll
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays.filter { overlay in
            guard let tagged = overlay as? TaggedPolyline else { return true }
            return tagged.kind != .animated
        })
        map.removeAnnotations(map.annotations.filter { $0.title != "Current Position" })
        guard coordinates.count > 1 else { return }

        // Full route — faded
        let fullLine = TaggedPolyline(coordinates: coordinates, count: coordinates.count)
        fullLine.kind = .full
        map.addOverlay(fullLine, level: .aboveRoads)

        // Best-split segment — highlighted on top
        if splitCoordinates.count > 1 {
            let splitLine = TaggedPolyline(coordinates: splitCoordinates, count: splitCoordinates.count)
            splitLine.kind = .split
            map.addOverlay(splitLine, level: .aboveRoads)

            // Start/end pins for the split
            let splitStart = MKPointAnnotation()
            splitStart.coordinate = splitCoordinates.first!
            splitStart.title = "Split Start"
            map.addAnnotation(splitStart)

            let splitEnd = MKPointAnnotation()
            splitEnd.coordinate = splitCoordinates.last!
            splitEnd.title = "Split End"
            map.addAnnotation(splitEnd)
        }

        // Re-fit only when the highlighted split changes, so manual pan/zoom is preserved.
        let key = splitCoordinates.first.map { "\($0.latitude),\($0.longitude)" } ?? "full"
        if context.coordinator.lastFitKey != key {
            context.coordinator.lastFitKey = key
            let fitRect: MKMapRect
            if splitCoordinates.count > 1 {
                let splitLine = MKPolyline(coordinates: splitCoordinates, count: splitCoordinates.count)
                fitRect = splitLine.boundingMapRect
            } else {
                fitRect = fullLine.boundingMapRect
            }
            map.setVisibleMapRect(fitRect, edgePadding: UIEdgeInsets(top: 48, left: 48, bottom: 48, right: 48), animated: true)
        }

        context.coordinator.startRouteAnimation(
            on: map,
            coordinates: coordinates,
            animationID: animationID,
            duration: animationDuration
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        var lastFitKey: String?
        private var displayLink: CADisplayLink?
        private var animationID: Int?
        private var animationStartedAt: CFTimeInterval = 0
        private var animationDuration: TimeInterval = 8
        private var routeCoordinates: [CLLocationCoordinate2D] = []
        private weak var mapView: MKMapView?
        private var animatedOverlay: TaggedPolyline?
        private var currentAnnotation: MKPointAnnotation?

        deinit {
            displayLink?.invalidate()
        }

        func startRouteAnimation(
            on map: MKMapView,
            coordinates: [CLLocationCoordinate2D],
            animationID: Int,
            duration: TimeInterval
        ) {
            let sameRoute = routeCoordinates.count == coordinates.count
                && routeCoordinates.first?.latitude == coordinates.first?.latitude
                && routeCoordinates.first?.longitude == coordinates.first?.longitude
                && routeCoordinates.last?.latitude == coordinates.last?.latitude
                && routeCoordinates.last?.longitude == coordinates.last?.longitude

            guard !sameRoute || self.animationID != animationID else { return }

            displayLink?.invalidate()
            removeAnimatedRoute()

            self.mapView = map
            self.routeCoordinates = coordinates
            self.animationID = animationID
            self.animationDuration = max(duration, 1)
            self.animationStartedAt = CACurrentMediaTime()

            let marker = MKPointAnnotation()
            marker.coordinate = coordinates[0]
            marker.title = "Current Position"
            currentAnnotation = marker
            map.addAnnotation(marker)

            renderAnimatedRoute(progress: 0)

            let link = CADisplayLink(target: self, selector: #selector(animationStep(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func animationStep(_ link: CADisplayLink) {
            let elapsed = CACurrentMediaTime() - animationStartedAt
            let progress = min(max(elapsed / animationDuration, 0), 1)
            renderAnimatedRoute(progress: progress)

            if progress >= 1 {
                link.invalidate()
                displayLink = nil
            }
        }

        private func renderAnimatedRoute(progress: Double) {
            guard let mapView, routeCoordinates.count > 1 else { return }

            if let animatedOverlay {
                mapView.removeOverlay(animatedOverlay)
            }

            let lastIndex = max(1, min(routeCoordinates.count - 1, Int(Double(routeCoordinates.count - 1) * progress)))
            let visibleCoordinates = Array(routeCoordinates.prefix(lastIndex + 1))
            let line = TaggedPolyline(coordinates: visibleCoordinates, count: visibleCoordinates.count)
            line.kind = .animated
            animatedOverlay = line
            mapView.addOverlay(line, level: .aboveRoads)

            currentAnnotation?.coordinate = routeCoordinates[lastIndex]
        }

        private func removeAnimatedRoute() {
            guard let mapView else { return }
            if let animatedOverlay {
                mapView.removeOverlay(animatedOverlay)
            }
            if let currentAnnotation {
                mapView.removeAnnotation(currentAnnotation)
            }
            animatedOverlay = nil
            currentAnnotation = nil
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? TaggedPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: polyline)
            switch polyline.kind {
            case .full:
                r.strokeColor = UIColor.systemBlue.withAlphaComponent(0.28)
                r.lineWidth = 3
            case .animated:
                r.strokeColor = UIColor.systemOrange
                r.lineWidth = 5
                r.lineCap = .round
                r.lineJoin = .round
            case .split:
                r.strokeColor = UIColor.systemYellow
                r.lineWidth = 5
                r.lineCap = .round
                r.lineJoin = .round
            }
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: annotation.title!!)
            view.canShowCallout = false
            switch annotation.title!! {
            case "Split Start":
                view.image = Self.dotImage(color: .systemGreen)
            case "Split End":
                view.image = Self.dotImage(color: .black, checkered: true)
            case "Current Position":
                view.image = Self.dotImage(color: .systemOrange)
            default:
                view.image = Self.dotImage(color: .systemBlue)
            }
            view.centerOffset = .zero
            return view
        }

        private static func dotImage(color: UIColor, checkered: Bool = false) -> UIImage {
            let size: CGFloat = 14
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            return renderer.image { ctx in
                let rect = CGRect(x: 0, y: 0, width: size, height: size)
                UIColor.white.setFill()
                ctx.cgContext.fillEllipse(in: rect)
                let inner = rect.insetBy(dx: 2, dy: 2)
                color.setFill()
                ctx.cgContext.fillEllipse(in: inner)
                if checkered {
                    ctx.cgContext.saveGState()
                    ctx.cgContext.addEllipse(in: inner)
                    ctx.cgContext.clip()
                    UIColor.white.setFill()
                    let half = inner.width / 2
                    ctx.cgContext.fill(CGRect(x: inner.minX, y: inner.minY, width: half, height: half))
                    ctx.cgContext.fill(CGRect(x: inner.midX, y: inner.midY, width: half, height: half))
                    ctx.cgContext.restoreGState()
                }
            }
        }
    }
}

// MARK: - Helpers

private func ordinal(_ n: Int) -> String {
    let suffix: String
    switch (n % 100, n % 10) {
    case (11, _), (12, _), (13, _): suffix = "th"
    case (_, 1): suffix = "st"
    case (_, 2): suffix = "nd"
    case (_, 3): suffix = "rd"
    default: suffix = "th"
    }
    return "\(n)\(suffix)"
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(.primary)
        }
    }
}
