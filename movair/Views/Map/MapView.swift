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
    private let routePlanArchiver: RoutePlanArchiving = RoutePlanArchiver()
    private let rideRecordArchiver: RideRecordArchiving = RideRecordArchiver.shared

    @State private var phase: NavigationPhase = .browsing
    @State private var isSearchPresented = false
    @State private var recenterTrigger = false
    @State private var searchSheetDetent: PresentationDetent = .large
    @State private var completedTrip: TripSummary?
    @State private var isStartingNavigation = false
    @State private var navigationStartError: String?

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
            .onReceive(locationManager.$latestLocation.compactMap { $0 }) { location in
                guard phase == .navigating else { return }
                activeNavigationViewModel.process(location: location)
            }
            .onReceive(phoneConnectivity.$latestHeartRateBPM) { bpm in
                activeNavigationViewModel.updateHeartRate(bpm)
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
            .onChange(of: activeNavigationViewModel.durationMinutes) { _, _ in
                pushStateToWatch()
            }
            .fullScreenCover(isPresented: Binding(
                get: { isRouteFlowPresented },
                set: { presented in
                    if !presented {
                        searchViewModel.clearSelection()
                        completedTrip = nil
                        phoneConnectivity.resetToIdle()
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
                    guard !isStartingNavigation else { return }
                    isStartingNavigation = true
                    navigationStartError = nil
                    let origin = routeSelectionViewModel.originTitle
                    let destination = routeSelectionViewModel.destination?.title ?? "Destination"
                    let planID = UUID().uuidString
                    phoneConnectivity.resetForNewRide()
                    Task {
                        defer { isStartingNavigation = false }
                        do {
                            try await activeNavigationViewModel.configure(
                                with: route,
                                originTitle: origin,
                                destinationTitle: destination,
                                originCoordinate: routeSelectionViewModel.currentOriginCoordinate,
                                destinationCoordinate: routeSelectionViewModel.destination?.coordinate,
                                routePlanID: planID
                            )
                            locationManager.startRideTracking()
                            phase = .navigating
                            if let payload = routeSelectionViewModel.routePlanPayload(chosenRouteID: route.id, planID: planID) {
                                Task.detached(priority: .background) {
                                    await routePlanArchiver.archive(payload)
                                }
                            }
                        } catch {
                            navigationStartError = (error as? ExposureEstimationError)?.userMessage
                                ?? "Live exposure tracking could not be started. Please try again."
                        }
                    }
                },
                onClose: {
                    searchViewModel.clearSelection()
                    phoneConnectivity.resetToIdle()
                    phase = .browsing
                }
            )
            .alert(
                "Unable to start ride",
                isPresented: Binding(
                    get: { navigationStartError != nil },
                    set: { if !$0 { navigationStartError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    navigationStartError = nil
                }
            } message: {
                Text(navigationStartError ?? "")
            }
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
                    phoneConnectivity.resetToIdle()
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
                showsUserLocation: true,
                userHeading: locationManager.userHeading
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

    private func handlePhaseChange(_ newPhase: NavigationPhase) {
        switch newPhase {
        case .navigating:
            activeNavigationViewModel.resumeTracking()
        case .paused:
            activeNavigationViewModel.pauseTracking()
        case .tripSummary, .browsing, .routeSelection:
            activeNavigationViewModel.pauseTracking()
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
        locationManager.stopRideTracking()
        Task {
            let trip = await activeNavigationViewModel.finishRide(completedAt: Date())
            tripStore.add(trip)
            completedTrip = trip
            phoneConnectivity.resetHeartRate()
            activeNavigationViewModel.updateHeartRate(nil)
            phase = .tripSummary
            if let payload = activeNavigationViewModel.lastRideRecordPayload {
                Task.detached(priority: .background) {
                    await rideRecordArchiver.archive(payload)
                }
            }
        }
    }

    private func pushStateToWatch() {
        phoneConnectivity.send(
            phase: phase,
            distanceKm: activeNavigationViewModel.distanceKm,
            exposureUg: activeNavigationViewModel.accumulatedExposureUg,
            elapsedMinutes: activeNavigationViewModel.durationMinutes
        )
    }
}

#Preview {
    MapView()
}
