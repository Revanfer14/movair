import SwiftUI

struct ContentView: View {
    @StateObject private var navigationVM = WatchNavigationViewModel()
    @ObservedObject private var connectivity = WatchConnectivityManager.shared

    @State private var isDismissedToHome = false

    var body: some View {
        NavigationStack {
            Group {
                if isDismissedToHome && (navigationVM.state == .active || navigationVM.state == .paused) {
                    WatchIdleView()
                } else {
                    switch navigationVM.state {
                    case .idle:
                        WatchIdleView()
                    case .active, .paused:
                        WatchActiveNavigationView(
                            viewModel: navigationVM,
                            onDismiss: {
                                isDismissedToHome = true
                            }
                        )
                    case .completed:
                        WatchCompletedView()
                    }
                }
            }
        }
        .onAppear {
            connectivity.requestCurrentState()
        }
        .onChange(of: navigationVM.state) { _, newState in
            if newState == .active || newState == .paused {
                isDismissedToHome = false
            }
            if newState == .completed {
                isDismissedToHome = false
            }
            if newState == .idle {
                isDismissedToHome = false
            }
        }
    }
}

#Preview {
    ContentView()
}
