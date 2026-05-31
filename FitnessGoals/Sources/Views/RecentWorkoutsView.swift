import SwiftUI

struct RecentWorkoutsView: View {
    @EnvironmentObject var vm: DashboardViewModel

    private var recent: [Workout] { Array(vm.workouts.prefix(10)) }

    var body: some View {
        CardView(title: "Recent Workouts") {
            if recent.isEmpty {
                Text("No workouts this year")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { idx, workout in
                        WorkoutRow(workout: workout, sport: vm.sport)
                        if idx < recent.count - 1 {
                            Divider().padding(.leading, 16)
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
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: workout.startDate)
    }

    private var distanceStr: String {
        Formatters.formatMiles(workout.distance)
    }

    private var paceStr: String {
        guard let spm = workout.paceSecondsPerMeter else { return "—" }
        return sport.usesPace ? Formatters.formatPace(spm) : Formatters.formatSpeed(spm)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateStr).font(.subheadline).bold()
                Text(Formatters.formatDuration(workout.duration))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(distanceStr).font(.subheadline).bold()
                Text(paceStr).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}
