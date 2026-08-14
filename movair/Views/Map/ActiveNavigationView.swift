import SwiftUI
import MapKit

struct ActiveNavigationView: View {
    @ObservedObject var viewModel: ActiveNavigationViewModel
    @ObservedObject var locationManager: LocationManager

    let isPaused: Bool
    var onPause: () -> Void
    var onResume: () -> Void
    var onFinish: () -> Void
    var onBack: () -> Void

    @State private var recenterTrigger = false

    var body: some View {
        ZStack(alignment: .top) {
            MapViewComponent(
                recenterTrigger: $recenterTrigger,
                centerCoordinate: locationManager.userLocation,
                showsUserLocation: true,
                routeCoordinates: viewModel.routeCoordinates,
                destinationCoordinate: viewModel.routeCoordinates.last,
                fitsRouteInView: true
            )
            .ignoresSafeArea()

            VStack {
                if let instruction = viewModel.currentInstruction {
                    NavigationInstructionBanner(
                        distanceKm: instruction.distanceKm,
                        instruction: instruction.text,
                        pageCount: viewModel.instructions.count,
                        currentPage: viewModel.currentInstructionIndex,
                        onBack: onBack
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                Spacer()

                mapControls

                NavigationStatsPanel(
                    mode: isPaused ? .paused : .active,
                    distanceKm: viewModel.distanceKm,
                    durationMinutes: viewModel.durationMinutes,
                    averageSpeedKmh: viewModel.averageSpeedKmh,
                    accumulatedExposureUg: viewModel.accumulatedExposureUg,
                    exposureLevel: viewModel.exposureLevel,
                    onPause: onPause,
                    onResume: onResume,
                    onFinish: onFinish
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var mapControls: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                mapControlButton(systemName: "location.fill") {
                    locationManager.requestPermission()
                    recenterTrigger = true
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 8)
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
    let vm = ActiveNavigationViewModel()
    vm.configure(
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
        )
    )
    return ActiveNavigationView(
        viewModel: vm,
        locationManager: LocationManager(),
        isPaused: false,
        onPause: {},
        onResume: {},
        onFinish: {},
        onBack: {}
    )
}
