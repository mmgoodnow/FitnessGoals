import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SportPickerView()
                GoalSetterView()
                ProgressCardView()
                ProgressChartView()
                WeeklyChartView()
                WeekdayAverageChartView()
                PaceAnalysisView()
                RecentWorkoutsView()
            }
            .padding()
        }
        .navigationTitle(vm.sport.rawValue + " Goals")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await vm.load() }
    }
}
