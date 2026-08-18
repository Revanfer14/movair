import SwiftUI
import MapKit

final class RoutePolyline: MKPolyline, @unchecked Sendable {
    var routeID: UUID = UUID()
    var isSelected: Bool = false
}

<<<<<<< Updated upstream
=======
final class DottedConnectorPolyline: MKPolyline, @unchecked Sendable {}

final class RouteStartAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    var title: String? = "Start of Route"

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

final class UserLocationAnnotationView: MKAnnotationView {
    private let arrowImageView = UIImageView()
    private let circleBackground = UIView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
    }

    private func setupUI() {
        frame = CGRect(x: 0, y: 0, width: 48, height: 48)
        centerOffset = CGPoint(x: 0, y: 0)
        canShowCallout = false
        backgroundColor = .clear

        circleBackground.frame = CGRect(x: 2, y: 2, width: 44, height: 44)
        circleBackground.backgroundColor = .white
        circleBackground.layer.cornerRadius = 22
        circleBackground.layer.shadowColor = UIColor.black.cgColor
        circleBackground.layer.shadowOpacity = 0.22
        circleBackground.layer.shadowOffset = CGSize(width: 0, height: 3)
        circleBackground.layer.shadowRadius = 5
        circleBackground.layer.borderWidth = 2
        circleBackground.layer.borderColor = UIColor.white.cgColor
        addSubview(circleBackground)

        arrowImageView.frame = CGRect(x: 10, y: 10, width: 24, height: 24)
        arrowImageView.contentMode = .scaleAspectFit
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        arrowImageView.image = UIImage(systemName: "location.north.fill", withConfiguration: config)
        arrowImageView.tintColor = UIColor(Color.Brand.blue600)
        circleBackground.addSubview(arrowImageView)
    }

    func updateHeading(deviceHeading: Double, cameraHeading: Double) {
        let relativeAngle = deviceHeading - cameraHeading
        let radians = relativeAngle * .pi / 180.0
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.arrowImageView.transform = CGAffineTransform(rotationAngle: CGFloat(radians))
        }
    }
}

>>>>>>> Stashed changes
struct MapViewComponent: UIViewRepresentable {
    @Binding var recenterTrigger: Bool

    var centerCoordinate: CLLocationCoordinate2D?
    var showsUserLocation: Bool = true
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var originCoordinate: CLLocationCoordinate2D?
    var destinationCoordinate: CLLocationCoordinate2D?
    var fitsRouteInView: Bool = false
    var routeEdgePadding: UIEdgeInsets = UIEdgeInsets(top: 120, left: 40, bottom: 280, right: 40)
    var showsOriginMarker: Bool = false
    var isInteractionEnabled: Bool = true
    var isNavigationTracking: Bool = false
    var userHeading: CLHeading?
    var routeHeading: Double?
    var navigationAltitude: CLLocationDistance = 200
    var navigationPitch: CGFloat = 55
    var routeOptions: [RouteOption] = []
    var selectedRouteID: UUID?
    var onSelectRouteID: ((UUID) -> Void)?

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
        mapView.isScrollEnabled = isInteractionEnabled
        mapView.isZoomEnabled = isInteractionEnabled
        mapView.isPitchEnabled = isInteractionEnabled
        mapView.isRotateEnabled = isInteractionEnabled
        mapView.setRegion(Self.defaultRegion, animated: false)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.showsUserLocation = showsUserLocation
        mapView.isScrollEnabled = isInteractionEnabled
        mapView.isZoomEnabled = isInteractionEnabled
        mapView.isPitchEnabled = isInteractionEnabled
        mapView.isRotateEnabled = isInteractionEnabled
        context.coordinator.parent = self

        updateOverlays(on: mapView)
        updateAnnotations(on: mapView)

