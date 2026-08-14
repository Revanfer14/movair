import SwiftUI
import MapKit

struct MapViewComponent: UIViewRepresentable {
    @Binding var recenterTrigger: Bool

    var centerCoordinate: CLLocationCoordinate2D?
    var showsUserLocation: Bool = true
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var destinationCoordinate: CLLocationCoordinate2D? = nil
    var fitsRouteInView: Bool = false

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    private static let userSpan = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.showsCompass = false
        mapView.pointOfInterestFilter = .includingAll
        mapView.setRegion(Self.defaultRegion, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.showsUserLocation = showsUserLocation
        context.coordinator.parent = self

        updateOverlays(on: mapView)
        updateAnnotations(on: mapView)

        if fitsRouteInView, routeCoordinates.count >= 2 {
            fitRoute(on: mapView)
            context.coordinator.hasCenteredOnce = true
        } else if let centerCoordinate {
            let shouldCenter = recenterTrigger || !context.coordinator.hasCenteredOnce
            if shouldCenter {
                let region = MKCoordinateRegion(center: centerCoordinate, span: Self.userSpan)
                mapView.setRegion(region, animated: context.coordinator.hasCenteredOnce)
                context.coordinator.hasCenteredOnce = true
            }
        }

        if recenterTrigger {
            DispatchQueue.main.async { recenterTrigger = false }
        }
    }

    private func updateOverlays(on mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        guard routeCoordinates.count >= 2 else { return }
        let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
        mapView.addOverlay(polyline)
    }

    private func updateAnnotations(on mapView: MKMapView) {
        let existing = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existing)

        if let destinationCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = destinationCoordinate
            annotation.title = "Destination"
            mapView.addAnnotation(annotation)
        }
    }

    private func fitRoute(on mapView: MKMapView) {
        var rect = MKMapRect.null
        for coordinate in routeCoordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            rect = rect.union(pointRect)
        }
        let inset = UIEdgeInsets(top: 80, left: 40, bottom: 220, right: 40)
        mapView.setVisibleMapRect(rect, edgePadding: inset, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewComponent
        var hasCenteredOnce = false

        init(parent: MapViewComponent) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color.Brand.blue600)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let id = "destination"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            if let marker = view as? MKMarkerAnnotationView {
                marker.markerTintColor = UIColor(Color.Brand.blue700)
                marker.glyphImage = UIImage(systemName: "flag.fill")
            }
            return view
        }
    }
}
