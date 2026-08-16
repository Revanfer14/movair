import SwiftUI
import MapKit
import Combine

struct MapView: View {

    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchViewModel = MapSearchViewModel()
    @StateObject private var routeSelectionViewModel = RouteSelectionViewModel()
    @StateObject private var activeNavigationViewModel = MapNavigationViewModel()
    @ObservedObject private var tripStore = TripHistoryStore.shared
    @ObservedObject private var phoneConnectivity = PhoneConnectivityManager.shared

    @State private var phase: NavigationPhase = .browsing
    @State private var isSearchPresented = false
    @State private var recenterTrigger = false
    @State private var searchSheetDetent: PresentationDetent = .large
    @State private var completedTrip: TripSummary?

    /// Simple elapsed-time tracker for the current ride (minutes).
    @State private var elapsedMinutes: Int = 0
    @State private var elapsedTimer: Timer?

    private var isRouteFlowPresented: Bool {
        phase == .routeSelection
            || phase == .navigating
            || phase == .paused
            || phase == .tripSummary
    }

    var body: some View {
        browsingContent
            .onAppear {
                locationManager.requestPermission()
                phoneConnectivity.activate()
                pushStateToWatch()
            }
            .onReceive(locationManager.$userLocation.compactMap { $0 }) { coordinate in
                searchViewModel.biasSearch(around: coordinate)
            }
            .onChange(of: searchViewModel.selectedDestination) { _, destination in
                guard let destination else { return }
                isSearchPresented = false
                routeSelectionViewModel.configure(
                    origin: locationManager.userLocation
                        ?? CLLocationCoordinate2D(latitude: -6.291, longitude: 106.641),
                    destination: destination
                )
                phase = .routeSelection
            }
            .onChange(of: phase) { _, newPhase in
                handlePhaseChange(newPhase)
            }
            .onChange(of: phoneConnectivity.incomingAction) { _, action in
                guard let action else { return }
                handleWatchAction(action)
                phoneConnectivity.consumeAction()
            }
            .onChange(of: activeNavigationViewModel.distanceKm) { _, _ in
                pushStateToWatch()
            }
            .onChange(of: activeNavigationViewModel.accumulatedExposureUg) { _, _ in
                pushStateToWatch()
            }
            .fullScreenCover(isPresented: Binding(
                get: { isRouteFlowPresented },
                set: { presented in
                    if !presented {
                        searchViewModel.clearSelection()
                        completedTrip = nil
                        phase = .browsing
                    }
                }
            )) {
                routeFlowContent
            }
    }

    @ViewBuilder
    private var routeFlowContent: some View {
        switch phase {
        case .routeSelection:
            RouteSelectionView(
                viewModel: routeSelectionViewModel,
                locationManager: locationManager,
                onStart: { route in
                    let origin = routeSelectionViewModel.originTitle
                    let destination = routeSelectionViewModel.destination?.title ?? "Destination"
                    activeNavigationViewModel.configure(
                        with: route,
                        originTitle: origin,
                        destinationTitle: destination,
                        originCoordinate: routeSelectionViewModel.currentOriginCoordinate,
                        destinationCoordinate: routeSelectionViewModel.destination?.coordinate
                    )
                    elapsedMinutes = 0
                    phase = .navigating
                },
                onClose: {
                    searchViewModel.clearSelection()
                    phase = .browsing
                }
            )
        case .navigating, .paused:
            ActiveNavigationView(
                viewModel: activeNavigationViewModel,
                locationManager: locationManager,
                isPaused: phase == .paused,
                onPause: { phase = .paused },
                onResume: { phase = .navigating },
                onFinish: {
                    finishRide()
                },
                onBack: {
                    phase = .routeSelection
                }
            )
        case .tripSummary:
            if let trip = completedTrip {
                TripSummaryView(trip: trip) {
                    searchViewModel.clearSelection()
                    completedTrip = nil
                    phase = .browsing
                }
            } else {
                Color.clear.onAppear {
                    phase = .browsing
                }
            }
        case .browsing:
            EmptyView()
        }
    }

    private var browsingContent: some View {
        ZStack(alignment: .top) {
            MapViewComponent(
                recenterTrigger: $recenterTrigger,
                centerCoordinate: locationManager.userLocation,
                showsUserLocation: true
            )
            .ignoresSafeArea()

            VStack {
                if !isSearchPresented {
                    searchBarOverlay
                }
                Spacer()
                recenterButton
            }
        }
        .sheet(isPresented: $isSearchPresented, onDismiss: {
            searchSheetDetent = .large
        }) {
            MapSearchSheet(viewModel: searchViewModel) {
                isSearchPresented = false
            }
            .presentationDetents([.large], selection: $searchSheetDetent)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }

    private var searchBarOverlay: some View {
        MapSearchComponent(
            placeholder: "Search for routes",
            onTap: { isSearchPresented = true }
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var recenterButton: some View {
        HStack {
            Spacer()
            Button {
                locationManager.requestPermission()
                if locationManager.userLocation != nil {
                    recenterTrigger = true
                }
            } label: {
                Image(systemName: "location.fill")
                    .foregroundStyle(Color.Brand.blue600)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
            }
            .accessibilityLabel("Center on my location")
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    // MARK: - Watch sync helpers

    private func handlePhaseChange(_ newPhase: NavigationPhase) {
        switch newPhase {
        case .navigating:
            startElapsedTimer()
        case .paused:
            stopElapsedTimer()
        case .tripSummary, .browsing, .routeSelection:
            stopElapsedTimer()
        }
        pushStateToWatch()
    }

    private func handleWatchAction(_ action: WCAction) {
        switch action {
        case .pause:
            if phase == .navigating {
                phase = .paused
            }
        case .resume:
            if phase == .paused {
                phase = .navigating
            }
        case .finish:
            if phase == .navigating || phase == .paused {
                finishRide()
            }
        case .requestState:
            pushStateToWatch()
        }
    }

    private func finishRide() {
        let trip = activeNavigationViewModel.makeTripSummary(completedAt: Date())
        tripStore.add(trip)
        completedTrip = trip
        phase = .tripSummary
    }

    private func pushStateToWatch() {
        phoneConnectivity.send(
            phase: phase,
            distanceKm: activeNavigationViewModel.distanceKm,
            exposureUg: activeNavigationViewModel.accumulatedExposureUg,
            elapsedMinutes: elapsedMinutes
        )
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                elapsedMinutes += 1
                pushStateToWatch()
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
}

#Preview {
    MapView()
}
