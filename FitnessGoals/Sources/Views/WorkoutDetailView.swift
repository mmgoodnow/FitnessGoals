import SwiftUI
import MapKit
import CoreLocation

struct WorkoutDetailView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    let point: DashboardViewModel.BestEffortPoint
    let distanceLabel: String
    let distanceMeters: Double

    @State private var coordinates: [CLLocationCoordinate2D] = []
    @State private var loadingRoute = true

    private var workout: Workout? { vm.workout(for: point.id) }
    private var isExcluded: Bool { vm.excludedWorkoutIDs.contains(point.id) }

    var body: some View {
        NavigationStack {
            List {
                // Map section
                Section {
                    ZStack {
                        if coordinates.count > 1 {
                            RouteMapView(coordinates: coordinates)
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
                    DetailRow(label: "Date", value: point.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    if let w = workout {
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

                Section("Best Effort") {
                    HStack {
                        Text(distanceLabel + " Split")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatTime(point.time))
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                    DetailRow(label: "Pace", value: formatPace(point.time, meters: distanceMeters))
                }

                Section {
                    Button(role: isExcluded ? nil : .destructive) {
                        vm.toggleExcluded(point.id)
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
                coordinates = await vm.fetchRouteCoordinates(for: point.id)
                loadingRoute = false
            }
        }
    }
}

// MARK: - Route map

struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.showsCompass = false
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)
        guard coordinates.count > 1 else { return }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        map.addOverlay(polyline)
        map.delegate = context.coordinator

        // Fit map to route with padding
        let rect = polyline.boundingMapRect
        map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24), animated: false)

        // Start dot
        let start = MKPointAnnotation()
        start.coordinate = coordinates.first!
        start.title = "Start"
        map.addAnnotation(start)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = UIColor.systemOrange
                r.lineWidth = 3
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "start")
            view.markerTintColor = .systemGreen
            view.glyphImage = UIImage(systemName: "figure.run")
            view.canShowCallout = false
            return view
        }
    }
}

// MARK: - Helpers

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
