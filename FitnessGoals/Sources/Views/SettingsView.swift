import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var customText = ""
    @State private var showCustom = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Yearly Goal") {
                    ForEach([100.0, 250, 500, 750, 1000], id: \.self) { goal in
                        Button {
                            vm.setGoal(goal)
                            showCustom = false
                        } label: {
                            HStack {
                                Text(String(format: "%.0f mi", goal))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if vm.yearlyGoalMiles == goal {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }

                    Button(showCustom ? "Cancel Custom" : "Custom…") {
                        showCustom.toggle()
                        customText = ""
                    }
                    .foregroundStyle(.blue)

                    if showCustom {
                        HStack {
                            TextField("Miles", text: $customText)
                                .keyboardType(.decimalPad)
                            Button("Set") {
                                if let miles = Double(customText), miles > 0 {
                                    vm.setGoal(miles)
                                    showCustom = false
                                    customText = ""
                                }
                            }
                            .disabled(Double(customText) == nil)
                        }
                    }
                }

                Section("Max Heart Rate") {
                    let options: [(p: Double, label: String)] = [
                        (0.99,   "p99"),
                        (0.999,  "p99.9"),
                        (0.9999, "p99.99"),
                    ]
                    ForEach(options, id: \.p) { opt in
                        let result = vm.hrPercentiles[opt.p]
                        Button {
                            vm.setHRPercentile(opt.p)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(opt.label)
                                        .foregroundStyle(.primary)
                                    if let r = result {
                                        Text("\(r.samplesAbove) samples above")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if let r = result {
                                    Text(String(format: "%.0f bpm", r.bpm))
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                }
                                if vm.selectedHRPercentile == opt.p {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                Section("HR Zones") {
                    let maxHR = vm.estimatedMaxHR
                    ForEach(HRZone.allCases) { zone in
                        let range = zone.bpmRange(maxHR: maxHR)
                        HStack {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 8, height: 8)
                            Text(zone.name)
                            Spacer()
                            Text(String(format: "%.0f–%.0f bpm", range.lowerBound, range.upperBound))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
