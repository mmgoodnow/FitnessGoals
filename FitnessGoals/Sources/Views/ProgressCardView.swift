import SwiftUI

struct ProgressCardView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        CardView(title: "Progress") {
            VStack(spacing: 16) {
                // Big progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(format: "%.1f mi", vm.totalMiles))
                            .font(.title2).bold()
                        Spacer()
                        Text(String(format: "%.0f%%", vm.progressFraction * 100))
                            .font(.title2).bold()
                            .foregroundStyle(.blue)
                    }
                    ProgressView(value: vm.progressFraction)
                        .tint(.blue)
                    Text("of \(String(format: "%.0f", vm.yearlyGoalMiles)) mi goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCell(
                        label: "Ahead / Behind",
                        value: String(format: "%+.1f mi", vm.milesAheadBehind),
                        color: vm.milesAheadBehind >= 0 ? .green : .red
                    )
                    StatCell(
                        label: "Req. Daily",
                        value: String(format: "%.2f mi/day", vm.requiredDailyMiles)
                    )
                    StatCell(
                        label: "Weekly Avg",
                        value: String(format: "%.1f mi/wk", vm.weeklyAverageMiles)
                    )
                    StatCell(
                        label: "Days Left",
                        value: "\(vm.daysRemaining)"
                    )
                }
            }
        }
    }
}

struct StatCell: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline).bold()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
