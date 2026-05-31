import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    SportPickerView()
                        .padding(.horizontal)
                    RecentWorkoutHighlightView()
                        .padding(.horizontal)
                    GoalSetterView()
                        .padding(.horizontal)
                    ProgressCardView()
                        .padding(.horizontal)
                    ProgressChartView()
                        .padding(.horizontal)
                    WeeklyChartView()
                        .padding(.horizontal)
                    if vm.sport.usesPace {
                        PaceTrendView()
                            .padding(.horizontal)
                        HeartRateTrendView()
                            .padding(.horizontal)
                        VO2TrendView()
                            .padding(.horizontal)
                    }
                    WeekdayFrequencyChartView()
                        .padding(.horizontal)
                    WeekdayDistanceChartView()
                        .padding(.horizontal)
                    PaceAnalysisView()
                        .padding(.horizontal)
                    RecentWorkoutsView()
                        .padding(.horizontal)
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(vm.sport.rawValue + " Goals")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await vm.load() }
    }
}
