import SwiftUI
import MapKit

struct MapViewComponent: UIViewRepresentable {
    @Binding var recenterTrigger: Bool

    var centerCoordinate: CLLocationCoordinate2D?
    var showsUserLocation: Bool = true
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var originCoordinate: CLLocationCoordinate2D? = nil
    var destinationCoordinate: CLLocationCoordinate2D? = nil
    var fitsRouteInView: Bool = false
    var routeEdgePadding: UIEdgeInsets = UIEdgeInsets(top: 120, left: 40, bottom: 280, right: 40)
    var showsOriginMarker: Bool = false

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

        let routeKey = Self.routeKey(routeCoordinates)

        if fitsRouteInView, routeCoordinates.count >= 2 {
            // Only refit when the route geometry actually changes — never on every SwiftUI refresh / pan.
            if routeKey != context.coordinator.lastFittedRouteKey {
                fitRoute(on: mapView)
                context.coordinator.lastFittedRouteKey = routeKey
                context.coordinator.hasCenteredOnce = true
            }
        } else if let centerCoordinate {
            let shouldCenter = recenterTrigger || !context.coordinator.hasCenteredOnce
            if shouldCenter {
                let region = MKCoordinateRegion(center: centerCoordinate, span: Self.userSpan)
                mapView.setRegion(region, animated: context.coordinator.hasCenteredOnce)
                context.coordinator.hasCenteredOnce = true
            }
        }

        if recenterTrigger {
            if fitsRouteInView, routeCoordinates.count >= 2 {
                fitRoute(on: mapView)
                context.coordinator.lastFittedRouteKey = routeKey
            } else if let centerCoordinate {
                let region = MKCoordinateRegion(center: centerCoordinate, span: Self.userSpan)
                mapView.setRegion(region, animated: true)
            }
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

        if showsOriginMarker, let originCoordinate {
            let origin = EndpointAnnotation(
                coordinate: originCoordinate,
                kind: .origin,
                title: "Origin"
            )
            mapView.addAnnotation(origin)
        }

        if let destinationCoordinate {
            let destination = EndpointAnnotation(
                coordinate: destinationCoordinate,
                kind: .destination,
                title: "Destination"
            )
            mapView.addAnnotation(destination)
        }
    }

    private func fitRoute(on mapView: MKMapView) {
        var rect = MKMapRect.null
        for coordinate in routeCoordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            rect = rect.union(pointRect)
        }
        guard !rect.isNull, !rect.isEmpty else { return }
        mapView.setVisibleMapRect(rect, edgePadding: routeEdgePadding, animated: true)
    }

    private static func routeKey(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard !coordinates.isEmpty else { return "empty" }
        let first = coordinates.first!
        let last = coordinates.last!
        let mid = coordinates[coordinates.count / 2]
        return String(
            format: "%d_%.5f,%.5f_%.5f,%.5f_%.5f,%.5f",
            coordinates.count,
            first.latitude, first.longitude,
            mid.latitude, mid.longitude,
            last.latitude, last.longitude
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewComponent
        var hasCenteredOnce = false
        var lastFittedRouteKey: String = ""

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

            if let endpoint = annotation as? EndpointAnnotation {
                let id = endpoint.kind == .origin ? "origin" : "destination"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                if let marker = view as? MKMarkerAnnotationView {
                    switch endpoint.kind {
                    case .origin:
                        marker.markerTintColor = UIColor(Color.Brand.blue600)
                        marker.glyphImage = UIImage(systemName: "location.fill")
                    case .destination:
                        marker.markerTintColor = UIColor(Color.Brand.blue700)
                        marker.glyphImage = UIImage(systemName: "flag.fill")
                    }
                    marker.canShowCallout = false
                }
                return view
            }

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

final class EndpointAnnotation: NSObject, MKAnnotation {
    enum Kind {
        case origin
        case destination
    }

    let coordinate: CLLocationCoordinate2D
    let kind: Kind
    var title: String?

    init(coordinate: CLLocationCoordinate2D, kind: Kind, title: String?) {
        self.coordinate = coordinate
        self.kind = kind
        self.title = title
    }
}
