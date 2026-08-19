import Foundation

protocol HistoryHighlightGenerating {
    func makeHighlights(trips: [TripSummary], referenceDate: Date) -> [HistoryHighlight]
}

struct HistoryHighlightGenerator: HistoryHighlightGenerating {
    private let minimumTripsForTrend = 2
    private let minimumMeaningfulPercentChange = 5.0
    private let recentWindowDays = 30
    private let eveningStartHour = 12

    func makeHighlights(trips: [TripSummary], referenceDate: Date) -> [HistoryHighlight] {
        [
            weeklyAverageHighlight(trips: trips, referenceDate: referenceDate),
            timeOfDayHighlight(trips: trips, referenceDate: referenceDate)
        ].compactMap { $0 }
    }

    private func weeklyAverageHighlight(trips: [TripSummary], referenceDate: Date) -> HistoryHighlight? {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate),
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start) else {
            return nil
        }
        let lastWeek = DateInterval(start: lastWeekStart, end: thisWeek.start)

        let thisWeekTrips = trips.filter { thisWeek.contains($0.completedAt) }
        let lastWeekTrips = trips.filter { lastWeek.contains($0.completedAt) }

        guard thisWeekTrips.count >= minimumTripsForTrend,
              lastWeekTrips.count >= minimumTripsForTrend else {
            return nil
        }

        let thisWeekAverage = averageExposureUg(of: thisWeekTrips)
        let lastWeekAverage = averageExposureUg(of: lastWeekTrips)
        guard lastWeekAverage > 0 else { return nil }

        let percentChange = ((thisWeekAverage - lastWeekAverage) / lastWeekAverage) * 100
        guard abs(percentChange) >= minimumMeaningfulPercentChange else { return nil }

        let isLower = percentChange < 0
        let roundedPercent = Int(abs(percentChange).rounded())
        let direction = isLower ? "lower" : "higher"
        let icon = isLower ? "arrow.down.right" : "arrow.up.right"

        return HistoryHighlight(
            systemImage: icon,
            text: "Your average exposure per ride was \(Int(thisWeekAverage.rounded())) µg this week, \(roundedPercent)% \(direction) than last week"
        )
    }

    private func timeOfDayHighlight(trips: [TripSummary], referenceDate: Date) -> HistoryHighlight? {
        let calendar = Calendar.current
        guard let windowStart = calendar.date(byAdding: .day, value: -recentWindowDays, to: referenceDate) else {
            return nil
        }
        let recentTrips = trips.filter { $0.completedAt >= windowStart && $0.completedAt <= referenceDate }

        let morningTrips = recentTrips.filter { calendar.component(.hour, from: $0.completedAt) < eveningStartHour }
        let eveningTrips = recentTrips.filter { calendar.component(.hour, from: $0.completedAt) >= eveningStartHour }

        guard morningTrips.count >= minimumTripsForTrend,
              eveningTrips.count >= minimumTripsForTrend else {
            return nil
        }

        let morningAverage = averageExposureUg(of: morningTrips)
        let eveningAverage = averageExposureUg(of: eveningTrips)
        guard morningAverage > 0, eveningAverage > 0 else { return nil }

        let higherAverage = max(morningAverage, eveningAverage)
        let percentDifference = abs(morningAverage - eveningAverage) / higherAverage * 100
        guard percentDifference >= minimumMeaningfulPercentChange else { return nil }

        let roundedPercent = Int(percentDifference.rounded())
        if morningAverage < eveningAverage {
            return HistoryHighlight(
                systemImage: "sun.max.fill",
                text: "Morning rides had ~\(roundedPercent)% lower estimated exposure than your evening rides"
            )
        }
        return HistoryHighlight(
            systemImage: "moon.stars.fill",
            text: "Evening rides had ~\(roundedPercent)% lower estimated exposure than your morning rides"
        )
    }

    private func averageExposureUg(of trips: [TripSummary]) -> Double {
        guard !trips.isEmpty else { return 0 }
        let total = trips.reduce(0.0) { $0 + Double($1.exposureUg) }
        return total / Double(trips.count)
    }
}
