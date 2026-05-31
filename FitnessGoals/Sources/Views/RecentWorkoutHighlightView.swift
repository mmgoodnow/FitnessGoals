import SwiftUI

struct RecentWorkoutHighlightView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        if let w = vm.mostRecentWorkout {
            CardView(title: "Last Workout", systemImage: "bolt.fill", accentColor: .orange) {
                HStack(alignment: .top, spacing: 16) {
                    // Date block
                    VStack(spacing: 2) {
                        Text(w.startDate.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(w.startDate.formatted(.dateTime.weekday(.wide)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 64)

                    Divider()

                    // Stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
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
                        if let spm = w.paceSecondsPerMeter {
                            HighlightStat(
                                label: vm.sport.usesPace ? "Pace" : "Speed",
                                value: vm.sport.usesPace ? Formatters.formatPace(spm) : Formatters.formatSpeed(spm),
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
    }
}

private struct HighlightStat: View {
    let label: String
    let value: String
    let icon: String
    var valueColor: Color = .primary
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(valueColor)
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
