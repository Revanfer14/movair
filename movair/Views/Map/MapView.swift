import SwiftUI
import MapKit
import Combine

struct MapView: View {

    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchViewModel = MapSearchViewModel()

    @State private var isSearchPresented = false
    @State private var recenterTrigger = false
    @State private var searchSheetDetent: PresentationDetent = .large

    var body: some View {
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
        .onAppear {
            locationManager.requestPermission()
        }
        .onReceive(locationManager.$userLocation.compactMap { $0 }) { coordinate in
            searchViewModel.biasSearch(around: coordinate)
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
                recenterTrigger = true
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
}

#Preview {
    MapView()
}
