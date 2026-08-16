import SwiftUI
import MapKit

struct RouteSelectionView: View {
    @ObservedObject var viewModel: RouteSelectionViewModel
    @ObservedObject var locationManager: LocationManager

    var onStart: (RouteOption) -> Void
    var onClose: () -> Void

    @State private var recenterTrigger = false
    @State private var sheetDetent: PresentationDetent = .medium

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                MapViewComponent(
                    recenterTrigger: $recenterTrigger,
                    centerCoordinate: locationManager.userLocation,
                    showsUserLocation: true,
                    routeCoordinates: viewModel.selectedRoute?.coordinates ?? [],
                    destinationCoordinate: viewModel.destination?.coordinate,
                    fitsRouteInView: true
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, 8)

                    Spacer()

                    HStack {
                        Spacer()
                        MapRoundTripToggle(
                            isOn: Binding(
                                get: { viewModel.isRoundTrip },
                                set: { viewModel.setRoundTrip($0) }
                            )
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, geometry.size.height * 0.54 + 12)
                }
            }
        }
        .sheet(isPresented: .constant(true)) {
            routeSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(22)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled(true)
                .presentationBackground {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.primary)
                    .frame(width: 28, height: 28)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            MapRouteEndpointBar(
                originTitle: viewModel.originTitle,
                destinationTitle: viewModel.destination?.title ?? "Destination"
            )
        }
        .padding(.horizontal, 16)
    }

    private func routeErrorState(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(Font.Brand.body)
                .foregroundStyle(Color.Brand.darkgray)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Retry", style: .outlined) {
                viewModel.retry()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var routeSheet: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 16)

            ZStack(alignment: .bottom) {
                if let routeError = viewModel.routeError {
                    routeErrorState(message: routeError)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 88)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.routes) { route in
                                RouteOptionCard(
                                    route: route,
                                    isSelected: route.id == viewModel.selectedRouteID
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.selectRoute(route)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        // Extra bottom inset so last cards can scroll above Start + glass fade
                        .padding(.bottom, 88)
                    }
                }

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .white.opacity(0.6), location: 0.25),
                                    .init(color: .white, location: 0.5)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    PrimaryButton(
                        title: "Start",
                        systemImage: "location.north.fill"
                    ) {
                        if let route = viewModel.selectedRoute {
                            onStart(route)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, -40)
                    .padding(.bottom, 12)
                }
                .frame(height: 130)
            }
        }
    }
}

private struct PreviewORSRoutingService: ORSRouting {
    func fetchRoutes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> [ORSRoute] {
        let midLat = (origin.latitude + destination.latitude) / 2
        let midLon = (origin.longitude + destination.longitude) / 2
        return [
            ORSRoute(
                coordinates: [origin, CLLocationCoordinate2D(latitude: midLat + 0.01, longitude: midLon), destination],
                distanceMeters: 20_000,
                durationSeconds: 5_400
            ),
            ORSRoute(
                coordinates: [origin, CLLocationCoordinate2D(latitude: midLat - 0.01, longitude: midLon - 0.01), destination],
                distanceMeters: 23_000,
                durationSeconds: 6_300
            ),
            ORSRoute(
                coordinates: [origin, CLLocationCoordinate2D(latitude: midLat + 0.005, longitude: midLon + 0.01), destination],
                distanceMeters: 18_000,
                durationSeconds: 4_800
            )
        ]
    }
}

#Preview {
    let vm = RouteSelectionViewModel(routingService: PreviewORSRoutingService())
    let dest = SelectedDestination(
        title: "BXChange Mall",
        subtitle: "BSD",
        coordinate: CLLocationCoordinate2D(latitude: -6.301, longitude: 106.653)
    )
    vm.configure(
        origin: CLLocationCoordinate2D(latitude: -6.29, longitude: 106.64),
        destination: dest
    )
    return RouteSelectionView(
        viewModel: vm,
        locationManager: LocationManager(),
        onStart: { _ in },
        onClose: {}
    )
}
