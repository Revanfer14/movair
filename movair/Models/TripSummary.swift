import Foundation
import CoreLocation

struct TripSummary: Identifiable, Equatable {
    let id: UUID
    let originTitle: String
    let destinationTitle: String
    let distanceKm: Double
    let durationMinutes: Int
    let averageSpeedKmh: Double
    let exposureUg: Int
    let exposureLevel: ExposureLevel
    let dailyBudgetUg: Int
    let coordinates: [CLLocationCoordinate2D]
    let completedAt: Date

    init(
        id: UUID = UUID(),
        originTitle: String,
        destinationTitle: String,
        distanceKm: Double,
        durationMinutes: Int,
        averageSpeedKmh: Double,
        exposureUg: Int,
        exposureLevel: ExposureLevel,
        dailyBudgetUg: Int = 261,
        coordinates: [CLLocationCoordinate2D] = [],
        completedAt: Date = Date()
    ) {
        self.id = id
        self.originTitle = originTitle
        self.destinationTitle = destinationTitle
        self.distanceKm = distanceKm
        self.durationMinutes = durationMinutes
        self.averageSpeedKmh = averageSpeedKmh
        self.exposureUg = exposureUg
        self.exposureLevel = exposureLevel
        self.dailyBudgetUg = dailyBudgetUg
        self.coordinates = coordinates
        self.completedAt = completedAt
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
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
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
