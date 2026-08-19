import Foundation
import Combine

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published private(set) var weekDates: [Date] = []
    @Published private(set) var weekExposures: [Int?] = []

    let store: TripHistoryStore
    private let dailyBudgetUg: Int = 261
    private let highlightGenerator: HistoryHighlightGenerating
    private let dailyBudgetUg: Int = 240

    init(store: TripHistoryStore = .shared, highlightGenerator: HistoryHighlightGenerating = HistoryHighlightGenerator()) {
        self.store = store
        self.highlightGenerator = highlightGenerator
        rebuildWeek(around: Date())
    }

    var selectedDayTrips: [TripSummary] {
        store.trips(for: selectedDate)
    }

    var selectedDayExposure: Int {
        store.exposure(for: selectedDate) ?? 0
    }

    var selectedDayLevel: ExposureLevel {
        ExposureLevel.from(exposureUg: selectedDayExposure)
    }

    var dailyBudgetPercent: Int {
        guard dailyBudgetUg > 0 else { return 0 }
        return min(100, Int((Double(selectedDayExposure) / Double(dailyBudgetUg) * 100).rounded()))
    }

    var dailyBudgetLabel: String {
        "\(selectedDayExposure) µg"
    }

    var dailyBudgetSubLabel: String {
        "of \(dailyBudgetUg) µg"
    }

    var latestTrip: TripSummary? {
        selectedDayTrips.first ?? store.trips.first
    }

    var highlights: [HistoryHighlight] {
        highlightGenerator.makeHighlights(trips: store.trips, referenceDate: Date())
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    func deleteTrip(_ trip: TripSummary) {
        store.delete(tripID: trip.id)
        rebuildWeek(around: selectedDate)
    }

    func deleteTrip(id: UUID) {
        store.delete(tripID: id)
        rebuildWeek(around: selectedDate)
    }

    func rebuildWeek(around date: Date) {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        weekDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        weekExposures = weekDates.map { store.exposure(for: $0) }
        if !weekDates.contains(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) {
            selectedDate = date
        }
    }
}
