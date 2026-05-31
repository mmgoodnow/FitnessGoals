import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DashboardViewModel()

    var body: some View {
        Group {
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
                TabView {
                    NavigationStack {
                        DashboardView()
                            .environmentObject(vm)
                    }
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    NavigationStack {
                        RecordsView()
                            .environmentObject(vm)
                    }
                    .tabItem {
                        Label("Records", systemImage: "trophy.fill")
                    }
                }
            }
        }
        .task { await vm.load() }
    }
}
