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

    private static let userSpan = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.showsCompass = true
        mapView.pointOfInterestFilter = .includingAll
        mapView.setRegion(Self.defaultRegion, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.showsUserLocation = showsUserLocation

        guard let centerCoordinate else { return }

        let shouldCenter = recenterTrigger || !context.coordinator.hasCenteredOnce
        guard shouldCenter else { return }

        let region = MKCoordinateRegion(center: centerCoordinate, span: Self.userSpan)
        mapView.setRegion(region, animated: context.coordinator.hasCenteredOnce)
        context.coordinator.hasCenteredOnce = true

        if recenterTrigger {
            DispatchQueue.main.async { recenterTrigger = false }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var hasCenteredOnce = false
    }
}
