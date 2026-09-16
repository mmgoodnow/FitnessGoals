import SwiftUI

struct ActivityCalendarView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var selectedDate: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let days = vm.recentActivityDays(asOf: context.date)
            let maxMiles = days.map(\.miles).max() ?? 0
            let selected = days.first { $0.date == selectedDate } ?? days.first { $0.isToday }

            VStack(spacing: 8) {
                HStack {
                    if let first = days.first, let today = days.first(where: { $0.isToday }) {
                        Text("\(first.date.formatted(.dateTime.month(.abbreviated).day())) - \(today.date.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(weekdays, id: \.self) { weekday in
                        Text(weekday)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(days) { day in
                        Button {
                            selectedDate = day.date
                        } label: {
                            VStack(spacing: 3) {
                                Text(day.date, format: .dateTime.day())
                                    .font(.caption2.weight(day.isToday ? .bold : .regular))
                                    .foregroundStyle(day.isFuture ? Color.secondary.opacity(0.35) : Color.primary)
                                    .frame(height: 16)
                                    .overlay(alignment: .bottom) {
                                        if day.isToday {
                                            Capsule().fill(Color.indigo)
                                                .frame(width: 12, height: 2)
                                                .offset(y: 2)
                                        }
                                    }
                                ZStack {
                                    if day.miles > 0 && maxMiles > 0 {
                                        // Scale area with mileage, rather than diameter.
                                        let diameter = max(3, 28 * sqrt(day.miles / maxMiles))
                                        Circle()
                                            .fill(Color.indigo)
                                            .frame(width: diameter, height: diameter)
                                    } else if !day.isFuture {
                                        Circle()
                                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .frame(height: 30)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background {
                                if day.date == selected?.date {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.indigo.opacity(0.09))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(day.isFuture)
                        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(day.isFuture ? "Future date" : String(format: "%.1f miles%@", day.miles, day.isToday ? ", today" : ""))
                        .accessibilityAddTraits(day.date == selected?.date ? .isSelected : [])
                    }
                }

                HStack {
                    if let selected {
                        Text(selected.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f mi", selected.miles))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
                .font(.caption)
                .frame(minHeight: 20)
            }
        }
    }
}
