import Foundation
import SwiftUI

protocol TripShareImageRendering {
    func makeImage(for trip: TripSummary) async throws -> UIImage
}

@MainActor
final class TripShareImageRenderer: TripShareImageRendering {
    private let mapSnapshotter: RouteMapSnapshotting

    init(mapSnapshotter: RouteMapSnapshotting = RouteMapSnapshotter()) {
        self.mapSnapshotter = mapSnapshotter
    }

    func makeImage(for trip: TripSummary) async throws -> UIImage {
        let cardSize = TripShareCardView.cardSize
        let mapImage = try await mapSnapshotter.makeSnapshot(
            coordinates: trip.displayCoordinates,
            size: cardSize,
            scale: 3
        )

        let cardView = TripShareCardView(trip: trip, mapImage: mapImage)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3

        guard let renderedImage = renderer.uiImage else {
            throw RouteMapSnapshotError.renderingFailed
        }
        return renderedImage
    }
}
