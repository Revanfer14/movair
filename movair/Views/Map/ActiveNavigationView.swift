import SwiftUI
import MapKit

struct ActiveNavigationView: View {
    @ObservedObject var viewModel: MapNavigationViewModel
    @ObservedObject var locationManager: LocationManager

    let isPaused: Bool
    var onPause: () -> Void
    var onResume: () -> Void
    var onFinish: () -> Void
    var onBack: (() -> Void)?

    @State private var recenterTrigger = false

    var body: some View {
        ZStack(alignment: .top) {
            MapViewComponent(
                recenterTrigger: $recenterTrigger,
                centerCoordinate: locationManager.userLocation,
                showsUserLocation: true,
                routeCoordinates: viewModel.routeCoordinates,
                displayedRouteCoordinates: viewModel.remainingRouteCoordinates,
                isOffRoute: viewModel.isOffRoute,
                originCoordinate: viewModel.originCoordinate,
                destinationCoordinate: viewModel.destinationCoordinate,
                fitsRouteInView: false,
                showsOriginMarker: true,
                isNavigationTracking: true,
                userHeading: locationManager.userHeading,
                routeHeading: viewModel.routeHeadingDegrees,
                navigationAltitude: 200,
                navigationPitch: 55
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if !viewModel.upcomingInstructions.isEmpty {
                    MapNavigationBanner(
                        instructions: viewModel.upcomingInstructions,
                        currentIndex: $viewModel.selectedUpcomingOffset
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                Spacer()

                mapControls

                MapNavigationStats(
                    mode: isPaused ? .paused : .active,
                    distanceKm: viewModel.distanceKm,
                    durationMinutes: viewModel.durationMinutes,
                    averageSpeedKmh: viewModel.averageSpeedKmh,
                    accumulatedExposureUg: viewModel.accumulatedExposureUg,
                    exposureLevel: viewModel.exposureLevel,
                    isOffRoute: viewModel.isOffRoute,
                    unattributedDurationMinutes: viewModel.unattributedDurationMinutes,
                    onPause: onPause,
                    onResume: onResume,
                    onFinish: onFinish
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $viewModel.hasArrivedAtDestination) {
            MapDestinationArrivalSheet(
                destinationTitle: viewModel.destinationTitle,
                distanceKm: viewModel.distanceKm,
                durationMinutes: viewModel.durationMinutes,
                averageSpeedKmh: viewModel.averageSpeedKmh,
                accumulatedExposureUg: viewModel.accumulatedExposureUg,
                exposureLevel: viewModel.exposureLevel,
                onConfirm: {
                    viewModel.hasArrivedAtDestination = false
                    onFinish()
                }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .presentationBackgroundInteraction(.disabled)
        }
    }

    private var mapControls: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                mapControlButton(systemName: "location.north.fill") {
                    locationManager.requestPermission()
                    recenterTrigger = true
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 10)
        }
    }

    private func mapControlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(Font.Brand.bodyBold)
                .foregroundStyle(Color.Brand.blue600)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let vm = MapNavigationViewModel()
    ActiveNavigationView(
        viewModel: vm,
        locationManager: LocationManager(),
        isPaused: false,
        onPause: {},
        onResume: {},
        onFinish: {}
    )
    .task {
        try? await vm.configure(
            with: RouteOption(
                title: "Cleaner Route",
                distanceKm: 14,
                durationMinutes: 37,
                exposureRangeUg: 100...120,
                exposureLevel: .low,
                pollutionDeltaPercent: -10,
                isRecommended: true,
                coordinates: [
                    CLLocationCoordinate2D(latitude: -6.29, longitude: 106.64),
                    CLLocationCoordinate2D(latitude: -6.30, longitude: 106.65)
                ]
            ),
            originTitle: "Current location",
            destinationTitle: "BXChange Mall"
        )
    }
}
