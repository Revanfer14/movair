import Foundation
import CoreLocation
import MapKit

struct RouteOption: Identifiable, Equatable {
    let id: UUID
    let title: String
    let distanceKm: Double
    let durationMinutes: Int
    let exposureRangeUg: ClosedRange<Int>
    let exposureLevel: ExposureLevel
    let pollutionDeltaPercent: Int
    let hasEquivalentExposure: Bool
    let isRecommended: Bool
    let isLonger: Bool
    let coordinates: [CLLocationCoordinate2D]

    init(
        id: UUID = UUID(),
        title: String,
        distanceKm: Double,
        durationMinutes: Int,
        exposureRangeUg: ClosedRange<Int>,
        exposureLevel: ExposureLevel,
        pollutionDeltaPercent: Int,
        hasEquivalentExposure: Bool = false,
        isRecommended: Bool = false,
        isLonger: Bool = false,
        coordinates: [CLLocationCoordinate2D]
    ) {
        self.id = id
        self.title = title
        self.distanceKm = distanceKm
        self.durationMinutes = durationMinutes
        self.exposureRangeUg = exposureRangeUg
        self.exposureLevel = exposureLevel
        self.pollutionDeltaPercent = pollutionDeltaPercent
        self.hasEquivalentExposure = hasEquivalentExposure
        self.isRecommended = isRecommended
        self.isLonger = isLonger
        self.coordinates = coordinates
    }

    var distanceLabel: String {
        String(format: "%.0f", distanceKm)
    }

    var durationLabel: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    var exposureLabel: String {
        "\(exposureRangeUg.lowerBound)-\(exposureRangeUg.upperBound) µg"
    }

    var pollutionDeltaLabel: String {
        if hasEquivalentExposure {
            return "Similar pollution to other routes"
        }
        let absValue = abs(pollutionDeltaPercent)
        if pollutionDeltaPercent > 0 {
            return "\(absValue)% higher pollution than other routes"
        }
        return "Lowest pollution"
    }

    static func == (lhs: RouteOption, rhs: RouteOption) -> Bool {
        lhs.id == rhs.id
    }
}

struct SelectedDestination: Equatable {
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: SelectedDestination, rhs: SelectedDestination) -> Bool {
        lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
