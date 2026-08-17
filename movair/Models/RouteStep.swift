import Foundation
import CoreLocation

struct RouteStep: Identifiable, Equatable, Codable {
    let id: UUID
    let distanceMeters: Double
    let durationSeconds: Double
    let maneuverType: Int
    let text: String
    let streetName: String
    let coordinate: CLLocationCoordinate2D
    let waypointIndex: Int

    enum CodingKeys: String, CodingKey {
        case id
        case distanceMeters
        case durationSeconds
        case maneuverType
        case text
        case streetName
        case coordinate
        case waypointIndex
    }

    private struct CoordinatePayload: Codable {
        let latitude: Double
        let longitude: Double
    }

    init(
        id: UUID = UUID(),
        distanceMeters: Double,
        durationSeconds: Double,
        maneuverType: Int,
        text: String,
        streetName: String,
        coordinate: CLLocationCoordinate2D,
        waypointIndex: Int
    ) {
        self.id = id
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.maneuverType = maneuverType
        self.text = text
        self.streetName = streetName
        self.coordinate = coordinate
        self.waypointIndex = waypointIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        distanceMeters = try container.decode(Double.self, forKey: .distanceMeters)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        maneuverType = try container.decode(Int.self, forKey: .maneuverType)
        text = try container.decode(String.self, forKey: .text)
        streetName = try container.decode(String.self, forKey: .streetName)
        waypointIndex = try container.decode(Int.self, forKey: .waypointIndex)
        let payload = try container.decode(CoordinatePayload.self, forKey: .coordinate)
        coordinate = CLLocationCoordinate2D(latitude: payload.latitude, longitude: payload.longitude)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(distanceMeters, forKey: .distanceMeters)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(maneuverType, forKey: .maneuverType)
        try container.encode(text, forKey: .text)
        try container.encode(streetName, forKey: .streetName)
        try container.encode(waypointIndex, forKey: .waypointIndex)
        let payload = CoordinatePayload(latitude: coordinate.latitude, longitude: coordinate.longitude)
        try container.encode(payload, forKey: .coordinate)
    }

    var systemImage: String {
        switch maneuverType {
        case 0, 2:
            return "arrow.turn.up.left"
        case 1, 3:
            return "arrow.turn.up.right"
        case 4, 12:
            return "arrow.up.left"
        case 5, 13:
            return "arrow.up.right"
        case 6:
            return "arrow.up"
        case 7, 8:
            return "arrow.triangle.2.circlepath"
        case 9:
            return "arrow.uturn.left"
        case 10:
            return "flag.fill"
        case 11:
            return "location.north.fill"
        default:
            return "arrow.up"
        }
    }

    static func == (lhs: RouteStep, rhs: RouteStep) -> Bool {
        lhs.id == rhs.id
    }
}
