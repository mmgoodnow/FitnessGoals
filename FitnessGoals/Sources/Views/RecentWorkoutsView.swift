import SwiftUI

struct RecentWorkoutsView: View {
    @EnvironmentObject var vm: DashboardViewModel

    private var recent: [Workout] { Array(vm.workouts.prefix(10)) }

    var body: some View {
        CardView(title: "Recent Workouts", systemImage: "list.bullet.rectangle", accentColor: .gray) {
            if recent.isEmpty {
                Text("No workouts this year")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { idx, workout in
                        WorkoutRow(workout: workout, sport: vm.sport)
                        if idx < recent.count - 1 {
                            Divider().padding(.leading, 0)
                        }
                    }
                }
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let sport: SportType

    private var dateStr: String {
        workout.startDate.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated))
    }

    private var distanceStr: String { Formatters.formatMiles(workout.distance) }

    private var paceStr: String {
        guard let spm = workout.paceSecondsPerMeter else { return "—" }
        return sport.usesPace ? Formatters.formatPace(spm) : Formatters.formatSpeed(spm)
    }

    private var hrStr: String? {
        guard let hr = workout.avgHeartRate else { return nil }
        return String(format: "%.0f bpm", hr)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dateStr)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    Text(Formatters.formatDuration(workout.duration))
                        .font(.caption).foregroundStyle(.secondary)
                    if let hr = hrStr {
                        Label(hr, systemImage: "heart.fill")
                            .font(.caption).foregroundStyle(.red.opacity(0.8))
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(distanceStr)
                    .font(.subheadline.weight(.semibold))
                Text(paceStr)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
    }
}
