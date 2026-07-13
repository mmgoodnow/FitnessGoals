import SwiftUI

struct TopEventEffortsView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var selectedWorkout: WorkoutDetailTarget? = nil

    let selectedDistanceID: String

    private var distance: DashboardViewModel.BestEffortDistance? {
        DashboardViewModel.bestEffortDistances.first { $0.id == selectedDistanceID }
    }

    private var rankedEfforts: [(rank: Int, point: DashboardViewModel.BestEffortPoint)] {
        let points = vm.bestEffortProgressions[selectedDistanceID] ?? []
        return points
            .sorted { $0.time < $1.time }
            .prefix(10)
            .enumerated()
            .map { (rank: $0.offset + 1, point: $0.element) }
    }

    var body: some View {
        CardView(
            title: "Top \(distance?.label ?? selectedDistanceID) Runs",
            systemImage: "list.number",
            accentColor: .yellow
        ) {
            if vm.bestEffortsLoading && rankedEfforts.isEmpty {
                VStack(spacing: 8) {
                    ProgressView(value: vm.bestEffortsProgress)
                        .tint(.yellow)
                    Text("Analysing routes... \(Int(vm.bestEffortsProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if rankedEfforts.isEmpty {
                Text("No \(distance?.label ?? selectedDistanceID) efforts yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(rankedEfforts, id: \.point.id) { item in
                        Button {
                            selectedWorkout = WorkoutDetailTarget(id: item.point.id)
                        } label: {
                            TopEventEffortRow(
                                rank: item.rank,
                                point: item.point,
                                workout: vm.workout(for: item.point.id),
                                distanceMeters: distance?.meters ?? 0
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if item.point.id != rankedEfforts.last?.point.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedWorkout) { target in
            WorkoutDetailView(workoutID: target.id)
                .environmentObject(vm)
                .presentationDragIndicator(.visible)
        }
    }
}

private struct TopEventEffortRow: View {
    let rank: Int
    let point: DashboardViewModel.BestEffortPoint
    let workout: Workout?
    let distanceMeters: Double

    private var dateText: String {
        point.date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var workoutDistanceText: String? {
        guard let workout else { return nil }
        return Formatters.formatMiles(workout.distance)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(dateText)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    if let workoutDistanceText {
                        Text(workoutDistanceText)
                    }
                    if let heartRate = workout?.avgHeartRate {
                        Label(String(format: "%.0f bpm", heartRate), systemImage: "heart.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatTime(point.time))
                    .font(.subheadline.weight(.semibold))
                if distanceMeters > 0 {
                    Text(formatPace(point.time, meters: distanceMeters))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
    }
}
