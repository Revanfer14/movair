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
    let steps: [RouteStep]

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
        coordinates: [CLLocationCoordinate2D],
        steps: [RouteStep] = []
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
        self.steps = steps
    }

    var distanceLabel: String {
        if distanceKm == floor(distanceKm) {
            return String(format: "%.0f", distanceKm)
        }
        return String(format: "%.1f", distanceKm)
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
            && lhs.title == rhs.title
            && lhs.distanceKm == rhs.distanceKm
            && lhs.durationMinutes == rhs.durationMinutes
            && lhs.exposureRangeUg == rhs.exposureRangeUg
            && lhs.exposureLevel == rhs.exposureLevel
            && lhs.pollutionDeltaPercent == rhs.pollutionDeltaPercent
            && lhs.hasEquivalentExposure == rhs.hasEquivalentExposure
            && lhs.isRecommended == rhs.isRecommended
            && lhs.isLonger == rhs.isLonger
            && lhs.steps.count == rhs.steps.count
            && coordinatesAreEqual(lhs.coordinates, rhs.coordinates)
    }

    private static func coordinatesAreEqual(_ lhs: [CLLocationCoordinate2D], _ rhs: [CLLocationCoordinate2D]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (left, right) in zip(lhs, rhs) where left.latitude != right.latitude || left.longitude != right.longitude {
            return false
        }
        return true
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
