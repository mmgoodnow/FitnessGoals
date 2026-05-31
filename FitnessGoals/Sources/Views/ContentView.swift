import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DashboardViewModel()

    var body: some View {
        NavigationStack {
            if vm.isLoading && vm.workouts.isEmpty {
                ProgressView("Loading workouts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await vm.load() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                DashboardView()
                    .environmentObject(vm)
            }
        }
        .task { await vm.load() }
    }
}
