import SwiftUI

struct GoalSetterView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var customText = ""
    @State private var showCustom = false

    var body: some View {
        CardView(title: "Yearly Goal", systemImage: "target", accentColor: .green) {
            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.sport.quickGoals, id: \.self) { goal in
                            let selected = vm.yearlyGoalMiles == goal
                            Button(String(format: "%.0f mi", goal)) {
                                vm.setGoal(goal)
                                showCustom = false
                            }
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selected ? Color.blue : Color(uiColor: .tertiarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(selected ? .white : .primary)
                        }
                        Button("Custom…") { showCustom.toggle() }
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(showCustom ? Color.blue : Color(uiColor: .tertiarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(showCustom ? .white : .primary)
                    }
                }

                if showCustom {
                    HStack {
                        TextField("Miles", text: $customText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Button("Set") {
                            if let miles = Double(customText), miles > 0 {
                                vm.setGoal(miles)
                                showCustom = false
                                customText = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(Double(customText) == nil)
                    }
                }
            }
        }
    }
}
