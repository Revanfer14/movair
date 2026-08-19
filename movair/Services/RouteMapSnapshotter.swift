import Foundation
import MapKit
import UIKit
import SwiftUI

enum RouteMapSnapshotError: Error {
    case insufficientCoordinates
    case renderingFailed
}

protocol RouteMapSnapshotting {
    func makeSnapshot(
        traceCoordinates: [CLLocationCoordinate2D],
        plannedCoordinates: [CLLocationCoordinate2D],
        size: CGSize,
        scale: CGFloat,
        contentInsets: UIEdgeInsets
    ) async throws -> UIImage
}

final class RouteMapSnapshotter: RouteMapSnapshotting {
    private let minimumFittedSpanMeters = 600.0

    func makeSnapshot(
        traceCoordinates: [CLLocationCoordinate2D],
        plannedCoordinates: [CLLocationCoordinate2D],
        size: CGSize,
        scale: CGFloat,
        contentInsets: UIEdgeInsets
    ) async throws -> UIImage {
        let hasTrace = traceCoordinates.count >= 2
        let coordinatesToFit = hasTrace ? traceCoordinates : plannedCoordinates
        guard coordinatesToFit.count >= 2 else {
            throw RouteMapSnapshotError.insufficientCoordinates
        }

        guard let mapRect = fittedMapRect(for: coordinatesToFit, size: size, contentInsets: contentInsets) else {
            throw RouteMapSnapshotError.insufficientCoordinates
        }

        let options = MKMapSnapshotter.Options()
        options.mapRect = mapRect
        options.size = size
        options.scale = scale
        options.mapType = .standard
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await snapshotter.start()

        guard let composedImage = drawRoute(
            traceCoordinates: hasTrace ? traceCoordinates : [],
            plannedCoordinates: plannedCoordinates,
            on: snapshot
        ) else {
            throw RouteMapSnapshotError.renderingFailed
        }
        return composedImage
    }

    private func fittedMapRect(
        for coordinates: [CLLocationCoordinate2D],
        size: CGSize,
        contentInsets: UIEdgeInsets
    ) -> MKMapRect? {
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1))
        }
        guard !rect.isNull, !rect.isEmpty else { return nil }

        let center = MKMapPoint(x: rect.midX, y: rect.midY).coordinate
        let metersPerMapPoint = 1 / MKMapPointsPerMeterAtLatitude(center.latitude)
        let minimumFittedSpanMapPoints = minimumFittedSpanMeters / metersPerMapPoint
        if rect.width < minimumFittedSpanMapPoints {
            let deficit = minimumFittedSpanMapPoints - rect.width
            rect = rect.insetBy(dx: -deficit / 2, dy: 0)
        }
        if rect.height < minimumFittedSpanMapPoints {
            let deficit = minimumFittedSpanMapPoints - rect.height
            rect = rect.insetBy(dx: 0, dy: -deficit / 2)
        }

        let contentWidth = size.width - contentInsets.left - contentInsets.right
        let contentHeight = size.height - contentInsets.top - contentInsets.bottom
        guard contentWidth > 0, contentHeight > 0 else { return nil }

        let scaleFactor = max(rect.width / contentWidth, rect.height / contentHeight)
        guard scaleFactor > 0, scaleFactor.isFinite else { return nil }

        let originX = rect.midX - (contentInsets.left + contentWidth / 2) * scaleFactor
        let originY = rect.midY - (contentInsets.top + contentHeight / 2) * scaleFactor

        return MKMapRect(
            x: originX,
            y: originY,
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
    }

    private func drawRoute(
        traceCoordinates: [CLLocationCoordinate2D],
        plannedCoordinates: [CLLocationCoordinate2D],
        on snapshot: MKMapSnapshotter.Snapshot
    ) -> UIImage? {
        let hasTrace = traceCoordinates.count >= 2
        let format = UIGraphicsImageRendererFormat()
        format.scale = snapshot.image.scale
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size, format: format)

        return renderer.image { context in
            snapshot.image.draw(at: .zero)

            let routeColor = UIColor(Color.Brand.blue600)

            if hasTrace, plannedCoordinates.count >= 2 {
                strokePath(
                    points: plannedCoordinates.map { snapshot.point(for: $0) },
                    color: .systemGray,
                    lineWidth: 5,
                    dashPattern: nil
                )
            }

            guard hasTrace else {
                let points = plannedCoordinates.map { snapshot.point(for: $0) }
                strokePath(points: points, color: .white.withAlphaComponent(0.9), lineWidth: 11, dashPattern: nil)
                strokePath(points: points, color: .systemGray, lineWidth: 7, dashPattern: nil)
                return
            }

            let runs = RouteTraceSplitter.splitAtGaps(traceCoordinates)
            for run in runs where run.count >= 2 {
                let points = run.map { snapshot.point(for: $0) }
                strokePath(points: points, color: .white.withAlphaComponent(0.9), lineWidth: 11, dashPattern: nil)
                strokePath(points: points, color: routeColor, lineWidth: 7, dashPattern: nil)
            }

            let markerPoints = traceCoordinates.map { snapshot.point(for: $0) }
            guard let firstPoint = markerPoints.first, let lastPoint = markerPoints.last else { return }
            drawStartMarker(at: firstPoint, color: routeColor, in: context.cgContext)
            drawFinishMarker(at: lastPoint, color: routeColor, in: context.cgContext)
        }
    }

    private func strokePath(points: [CGPoint], color: UIColor, lineWidth: CGFloat, dashPattern: [CGFloat]?) {
        guard let firstPoint = points.first else { return }
        let path = UIBezierPath()
        path.move(to: firstPoint)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        if let dashPattern {
            path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        }
        color.setStroke()
        path.stroke()
    }

    private func drawStartMarker(at point: CGPoint, color: UIColor, in context: CGContext) {
        let radius: CGFloat = 9
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: -3, dy: -3))
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
    }

    private func drawFinishMarker(at point: CGPoint, color: UIColor, in context: CGContext) {
        let radius: CGFloat = 9
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: -3, dy: -3))
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)

        let flagSize: CGFloat = 28
        let flagImage = UIImage(
            systemName: "flag.checkered.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: flagSize, weight: .bold)
        )?.withTintColor(color, renderingMode: .alwaysOriginal)

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
