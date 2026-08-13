import SwiftUI
import MapKit

struct MapViewComponent: UIViewRepresentable {
    @Binding var recenterTrigger: Bool
    
    var centerCoordinate: CLLocationCoordinate2D?
    var showsUserLocation: Bool = true

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456), // Jakarta fallback
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = showsUserLocation
        mapView.pointOfInterestFilter = .includingAll
        mapView.setRegion(Self.defaultRegion, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard let centerCoordinate else { return }

        if recenterTrigger || !context.coordinator.hasCenteredOnce {
            let region = MKCoordinateRegion(
                center: centerCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            mapView.setRegion(region, animated: true)
            context.coordinator.hasCenteredOnce = true

            if recenterTrigger {
                DispatchQueue.main.async { recenterTrigger = false }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var hasCenteredOnce = false
    }
}
