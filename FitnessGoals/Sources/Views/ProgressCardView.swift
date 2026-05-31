import SwiftUI

struct ProgressCardView: View {
    @EnvironmentObject var vm: DashboardViewModel

    private var aheadColor: Color { vm.milesAheadBehind >= 0 ? .green : .red }

    var body: some View {
        CardView(title: "Progress", systemImage: "flag.fill", accentColor: .blue) {
            VStack(spacing: 16) {
                // Distance + percentage
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f", vm.totalMiles))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("mi")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 2)
                    Spacer()
                    Text(String(format: "%.0f%%", vm.progressFraction * 100))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(vm.progressFraction >= vm.dayFraction ? .green : .orange)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.quaternary)
                            .frame(height: 10)
                        // Target marker
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.secondary.opacity(0.5))
                            .frame(width: 2, height: 16)
                            .offset(x: geo.size.width * min(vm.dayFraction, 1) - 1)
                        // Actual progress
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(
                                colors: [.blue, vm.progressFraction >= vm.dayFraction ? .green : .blue],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * vm.progressFraction, height: 10)
                    }
                }
                .frame(height: 16)

                Text("of \(String(format: "%.0f", vm.yearlyGoalMiles)) mi goal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Divider()

                // Pace rows
                VStack(spacing: 10) {
                    PaceRow(
                        label: "YTD pace",
                        weekly: vm.weeklyAverageMiles,
                        annual: vm.weeklyAverageMiles * 52,
                        deltaLabel: String(format: "%+.1f mi", vm.milesAheadBehind),
                        deltaColor: aheadColor
                    )
                    Divider()
                    PaceRow(
                        label: "Needed to finish at goal",
                        weekly: vm.weeklyMilesNeeded,
                        annual: vm.yearlyGoalMiles,
                        deltaLabel: nil,
                        deltaColor: .primary
                    )
                }
            }
        }
    }
}

struct PaceRow: View {
    let label: String
    let weekly: Double
    let annual: Double
    let deltaLabel: String?
    let deltaColor: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f mi/wk", weekly))
                        .font(.subheadline.weight(.semibold))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(String(format: "%.0f mi/yr", annual))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let deltaLabel {
                Text(deltaLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(deltaColor)
            }
        }
    }
}

private extension DashboardViewModel {
    var dayFraction: Double {
        Double(dayOfYear) / Double(daysInYear)
    }
}
