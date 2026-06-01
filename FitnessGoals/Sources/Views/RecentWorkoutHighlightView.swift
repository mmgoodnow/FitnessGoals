import SwiftUI

struct RecentWorkoutHighlightView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var selectedWorkout: WorkoutDetailTarget? = nil

    var body: some View {
        if let w = vm.mostRecentWorkout {
            CardView(title: "Last Workout", systemImage: "bolt.fill", accentColor: .orange) {
                HStack(alignment: .top, spacing: 20) {
                    // Date block
                    VStack(spacing: 2) {
                        Text(w.startDate.formatted(.dateTime.month(.wide)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(w.startDate.formatted(.dateTime.day()))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        Text(w.startDate.formatted(.dateTime.weekday(.wide)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 72)

                    Divider()

                    // 2x2 stats grid
                    VStack(spacing: 12) {
                        HStack(spacing: 0) {
                            HighlightStat(
                                label: "Distance",
                                value: Formatters.formatMiles(w.distance),
                                icon: "figure.run"
                            )
                            HighlightStat(
                                label: "Duration",
                                value: Formatters.formatDuration(w.duration),
                                icon: "clock"
                            )
                        }
                        HStack(spacing: 0) {
                            if let spm = w.paceSecondsPerMeter {
                                HighlightStat(
                                    label: "Pace",
                                    value: Formatters.formatPace(spm),
                                    icon: "speedometer"
                                )
                            }
                            if let hr = w.avgHeartRate {
                                let zone = HRZone.zone(for: hr, maxHR: vm.estimatedMaxHR)
                                HighlightStat(
                                    label: "Avg HR",
                                    value: String(format: "%.0f bpm", hr),
                                    icon: "heart.fill",
                                    valueColor: zone?.color ?? .primary,
                                    subtitle: zone?.name
                                )
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedWorkout = WorkoutDetailTarget(id: w.id)
            }
            .sheet(item: $selectedWorkout) { target in
                WorkoutDetailView(workoutID: target.id)
                    .environmentObject(vm)
            }
        }
    }
}

private struct HighlightStat: View {
    let label: String
    let value: String
    let icon: String
    var valueColor: Color = .primary
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
