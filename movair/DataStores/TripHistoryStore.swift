import Foundation
import Combine
import CoreLocation

@MainActor
final class TripHistoryStore: ObservableObject {
    @Published private(set) var trips: [TripSummary] = []

    static let shared = TripHistoryStore()

    init(seedDummy: Bool = true) {
        if seedDummy {
            trips = Self.makeDummyTrips()
        }
    }

    func add(_ trip: TripSummary) {
        trips.insert(trip, at: 0)
    }

    func trips(forWeekContaining date: Date = Date()) -> [TripSummary] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }
        return trips.filter { interval.contains($0.completedAt) }
    }

    func exposure(for day: Date) -> Int? {
        let calendar = Calendar.current
        let dayTrips = trips.filter { calendar.isDate($0.completedAt, inSameDayAs: day) }
        guard !dayTrips.isEmpty else { return nil }
        return dayTrips.reduce(0) { $0 + $1.exposureUg }
    }

    private static func makeDummyTrips() -> [TripSummary] {
        let calendar = Calendar.current
        let now = Date()

        func dayOffset(_ days: Int, hour: Int, minute: Int) -> Date {
            let comps = calendar.dateComponents([.year, .month, .day], from: now)
            let base = calendar.date(from: comps) ?? now
            let shifted = calendar.date(byAdding: .day, value: days, to: base) ?? base
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: shifted) ?? shifted
        }

        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: -6.291, longitude: 106.641),
            CLLocationCoordinate2D(latitude: -6.295, longitude: 106.648),
            CLLocationCoordinate2D(latitude: -6.301, longitude: 106.653)
        ]

        return [
            TripSummary(
                originTitle: "Green Office Park",
                destinationTitle: "BXChange Mall",
                distanceKm: 10.5,
                durationMinutes: 100,
                averageSpeedKmh: 10,
                exposureUg: 110,
                exposureLevel: .moderate,
                coordinates: coords,
                completedAt: dayOffset(0, hour: 7, minute: 15)
            ),
            TripSummary(
                originTitle: "The Breeze",
                destinationTitle: "Intermoda BSD",
                distanceKm: 6.2,
                durationMinutes: 35,
                averageSpeedKmh: 12,
                exposureUg: 72,
                exposureLevel: .low,
                coordinates: coords,
                completedAt: dayOffset(-1, hour: 17, minute: 40)
            ),
            TripSummary(
                originTitle: "Aeon Mall",
                destinationTitle: "Green Office Park",
                distanceKm: 8.0,
                durationMinutes: 48,
                averageSpeedKmh: 11,
                exposureUg: 95,
                exposureLevel: .moderate,
                coordinates: coords,
                completedAt: dayOffset(-2, hour: 8, minute: 5)
            )
        ]
    }
}
