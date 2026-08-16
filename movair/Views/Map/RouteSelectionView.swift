import SwiftUI
import MapKit
import Combine

private enum EndpointEditTarget: Identifiable {
    case origin
    case destination

    var id: String {
        switch self {
        case .origin: return "origin"
        case .destination: return "destination"
        }
    }

    var title: String {
        switch self {
        case .origin: return "Choose origin"
        case .destination: return "Choose destination"
        }
    }
}

struct RouteSelectionView: View {
    @ObservedObject var viewModel: RouteSelectionViewModel
    @ObservedObject var locationManager: LocationManager

    var onStart: (RouteOption) -> Void
    var onClose: () -> Void

    @State private var recenterTrigger = false
    @State private var endpointEditTarget: EndpointEditTarget?
    @StateObject private var endpointSearchViewModel = MapSearchViewModel()

    private let panelHeightRatio: CGFloat = 0.48

    var body: some View {
        GeometryReader { geometry in
            let panelHeight = max(280, geometry.size.height * panelHeightRatio)

            ZStack(alignment: .bottom) {
                MapViewComponent(
                    recenterTrigger: $recenterTrigger,
                    centerCoordinate: locationManager.userLocation,
                    showsUserLocation: true,
                    routeCoordinates: viewModel.selectedRoute?.coordinates ?? [],
                    destinationCoordinate: viewModel.destination?.coordinate,
                    fitsRouteInView: true
                )
                .ignoresSafeArea()

                // Endpoint bar
                VStack(spacing: 0) {
                    topBar
                        .padding(.top, 8)
                    Spacer(minLength: 0)
                }

                // Round Trip toggle
                VStack(spacing: 10) {
                    HStack {
                        Spacer(minLength: 0)
                        MapRoundTripToggle(
                            isOn: Binding(
                                get: { viewModel.isRoundTrip },
                                set: { viewModel.setRoundTrip($0) }
                            )
                        )
                    }
                    .padding(.horizontal, 8)

                    routePanel
                        .frame(height: panelHeight)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            viewModel.updateUserLocation(locationManager.userLocation)
            if let coordinate = locationManager.userLocation {
                endpointSearchViewModel.biasSearch(around: coordinate)
            }
        }
        .onReceive(locationManager.$userLocation.compactMap { $0 }) { coordinate in
            viewModel.updateUserLocation(coordinate)
            endpointSearchViewModel.biasSearch(around: coordinate)
        }
        .sheet(item: $endpointEditTarget) { target in
            endpointSearchSheet(for: target)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
        .onChange(of: endpointSearchViewModel.selectedDestination) { _, place in
            guard let place, let target = endpointEditTarget else { return }
            applyEndpointSelection(place, for: target)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // Top bar
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
                destinationTitle: viewModel.destination?.title ?? "Destination",
                onEditOrigin: {
                    openEndpointSearch(.origin)
                },
                onEditDestination: {
                    openEndpointSearch(.destination)
                },
                onSwap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.swapEndpoints()
                    }
                }
            )
        }
        .padding(.horizontal, 16)
    }

    // Glass route panel
    private var routePanel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 10)

            ZStack(alignment: .bottom) {
                Group {
                    if viewModel.isLoading && viewModel.routes.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let routeError = viewModel.routeError {
                        routeErrorState(message: routeError)
                            .padding(.horizontal, 16)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.routes) { route in
                                    MapRouteOptionCard(
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
                            .padding(.bottom, 108)
                        }
                    }
                }

                // Footer
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 32)
                        .mask(
                            LinearGradient(
                                colors: [.clear, .white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)

                    PrimaryButton(
                        title: "Start",
                        systemImage: "location.north.fill"
                    ) {
                        if let route = viewModel.selectedRoute {
                            onStart(route)
                        }
                    }
                    .disabled(viewModel.selectedRoute == nil)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                    .background {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .ignoresSafeArea(edges: .bottom)
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: -6)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .ignoresSafeArea(edges: .bottom)
    }

    // Endpoint search
    private func openEndpointSearch(_ target: EndpointEditTarget) {
        endpointSearchViewModel.searchText = ""
        endpointSearchViewModel.clearSelection()
        endpointEditTarget = target
    }

    private func applyEndpointSelection(_ place: SelectedDestination, for target: EndpointEditTarget) {
        switch target {
        case .origin:
            viewModel.updateOrigin(to: place)
        case .destination:
            viewModel.updateDestination(to: place)
        }
        endpointSearchViewModel.clearSelection()
        endpointEditTarget = nil
    }

    @ViewBuilder
    private func endpointSearchSheet(for target: EndpointEditTarget) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if target == .origin {
                        currentLocationRow
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                    }

                    endpointSearchSectionHeader
                    endpointSearchResults
                        .padding(.horizontal)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        endpointSearchViewModel.clearSelection()
                        endpointEditTarget = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(Font.Brand.body)
                            .foregroundStyle(Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
        }
        .searchable(
            text: $endpointSearchViewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: target == .origin ? "Search starting point" : "Search destination"
        )
        .autocorrectionDisabled()
        .background(Color(.systemGroupedBackground))
    }

    private var currentLocationRow: some View {
        Button {
            viewModel.updateOriginToCurrentLocation()
            endpointSearchViewModel.clearSelection()
            endpointEditTarget = nil
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundStyle(Color.Brand.blue600)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current location")
                        .font(Font.Brand.body)
                        .foregroundStyle(Color.primary)
                    Text("Use your GPS position")
                        .font(Font.Brand.footnote)
                        .foregroundStyle(Color.Brand.darkgray)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use current location")
    }

    @ViewBuilder
    private var endpointSearchSectionHeader: some View {
        if endpointSearchViewModel.searchText.isEmpty {
            if !endpointSearchViewModel.recents.isEmpty {
                Text("Recents")
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.Brand.blue600)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        } else {
            Text("Results")
                .font(Font.Brand.bodyBold)
                .foregroundStyle(Color.Brand.blue600)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var endpointSearchResults: some View {
        if endpointSearchViewModel.searchText.isEmpty {
            SearchRecentList(
                recents: endpointSearchViewModel.recents,
                onSelect: { endpointSearchViewModel.selectRecent($0) },
                onDelete: { endpointSearchViewModel.deleteRecent($0) }
            )
        } else {
            SearchResultList(
                results: endpointSearchViewModel.results,
                onSelect: { endpointSearchViewModel.selectResult($0) }
            )
        }
    }

    private func routeErrorState(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(Font.Brand.body)
                .foregroundStyle(Color.Brand.darkgray)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Retry", style: .unfilled) {
                viewModel.retry()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
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
