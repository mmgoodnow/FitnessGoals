import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    RecentWorkoutHighlightView()
                        .padding(.horizontal)
                    ProgressCardView()
                        .padding(.horizontal)
                    ProgressChartView()
                        .padding(.horizontal)
                    WeeklyChartView()
                        .padding(.horizontal)
                    if vm.sport.usesPace {
                        BestEffortsView()
                            .padding(.horizontal)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(vm)
        }
        .refreshable { await vm.load() }
    }
}
