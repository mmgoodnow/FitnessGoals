import SwiftUI
import MapKit
import CoreLocation

struct WorkoutDetailView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    let workoutID: UUID

    @State private var routeData: HealthKitService.FullRouteData = .init(coordinates: [], segmentsByDistance: [:], splitsByDistance: [:])
    @State private var loadingRoute = true
    @State private var selectedDistance: Double? = nil

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

    var body: some View {
        NavigationStack {
            List {
                // Map section
                Section {
                    ZStack {
                        if routeData.coordinates.count > 1 {
                            RouteMapView(coordinates: routeData.coordinates, splitCoordinates: highlightCoords)
                                .frame(height: 220)
                                .listRowInsets(EdgeInsets())
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if loadingRoute {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 220)
                                .overlay {
                                    ProgressView()
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 80)
                                .overlay {
                                    Label("No route data", systemImage: "map.slash")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

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

                if !splitRows.isEmpty {
                    Section {
                        ForEach(splitRows) { dist in
                            let time = routeData.splitsByDistance[dist.meters] ?? 0
                            let isSelected = selectedDistance == dist.meters
                            let ranking = vm.rank(forSplit: time, distanceID: dist.id)
                            Button {
                                selectedDistance = dist.meters
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
                    } header: {
                        Text("Best Efforts")
                    } footer: {
                        Text("Tap a distance to highlight its fastest segment on the map.")
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
            .navigationTitle("Workout Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                routeData = await vm.fetchFullRouteData(for: workoutID)
                // Default-select the longest qualifying distance (most meaningful effort).
                selectedDistance = splitRows.last?.meters
                loadingRoute = false
            }
        }
    }
}

// MARK: - Route map

// Tag polylines so the renderer knows which color to use
private class TaggedPolyline: MKPolyline {
    enum Kind { case full, split }
    var kind: Kind = .full
}

struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let splitCoordinates: [CLLocationCoordinate2D]

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
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)
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
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        var lastFitKey: String?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? TaggedPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: polyline)
            switch polyline.kind {
            case .full:
                r.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
                r.lineWidth = 3
            case .split:
                r.strokeColor = UIColor.systemYellow
                r.lineWidth = 5
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
                view.image = Self.dotImage(color: .systemRed, checkered: true)
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