        if let userView = mapView.view(for: mapView.userLocation) as? UserLocationAnnotationView {
            let deviceHeading: Double = {
                if let heading = userHeading {
                    let deg = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
                    if deg >= 0 { return deg }
                }
                return routeHeading ?? 0
            }()
            let cameraHeading = mapView.camera.heading
            userView.updateHeading(deviceHeading: deviceHeading, cameraHeading: cameraHeading)
        }

        if isNavigationTracking {
            updateNavigationCamera(on: mapView, context: context)
            return
        }

        let routeKey = effectiveRouteKey()

        if fitsRouteInView && hasValidRoutesToFit() {
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
            if fitsRouteInView && hasValidRoutesToFit() {
                fitRoute(on: mapView)
                context.coordinator.lastFittedRouteKey = routeKey
            } else if let centerCoordinate {
                let region = MKCoordinateRegion(center: centerCoordinate, span: Self.userSpan)
                mapView.setRegion(region, animated: true)
            }
            DispatchQueue.main.async { recenterTrigger = false }
        }
    }

    private func updateNavigationCamera(on mapView: MKMapView, context: Context) {
        guard let centerCoordinate else { return }

        let targetHeading: Double = {
            if let heading = userHeading {
                let deg = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
                if deg >= 0 { return deg }
            }
            if let routeHeading {
                return routeHeading
            }
            return mapView.camera.heading
        }()

        var targetAltitude = navigationAltitude
        if let firstCoord = routeCoordinates.first {
            let userLoc = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
            let startLoc = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
            let dist = userLoc.distance(from: startLoc)
            if dist > 15 && dist < 300 {
                targetAltitude = max(navigationAltitude, dist * 2.2)
            }
        }

        let isInitial = !context.coordinator.hasCenteredNavigation
        let shouldForceUpdate = recenterTrigger || isInitial

        if shouldForceUpdate {
            let camera = MKMapCamera(
                lookingAtCenter: centerCoordinate,
                fromDistance: targetAltitude,
                pitch: navigationPitch,
                heading: targetHeading
            )
            mapView.setCamera(camera, animated: !isInitial)
            context.coordinator.hasCenteredNavigation = true
            context.coordinator.userHasDraggedMap = false
            context.coordinator.lastAppliedHeading = targetHeading
            context.coordinator.lastAppliedCenter = centerCoordinate
            if recenterTrigger {
                DispatchQueue.main.async { recenterTrigger = false }
            }
            return
        }

        if !context.coordinator.userHasDraggedMap {
            let lastHeading = context.coordinator.lastAppliedHeading
            let angleDiff = abs(Self.shortestAngleDifference(from: lastHeading, to: targetHeading))

            let lastCenter = context.coordinator.lastAppliedCenter
            let centerMoved: Bool = {
                guard let lastCenter else { return true }
                let l1 = CLLocation(latitude: lastCenter.latitude, longitude: lastCenter.longitude)
                let l2 = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
                return l1.distance(from: l2) >= 3
            }()

            if angleDiff >= 4.5 || centerMoved {
                let camera = MKMapCamera(
                    lookingAtCenter: centerCoordinate,
                    fromDistance: targetAltitude,
                    pitch: navigationPitch,
                    heading: targetHeading
                )
                mapView.setCamera(camera, animated: true)
                context.coordinator.lastAppliedHeading = targetHeading
                context.coordinator.lastAppliedCenter = centerCoordinate
            }
        }
    }

    private static func shortestAngleDifference(from: Double, to: Double) -> Double {
        let diff = (to - from + 540).truncatingRemainder(dividingBy: 360) - 180
        return diff
    }

    private func updateOverlays(on mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)

<<<<<<< Updated upstream
=======
        if isNavigationTracking, let userCoord = centerCoordinate, let firstRouteCoord = routeCoordinates.first {
            let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
            let startLoc = CLLocation(latitude: firstRouteCoord.latitude, longitude: firstRouteCoord.longitude)
            let distanceToStart = userLoc.distance(from: startLoc)

            if distanceToStart > 10 {
                let connector = DottedConnectorPolyline(coordinates: [userCoord, firstRouteCoord], count: 2)
                mapView.addOverlay(connector)
            }
        }

