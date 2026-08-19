import Foundation
import CoreLocation

struct RecentSearch: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let latitude: Double?
    let longitude: Double?
    let date: Date

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
        self.date = date
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
