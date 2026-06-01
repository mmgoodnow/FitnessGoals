import SwiftUI

struct RecordsView: View {
    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    BestEffortsView()
                        .padding(.horizontal)
                    RecentWorkoutsView()
                        .padding(.horizontal)
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await vm.load() }
    }
}
