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

                // Stats grid
                HStack(spacing: 0) {
                    StatCell(label: "Ahead/Behind", value: String(format: "%+.1f mi", vm.milesAheadBehind), color: aheadColor)
                    Divider().frame(height: 36)
                    StatCell(label: "Req. Daily", value: String(format: "%.2f mi", vm.requiredDailyMiles))
                    Divider().frame(height: 36)
                    StatCell(label: "Wk Avg", value: String(format: "%.1f mi", vm.weeklyAverageMiles))
                    Divider().frame(height: 36)
                    StatCell(label: "Days Left", value: "\(vm.daysRemaining)")
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
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension DashboardViewModel {
    var dayFraction: Double {
        Double(dayOfYear) / Double(daysInYear)
    }
}
