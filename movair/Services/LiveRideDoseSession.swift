import CoreLocation
import Foundation

struct LiveDoseSnapshot: Equatable {
    let doseMicrograms: Double
    let segmentConcentrations: [Double]
    let unattributedDurationSeconds: TimeInterval
    let interpolatedSegmentFlags: [Bool]
    let isOffRoute: Bool
}

actor LiveRideDoseSession {
    private let segments: [RouteSegment]
    private let weatherService: OpenMeteoProviding
    private let predictor: PMPredicting
    private let roadDataStore: RoadDataProviding
    private let ventilationRateProvider: VentilationRateProvider

    private var roadAttributesBySegment: [RoadAttributes]
    private var basePM25BySegment: [Double]
    private var lockedSegmentIndices: Set<Int> = []
    private var currentWIBHour: Int?
    private let wibTimeZone: TimeZone

    init(
        segments: [RouteSegment],
        weatherService: OpenMeteoProviding = OpenMeteoService(),
        predictor: PMPredicting? = nil,
        roadDataStore: RoadDataProviding? = nil,
        ventilationRateProvider: VentilationRateProvider = ConstantVentilationRate()
    ) async throws {
        guard let wibTimeZone = TimeZone(identifier: "Asia/Jakarta") else {
            throw ExposureEstimationError.modelPredictionFailed
        }
        guard !segments.isEmpty else {
            throw ExposureEstimationError.invalidRoute
        }

        let resolvedRoadDataStore = try roadDataStore ?? RoadDataStore.shared ?? RoadDataStore()
        let resolvedPredictor = try predictor ?? PMPredictor()

        self.segments = segments
        self.weatherService = weatherService
        self.predictor = resolvedPredictor
        self.roadDataStore = resolvedRoadDataStore
        self.ventilationRateProvider = ventilationRateProvider
        self.wibTimeZone = wibTimeZone
        self.roadAttributesBySegment = try segments.map {
            try resolvedRoadDataStore.attributes(for: $0.midpoint)
        }
        self.basePM25BySegment = Array(repeating: 0, count: segments.count)
    }

    func prepare(date: Date = Date()) async throws {
        await ventilationRateProvider.prepare()
        currentWIBHour = wibHour(for: date)
        try await refreshUnlockedBasePM25(date: date)
    }

    func apply(
        snapshot: RideTrackingSnapshot,
        date: Date = Date(),
        heartRateBPM: Double = 0
    ) async throws -> LiveDoseSnapshot {
        try await refreshIfHourChanged(
            date: date,
            activeSegmentIndex: snapshot.activeSegmentIndex
        )

        let concentrations = segmentConcentrations()
        let durationsMinutes = snapshot.segmentDurations.map { $0 / 60 }
        let exposure = DoseCalculator.exposure(
            concentrations: concentrations,
            durationsMinutes: durationsMinutes
        )
        let dose = DoseCalculator.doseMicrograms(
            exposure: exposure,
            ventilationRate: ventilationRateProvider.ventilationRate(heartRateBPM: heartRateBPM)
        )

        return LiveDoseSnapshot(
            doseMicrograms: dose,
            segmentConcentrations: concentrations,
            unattributedDurationSeconds: snapshot.unattributedDuration,
            interpolatedSegmentFlags: snapshot.interpolatedSegmentFlags,
            isOffRoute: snapshot.isOffRoute
        )
    }

    func makeRideRecord(from snapshot: RideTrackingSnapshot, doseMicrograms: Double) -> RideRecord {
        RideRecord(
            segmentDurationsSeconds: snapshot.segmentDurations,
            segmentConcentrations: segmentConcentrations(),
            unattributedDurationSeconds: snapshot.unattributedDuration,
            interpolatedSegmentFlags: snapshot.interpolatedSegmentFlags,
            totalDoseMicrograms: doseMicrograms
        )
    }

    private func refreshIfHourChanged(date: Date, activeSegmentIndex: Int?) async throws {
        let hour = wibHour(for: date)
        guard currentWIBHour != hour else { return }

        if let activeSegmentIndex {
            for index in 0..<activeSegmentIndex {
                lockedSegmentIndices.insert(index)
            }
        }

        currentWIBHour = hour
        try await refreshUnlockedBasePM25(date: date)
    }

    private func refreshUnlockedBasePM25(date: Date) async throws {
        var unlockedCells = Set<CAMSCell>()
        for (index, segment) in segments.enumerated() where !lockedSegmentIndices.contains(index) {
            unlockedCells.insert(CAMSCell(coordinate: segment.midpoint))
        }

        guard unlockedCells.count <= DoseConstants.maxCAMSCellsPerRequest else {
            throw ExposureEstimationError.routeOutsideValidatedCoverage
        }

        var basePM25ByCell: [CAMSCell: Double] = [:]
        for cell in unlockedCells {
            let weather = try await weatherService.weather(at: cell.centroid, date: date)
            do {
                basePM25ByCell[cell] = try predictor.predict(snapshot: weather, date: date)
            } catch {
                throw ExposureEstimationError.modelPredictionFailed
            }
        }

        for (index, segment) in segments.enumerated() where !lockedSegmentIndices.contains(index) {
            let cell = CAMSCell(coordinate: segment.midpoint)
            guard let basePM25 = basePM25ByCell[cell] else {
                throw ExposureEstimationError.unavailableData
            }
            basePM25BySegment[index] = basePM25
        }
    }

    private func segmentConcentrations() -> [Double] {
        zip(basePM25BySegment, roadAttributesBySegment).map { basePM25, attributes in
            DoseCalculator.concentration(
                basePM25: basePM25,
                roadClass: attributes.roadClass,
                greeneryIndex: attributes.greeneryIndex
            )
        }
    }

    private func wibHour(for date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = wibTimeZone
        return calendar.component(.hour, from: date)
    }
}
