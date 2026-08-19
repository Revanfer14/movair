import SwiftUI

struct ContentView: View {
    @StateObject private var navigationVM = WatchNavigationViewModel()
    @ObservedObject private var connectivity = WatchConnectivityManager.shared

    @State private var activePage = 0

    var body: some View {
        NavigationStack {
            switch navigationVM.state {
            case .idle:
                WatchIdleView()
            case .active, .paused:
                TabView(selection: $activePage) {
                    WatchDirectionView(viewModel: navigationVM)
                        .tag(0)

                    WatchActiveNavigationView(viewModel: navigationVM)
                        .tag(1)
                }
                .tabViewStyle(.verticalPage)
            case .completed:
                WatchCompletedView()
            }
        }
        .onAppear {
            connectivity.requestCurrentState()
        }
        .onChange(of: navigationVM.state) { oldState, newState in
            let wasActiveOrPaused = oldState == .active || oldState == .paused
            let isActiveOrPaused = newState == .active || newState == .paused
            if isActiveOrPaused && !wasActiveOrPaused {
                activePage = 0
            }
        }
    }
}

#Preview {
    ContentView()
}
