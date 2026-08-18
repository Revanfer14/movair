import Foundation
import MapKit
import UIKit

enum RouteMapSnapshotError: Error {
    case insufficientCoordinates
    case renderingFailed
}

protocol RouteMapSnapshotting {
    func makeSnapshot(coordinates: [CLLocationCoordinate2D], size: CGSize, scale: CGFloat) async throws -> UIImage
}

final class RouteMapSnapshotter: RouteMapSnapshotting {
    func makeSnapshot(coordinates: [CLLocationCoordinate2D], size: CGSize, scale: CGFloat) async throws -> UIImage {
        guard coordinates.count >= 2 else {
            throw RouteMapSnapshotError.insufficientCoordinates
        }

        let options = MKMapSnapshotter.Options()
        options.region = paddedRegion(for: coordinates)
        options.size = size
        options.scale = scale
        options.mapType = .standard
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await snapshotter.start()

        guard let composedImage = drawRoute(coordinates, on: snapshot) else {
            throw RouteMapSnapshotError.renderingFailed
        }
        return composedImage
    }

    private func paddedRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLatitude = coordinates[0].latitude
        var maxLatitude = coordinates[0].latitude
        var minLongitude = coordinates[0].longitude
        var maxLongitude = coordinates[0].longitude

        for coordinate in coordinates {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let paddingFactor = 1.18
        let latitudeDelta = max((maxLatitude - minLatitude) * paddingFactor, 0.003)
        let longitudeDelta = max((maxLongitude - minLongitude) * paddingFactor, 0.003)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private func drawRoute(_ coordinates: [CLLocationCoordinate2D], on snapshot: MKMapSnapshotter.Snapshot) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)

            let points = coordinates.map { snapshot.point(for: $0) }
            guard let firstPoint = points.first, let lastPoint = points.last else { return }

            let path = UIBezierPath()
            path.move(to: firstPoint)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.lineWidth = 8
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.black.setStroke()
            path.stroke()

            drawStartMarker(at: firstPoint, in: context.cgContext)
            drawFinishMarker(at: lastPoint, in: context.cgContext)
        }
    }

    private func drawStartMarker(at point: CGPoint, in context: CGContext) {
        let radius: CGFloat = 9
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: -3, dy: -3))
        context.setFillColor(UIColor.black.cgColor)
        context.fillEllipse(in: rect)
    }

    private func drawFinishMarker(at point: CGPoint, in context: CGContext) {
        let radius: CGFloat = 9
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: -3, dy: -3))
        context.setFillColor(UIColor.black.cgColor)
        context.fillEllipse(in: rect)

        let flagSize: CGFloat = 28
        let flagImage = UIImage(
            systemName: "flag.checkered.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: flagSize, weight: .bold)
        )?.withTintColor(.black, renderingMode: .alwaysOriginal)

        flagImage?.draw(
            in: CGRect(
                x: point.x - flagSize / 2,
                y: point.y - radius - flagSize - 4,
                width: flagSize,
                height: flagSize
            )
        )
    }
}
