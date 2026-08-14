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
                        RoundTripToggle(
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
                .presentationDetents([.medium], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
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

            RouteEndpointBar(
                originTitle: viewModel.originTitle,
                destinationTitle: viewModel.destination?.title ?? "Destination"
            )
        }
        .padding(.horizontal, 16)
    }

    private var routeSheet: some View {
        VStack(spacing: 0) {
            // Space below grabber
            Color.clear.frame(height: 12)

            ZStack(alignment: .bottom) {
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

                // Glass fade + Start button pinned at bottom
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.001)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 28)
                    .background {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .mask(
                                LinearGradient(
                                    colors: [.clear, .black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    VStack(spacing: 0) {
                        PrimaryButton(
                            title: "Start",
                            systemImage: "location.north.fill"
                        ) {
                            if let route = viewModel.selectedRoute {
                                onStart(route)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
}

#Preview {
    let vm = RouteSelectionViewModel()
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
