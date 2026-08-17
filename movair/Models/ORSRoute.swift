import Foundation
import CoreLocation

struct ORSRoute: Identifiable, Equatable {
    let id: UUID
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Double
    let durationSeconds: Double

    init(
        id: UUID = UUID(),
        coordinates: [CLLocationCoordinate2D],
        distanceMeters: Double,
        durationSeconds: Double
    ) {
        self.id = id
        self.coordinates = coordinates
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
    }

    static func == (lhs: ORSRoute, rhs: ORSRoute) -> Bool {
        lhs.coordinates.count == rhs.coordinates.count
            && lhs.distanceMeters == rhs.distanceMeters
            && lhs.durationSeconds == rhs.durationSeconds
    }
}
