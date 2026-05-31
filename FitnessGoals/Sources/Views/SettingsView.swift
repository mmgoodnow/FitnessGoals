import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var customText = ""
    @State private var showCustom = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sport") {
                    Picker("Sport", selection: Binding(
                        get: { vm.sport },
                        set: { vm.changeSport($0) }
                    )) {
                        ForEach(SportType.allCases) { sport in
                            Label(sport.rawValue, systemImage: sport.icon).tag(sport)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Yearly Goal") {
                    ForEach(vm.sport.quickGoals, id: \.self) { goal in
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

                Section("Heart Rate") {
                    let maxHR = vm.estimatedMaxHR
                    LabeledContent("Max HR (p99.9)", value: String(format: "%.0f bpm", maxHR))
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
