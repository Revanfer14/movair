import SwiftUI
import MapKit
import CoreLocation

private struct MapPoint: Equatable {
    let latitude: Double
    let longitude: Double

    init?(_ coordinate: CLLocationCoordinate2D?) {
        guard let coordinate else { return nil }
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }
}

struct WatchDirectionView: View {
    @ObservedObject var viewModel: WatchNavigationViewModel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isMapInteractive = false

    private var userMapPoint: MapPoint? {
        MapPoint(viewModel.userCoordinate)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, interactionModes: isMapInteractive ? .all : []) {
                if viewModel.routeCoordinates.count > 1 {
                    MapPolyline(coordinates: viewModel.routeCoordinates)
                        .stroke(Color.Brand.blue500, lineWidth: 4)
                }

                if let userCoordinate = viewModel.userCoordinate {
                    Annotation("", coordinate: userCoordinate) {
                        Circle()
                            .fill(Color.Brand.blue500)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.Brand.white, lineWidth: 2))
                    }
                }
            }
            .mapControls { }
            .onAppear {
                updateCamera(center: viewModel.userCoordinate)
            }
            .onChange(of: userMapPoint) { _, newValue in
                let coordinate = newValue.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                updateCamera(center: coordinate)
            }

            if !isMapInteractive {
                Color.black.opacity(0.13)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isMapInteractive = true
                    }
            }

            if !isMapInteractive {
                instructionBanner
            }
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if isMapInteractive {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isMapInteractive = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Lock map")
                }
            }
        }
    }

    private var instructionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.instructionSystemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.Brand.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedInstructionDistance)
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.Brand.white)

                if !viewModel.instructionStreetName.isEmpty {
                    Text(viewModel.instructionStreetName)
                        .font(Font.Brand.footnote)
                        .foregroundStyle(Color.Brand.darkgray)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.Brand.lightgray.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.instructionText.isEmpty ? "Directions" : viewModel.instructionText)
    }

    private func updateCamera(center: CLLocationCoordinate2D?) {
        guard let center else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
            )
        )
    }

    private var formattedInstructionDistance: String {
        let meters = viewModel.instructionDistanceMeters
        if meters < 1000 {
            let rounded = max(0, Int((meters / 10).rounded()) * 10)
            return "\(rounded) m"
        }
        return String(format: "%.1f km", meters / 1000)
    }
}

#Preview {
    NavigationStack {
        WatchDirectionView(
            viewModel: {
                let vm = WatchNavigationViewModel()
                vm.state = .active
                return vm
            }()
        )
    }
}
