import Foundation
import CoreLocation

struct TripSummary: Identifiable, Equatable, Codable {
    let id: UUID
    let originTitle: String
    let destinationTitle: String
    let distanceKm: Double
    let durationMinutes: Int
    let durationSeconds: TimeInterval
    let averageSpeedKmh: Double
    let exposureUg: Int
    let exposureLevel: ExposureLevel
    let isMeasuredExposure: Bool
    let unattributedDurationMinutes: Int
    let dailyBudgetUg: Int
    let coordinates: [CLLocationCoordinate2D]
    let travelledCoordinates: [CLLocationCoordinate2D]
    let originCoordinate: CLLocationCoordinate2D?
    let destinationCoordinate: CLLocationCoordinate2D?
    let segmentConcentrations: [Double]
    let segmentDurationsSeconds: [TimeInterval]
    let completedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case originTitle
        case destinationTitle
        case distanceKm
        case durationMinutes
        case durationSeconds
        case averageSpeedKmh
        case exposureUg
        case exposureLevel
        case isMeasuredExposure
        case unattributedDurationMinutes
        case dailyBudgetUg
        case coordinates
        case travelledCoordinates
        case originCoordinate
        case destinationCoordinate
        case segmentConcentrations
        case segmentDurationsSeconds
        case completedAt
    }

    private struct CoordinatePayload: Codable {
        let latitude: Double
        let longitude: Double
    }

    init(
        id: UUID = UUID(),
        originTitle: String,
        destinationTitle: String,
        distanceKm: Double,
        durationMinutes: Int,
        durationSeconds: TimeInterval? = nil,
        averageSpeedKmh: Double,
        exposureUg: Int,
        exposureLevel: ExposureLevel,
        isMeasuredExposure: Bool = false,
        unattributedDurationMinutes: Int = 0,
        dailyBudgetUg: Int = 261,
        coordinates: [CLLocationCoordinate2D] = [],
        travelledCoordinates: [CLLocationCoordinate2D] = [],
        originCoordinate: CLLocationCoordinate2D? = nil,
        destinationCoordinate: CLLocationCoordinate2D? = nil,
        segmentConcentrations: [Double] = [],
        segmentDurationsSeconds: [TimeInterval] = [],
        completedAt: Date = Date()
    ) {
        self.id = id
        self.originTitle = originTitle
        self.destinationTitle = destinationTitle
        self.distanceKm = distanceKm
        self.durationMinutes = durationMinutes
        self.durationSeconds = durationSeconds ?? Double(durationMinutes) * 60
        self.averageSpeedKmh = averageSpeedKmh
        self.exposureUg = exposureUg
        self.exposureLevel = exposureLevel
        self.isMeasuredExposure = isMeasuredExposure
        self.unattributedDurationMinutes = unattributedDurationMinutes
        self.dailyBudgetUg = dailyBudgetUg
        self.coordinates = coordinates
        self.travelledCoordinates = travelledCoordinates
        self.originCoordinate = originCoordinate
        self.destinationCoordinate = destinationCoordinate
        self.segmentConcentrations = segmentConcentrations
        self.segmentDurationsSeconds = segmentDurationsSeconds
        self.completedAt = completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        originTitle = try container.decode(String.self, forKey: .originTitle)
        destinationTitle = try container.decode(String.self, forKey: .destinationTitle)
        distanceKm = try container.decode(Double.self, forKey: .distanceKm)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        durationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .durationSeconds)
            ?? Double(durationMinutes) * 60
        averageSpeedKmh = try container.decode(Double.self, forKey: .averageSpeedKmh)
        exposureUg = try container.decode(Int.self, forKey: .exposureUg)
        exposureLevel = try container.decode(ExposureLevel.self, forKey: .exposureLevel)
        isMeasuredExposure = try container.decodeIfPresent(Bool.self, forKey: .isMeasuredExposure) ?? false
        unattributedDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .unattributedDurationMinutes) ?? 0
        dailyBudgetUg = try container.decodeIfPresent(Int.self, forKey: .dailyBudgetUg) ?? 261
        completedAt = try container.decode(Date.self, forKey: .completedAt)

        let payloads = try container.decodeIfPresent([CoordinatePayload].self, forKey: .coordinates) ?? []
        coordinates = payloads.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        let travelledPayloads = try container.decodeIfPresent([CoordinatePayload].self, forKey: .travelledCoordinates) ?? []
        travelledCoordinates = travelledPayloads.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        if let originPayload = try container.decodeIfPresent(CoordinatePayload.self, forKey: .originCoordinate) {
            originCoordinate = CLLocationCoordinate2D(latitude: originPayload.latitude, longitude: originPayload.longitude)
        } else {
            originCoordinate = nil
        }

        if let destinationPayload = try container.decodeIfPresent(CoordinatePayload.self, forKey: .destinationCoordinate) {
            destinationCoordinate = CLLocationCoordinate2D(latitude: destinationPayload.latitude, longitude: destinationPayload.longitude)
        } else {
            destinationCoordinate = nil
        }

        segmentConcentrations = try container.decodeIfPresent([Double].self, forKey: .segmentConcentrations) ?? []
        segmentDurationsSeconds = try container.decodeIfPresent([TimeInterval].self, forKey: .segmentDurationsSeconds) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(originTitle, forKey: .originTitle)
        try container.encode(destinationTitle, forKey: .destinationTitle)
        try container.encode(distanceKm, forKey: .distanceKm)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(averageSpeedKmh, forKey: .averageSpeedKmh)
        try container.encode(exposureUg, forKey: .exposureUg)
        try container.encode(exposureLevel, forKey: .exposureLevel)
        try container.encode(isMeasuredExposure, forKey: .isMeasuredExposure)
        try container.encode(unattributedDurationMinutes, forKey: .unattributedDurationMinutes)
        try container.encode(dailyBudgetUg, forKey: .dailyBudgetUg)
        try container.encode(completedAt, forKey: .completedAt)

        let payloads = coordinates.map { CoordinatePayload(latitude: $0.latitude, longitude: $0.longitude) }
        try container.encode(payloads, forKey: .coordinates)

        let travelledPayloads = travelledCoordinates.map { CoordinatePayload(latitude: $0.latitude, longitude: $0.longitude) }
        try container.encode(travelledPayloads, forKey: .travelledCoordinates)

        try container.encodeIfPresent(
            originCoordinate.map { CoordinatePayload(latitude: $0.latitude, longitude: $0.longitude) },
            forKey: .originCoordinate
        )
        try container.encodeIfPresent(
            destinationCoordinate.map { CoordinatePayload(latitude: $0.latitude, longitude: $0.longitude) },
            forKey: .destinationCoordinate
        )

        try container.encode(segmentConcentrations, forKey: .segmentConcentrations)
        try container.encode(segmentDurationsSeconds, forKey: .segmentDurationsSeconds)
    }

    var displayCoordinates: [CLLocationCoordinate2D] {
        travelledCoordinates.count >= 2 ? travelledCoordinates : coordinates
    }

    var hasActualTrace: Bool {
        travelledCoordinates.count >= 2
    }

    var dailyExposurePercent: Int {
        guard dailyBudgetUg > 0 else { return 0 }
        return min(100, Int((Double(exposureUg) / Double(dailyBudgetUg) * 100).rounded()))
    }

    var routeTitle: String {
        "From \(originTitle) to \(destinationTitle)"
    }

    var distanceLabel: String {
        if distanceKm == floor(distanceKm) {
            return String(format: "%.0f km", distanceKm)
        }
        return String(format: "%.1f km", distanceKm)
    }

    var durationLabel: String {
        let totalMinutes = Int((durationSeconds / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m"
        }
        return "\(minutes) min"
    }

    var speedLabel: String {
        String(format: "%.0f km/h", averageSpeedKmh)
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yyyy · hh:mm a"
        return formatter.string(from: completedAt)
    }

    var relativeDateLabel: String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH.mm"
        let time = timeFormatter.string(from: completedAt)

        if calendar.isDateInToday(completedAt) {
            return "Today at \(time)"
        }
        if calendar.isDateInYesterday(completedAt) {
            return "Yesterday at \(time)"
        }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MMM d"
        return "\(dayFormatter.string(from: completedAt)) at \(time)"
    }

    static func == (lhs: TripSummary, rhs: TripSummary) -> Bool {
        lhs.id == rhs.id
    }
}
