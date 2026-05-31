import SwiftUI

struct SportPickerView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        Picker("Sport", selection: Binding(
            get: { vm.sport },
            set: { vm.changeSport($0) }
        )) {
            ForEach(SportType.allCases) { sport in
                Label(sport.rawValue, systemImage: sport.icon).tag(sport)
            }
        }
        .pickerStyle(.segmented)
    }
}
