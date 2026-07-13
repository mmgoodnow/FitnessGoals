import SwiftUI

struct RecordsView: View {
    @EnvironmentObject var vm: DashboardViewModel
    @State private var selectedDistanceID: String = "5k"

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    BestEffortsView(selectedDistanceID: $selectedDistanceID)
                        .padding(.horizontal)
                    TopEventEffortsView(selectedDistanceID: selectedDistanceID)
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
