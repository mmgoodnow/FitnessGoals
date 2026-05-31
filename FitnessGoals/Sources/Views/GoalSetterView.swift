import SwiftUI

struct GoalSetterView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var customText = ""
    @State private var showCustom = false

    var body: some View {
        CardView(title: "Yearly Goal") {
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.sport.quickGoals, id: \.self) { goal in
                            Button(String(format: "%.0f mi", goal)) {
                                vm.setGoal(goal)
                                showCustom = false
                            }
                            .buttonStyle(.bordered)
                            .tint(vm.yearlyGoalMiles == goal ? .blue : .secondary)
                        }
                        Button("Custom") { showCustom.toggle() }
                            .buttonStyle(.bordered)
                            .tint(showCustom ? .blue : .secondary)
                    }
                    .padding(.horizontal, 1)
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
