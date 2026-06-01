import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    let point: DashboardViewModel.BestEffortPoint
    let distanceLabel: String
    let distanceMeters: Double

    private var workout: Workout? { vm.workout(for: point.id) }
    private var isExcluded: Bool { vm.excludedWorkoutIDs.contains(point.id) }

    var body: some View {
        NavigationStack {
            List {
                Section {
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
                } header: {
                    Text("Workout")
                }

                Section {
                    HStack {
                        Text(distanceLabel + " Split")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatTime(point.time))
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                    DetailRow(label: "Pace", value: formatPace(point.time, meters: distanceMeters))
                } header: {
                    Text("Best Effort")
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
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Excludes this workout from best effort calculations. Useful for GPS artifacts or accidental recordings.")
                            .foregroundStyle(.secondary)
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
        }
    }
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