>>>>>>> Stashed changes
        if !routeOptions.isEmpty {
            let unselectedRoutes = routeOptions.filter { $0.id != selectedRouteID }
            for route in unselectedRoutes {
                guard route.coordinates.count >= 2 else { continue }
                let polyline = RoutePolyline(coordinates: route.coordinates, count: route.coordinates.count)
                polyline.routeID = route.id
                polyline.isSelected = false
                mapView.addOverlay(polyline)
            }

            if let selectedRoute = routeOptions.first(where: { $0.id == selectedRouteID }), selectedRoute.coordinates.count >= 2 {
                let polyline = RoutePolyline(coordinates: selectedRoute.coordinates, count: selectedRoute.coordinates.count)
                polyline.routeID = selectedRoute.id
                polyline.isSelected = true
                mapView.addOverlay(polyline)
            }
        } else if routeCoordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            mapView.addOverlay(polyline)
        }
    }

    private func updateAnnotations(on mapView: MKMapView) {
        let existing = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existing)

        if isNavigationTracking, let firstCoord = routeCoordinates.first {
            let startAnnotation = RouteStartAnnotation(coordinate: firstCoord)
            mapView.addAnnotation(startAnnotation)
        }

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

    private func hasValidRoutesToFit() -> Bool {
        if !routeOptions.isEmpty {
            return routeOptions.contains { $0.coordinates.count >= 2 }
        }
        return routeCoordinates.count >= 2
    }

    private func fitRoute(on mapView: MKMapView) {
        var rect = MKMapRect.null

        if !routeOptions.isEmpty {
            for route in routeOptions {
                for coordinate in route.coordinates {
                    let point = MKMapPoint(coordinate)
                    let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
                    rect = rect.union(pointRect)
                }
            }
        } else {
            for coordinate in routeCoordinates {
                let point = MKMapPoint(coordinate)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
                rect = rect.union(pointRect)
            }
        }

        if let originCoordinate {
            let point = MKMapPoint(originCoordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1))
        }
        if let destinationCoordinate {
            let point = MKMapPoint(destinationCoordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1))
        }
        guard !rect.isNull, !rect.isEmpty else { return }
        mapView.setVisibleMapRect(rect, edgePadding: routeEdgePadding, animated: false)
    }

    private func effectiveRouteKey() -> String {
        if !routeOptions.isEmpty {
            let ids = routeOptions.map(\.id.uuidString).joined(separator: "_")
            return "\(ids)_\(selectedRouteID?.uuidString ?? "none")"
        }
        guard !routeCoordinates.isEmpty else { return "empty" }
        let first = routeCoordinates.first!
        let last = routeCoordinates.last!
        let mid = routeCoordinates[routeCoordinates.count / 2]
        return String(
            format: "%d_%.5f,%.5f_%.5f,%.5f_%.5f,%.5f",
            routeCoordinates.count,
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
        var hasCenteredNavigation = false
        var lastFittedRouteKey: String = ""
        var userHasDraggedMap = false
        var lastAppliedHeading: Double = 0
        var lastAppliedCenter: CLLocationCoordinate2D?

        init(parent: MapViewComponent) {
            self.parent = parent
        }

        @objc func handleMapTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView = recognizer.view as? MKMapView else { return }
            guard !parent.routeOptions.isEmpty else { return }

            let touchPoint = recognizer.location(in: mapView)
            let touchCoord = mapView.convert(touchPoint, toCoordinateFrom: mapView)

            var bestRouteID: UUID?
            var minDistance: Double = .greatestFiniteMagnitude

            for route in parent.routeOptions {
                let d = distanceToPolyline(coordinate: touchCoord, coordinates: route.coordinates, in: mapView)
                if d < minDistance {
                    minDistance = d
                    bestRouteID = route.id
                }
            }

            if let bestRouteID, minDistance <= 35 {
                if bestRouteID != parent.selectedRouteID {
                    parent.onSelectRouteID?(bestRouteID)
                }
            }
        }

        private func distanceToPolyline(coordinate: CLLocationCoordinate2D, coordinates: [CLLocationCoordinate2D], in mapView: MKMapView) -> Double {
            guard coordinates.count >= 2 else { return .greatestFiniteMagnitude }
            let pPoint = mapView.convert(coordinate, toPointTo: mapView)
            var minScreenDistance = Double.greatestFiniteMagnitude

            for i in 0..<(coordinates.count - 1) {
                let pt1 = mapView.convert(coordinates[i], toPointTo: mapView)
                let pt2 = mapView.convert(coordinates[i + 1], toPointTo: mapView)
                let d = pointToSegmentScreenDistance(point: pPoint, p1: pt1, p2: pt2)
                if d < minScreenDistance {
                    minScreenDistance = d
                }
            }
            return minScreenDistance
        }

        private func pointToSegmentScreenDistance(point: CGPoint, p1: CGPoint, p2: CGPoint) -> Double {
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let lengthSquared = dx * dx + dy * dy
            if lengthSquared == 0 {
                return hypot(Double(point.x - p1.x), Double(point.y - p1.y))
            }
            let t = max(0, min(1, ((point.x - p1.x) * dx + (point.y - p1.y) * dy) / lengthSquared))
            let projX = p1.x + t * dx
            let projY = p1.y + t * dy
            return hypot(Double(point.x - projX), Double(point.y - projY))
        }

        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            if mode == .none {
                userHasDraggedMap = true
            } else {
                userHasDraggedMap = false
            }
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            let view = mapView.subviews.first
            if let gestureRecognizers = view?.gestureRecognizers {
                for recognizer in gestureRecognizers where recognizer.state == .began || recognizer.state == .changed {
                    userHasDraggedMap = true
                    break
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
<<<<<<< Updated upstream
=======
            if overlay is DottedConnectorPolyline {
                let renderer = MKPolylineRenderer(overlay: overlay)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.85)
                renderer.lineWidth = 6
                renderer.lineCap = .round
                renderer.lineDashPattern = [1, 12]
                return renderer
            }

>>>>>>> Stashed changes
            if let routePolyline = overlay as? RoutePolyline {
                let renderer = MKPolylineRenderer(polyline: routePolyline)
                if routePolyline.isSelected {
                    renderer.strokeColor = UIColor(Color.Brand.blue600)
                    renderer.lineWidth = 6.5
                } else {
                    renderer.strokeColor = UIColor(Color.Brand.blue600.opacity(0.38))
                    renderer.lineWidth = 5.5
                }
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }

            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color.Brand.blue600)
                renderer.lineWidth = 5.5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let id = "userLocation"
                let userView = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? UserLocationAnnotationView
                    ?? UserLocationAnnotationView(annotation: annotation, reuseIdentifier: id)
                userView.annotation = annotation
                let deviceHeading = parent.userHeading?.trueHeading ?? parent.userHeading?.magneticHeading ?? parent.routeHeading ?? 0
                let cameraHeading = mapView.camera.heading
                userView.updateHeading(deviceHeading: deviceHeading, cameraHeading: cameraHeading)
                return userView
            }

            if annotation is RouteStartAnnotation {
                let id = "routeStart"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
                view.backgroundColor = .white
                view.layer.cornerRadius = 10
                view.layer.borderWidth = 4
                view.layer.borderColor = UIColor(Color.Brand.blue600).cgColor
                view.layer.shadowColor = UIColor.black.cgColor
                view.layer.shadowOpacity = 0.25
                view.layer.shadowOffset = CGSize(width: 0, height: 2)
                view.layer.shadowRadius = 3
                view.canShowCallout = false
                return view
            }

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
