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
    private let fetchGroups: [SegmentFetchGroup]
    private var lockedSegmentIndices: Set<Int> = []
    private var currentWIBHour: Int?
    private let wibTimeZone: TimeZone
    private var previousSegmentDurationsSeconds: [TimeInterval]
    private var accumulatedDoseMicrograms: Double = 0
    private var doseBySegment: [Double]
    private var exposureBySegment: [Double]
    private var hourRolloverCount = 0
    private var lastVentilationRate: Double = 0
    private var lastHeartRateBPM: Double = 0

    init(
        segments: [RouteSegment],
        weatherService: OpenMeteoProviding = OpenMeteoService(),
        predictor: PMPredicting? = nil,
        roadDataStore: RoadDataProviding? = nil,
        fetchGrouper: SegmentFetchGrouping = SegmentFetchGrouper(),
        ventilationRateProvider: VentilationRateProvider = ConstantVentilationRate()
    ) async throws {
        guard let wibTimeZone = TimeZone(identifier: "Asia/Jakarta") else {
            throw ExposureEstimationError.modelPredictionFailed
        }
        guard !segments.isEmpty else {
            throw ExposureEstimationError.invalidRoute
        }

        let resolvedRoadDataStore = try roadDataStore ?? RoadDataStore.shared ?? RoadDataStore()
        let resolvedPredictor = predictor ?? RemotePMPredictor()
        let resolvedFetchGroups = fetchGrouper.makeGroups(from: segments)
        guard resolvedFetchGroups.count <= DoseConstants.maxFetchGroupsPerRequest else {
            throw ExposureEstimationError.routeOutsideValidatedCoverage
        }

        self.segments = segments
        self.weatherService = weatherService
        self.predictor = resolvedPredictor
        self.roadDataStore = resolvedRoadDataStore
        self.ventilationRateProvider = ventilationRateProvider
        self.wibTimeZone = wibTimeZone
        self.fetchGroups = resolvedFetchGroups
        self.roadAttributesBySegment = try segments.map {
            try resolvedRoadDataStore.attributes(for: $0.midpoint)
        }
        self.basePM25BySegment = Array(repeating: 0, count: segments.count)
        self.previousSegmentDurationsSeconds = Array(repeating: 0, count: segments.count)
        self.doseBySegment = Array(repeating: 0, count: segments.count)
        self.exposureBySegment = Array(repeating: 0, count: segments.count)
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
            let deltaDurationsMinutes = zip(snapshot.segmentDurations, previousSegmentDurationsSeconds).map {
                max(0, $0 - $1) / 60
            }
            let currentVentilationRate = ventilationRateProvider.ventilationRate(heartRateBPM: heartRateBPM)

            var deltaExposure = 0.0
            for index in deltaDurationsMinutes.indices {
                let contribution = concentrations[index] * deltaDurationsMinutes[index]
                exposureBySegment[index] += contribution
                doseBySegment[index] += currentVentilationRate * contribution
                deltaExposure += contribution
            }

            accumulatedDoseMicrograms += DoseCalculator.doseMicrograms(
                exposure: deltaExposure,
                ventilationRate: currentVentilationRate
            )
            previousSegmentDurationsSeconds = snapshot.segmentDurations
            lastVentilationRate = currentVentilationRate
            lastHeartRateBPM = heartRateBPM

            return LiveDoseSnapshot(
                doseMicrograms: accumulatedDoseMicrograms,
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
            totalDoseMicrograms: doseMicrograms,
            segmentDoseMicrograms: doseBySegment,
            segmentExposures: exposureBySegment,
            modelVersion: predictor.modelVersion,
            lastVentilationRate: lastVentilationRate,
            lastHeartRateBPM: lastHeartRateBPM,
            hourRolloverCount: hourRolloverCount
        )
    }

    private func refreshIfHourChanged(date: Date, activeSegmentIndex: Int?) async throws {
        let hour = wibHour(for: date)
        guard currentWIBHour != hour else { return }
        hourRolloverCount += 1

        if let activeSegmentIndex {
            for index in 0..<activeSegmentIndex {
                lockedSegmentIndices.insert(index)
            }
        }

        currentWIBHour = hour
        try await refreshUnlockedBasePM25(date: date)
    }

    private func refreshUnlockedBasePM25(date: Date) async throws {
        let unlockedGroups = fetchGroups.filter { group in
            group.segmentIndices.contains { !lockedSegmentIndices.contains($0) }
        }

        guard unlockedGroups.count <= DoseConstants.maxFetchGroupsPerRequest else {
            throw ExposureEstimationError.routeOutsideValidatedCoverage
        }

        var snapshots: [WeatherSnapshot] = []
        snapshots.reserveCapacity(unlockedGroups.count)
        for group in unlockedGroups {
            snapshots.append(try await weatherService.weather(at: group.referenceCoordinate, date: date))
        }

        let predictions: [Double]
        do {
            predictions = try await predictor.predict(snapshots: snapshots, date: date)
        } catch {
            throw ExposureEstimationError.modelPredictionFailed
        }
        guard predictions.count == unlockedGroups.count else {
            throw ExposureEstimationError.modelPredictionFailed
        }

        for (group, basePM25) in zip(unlockedGroups, predictions) {
            for segmentIndex in group.segmentIndices where !lockedSegmentIndices.contains(segmentIndex) {
                basePM25BySegment[segmentIndex] = basePM25
            }
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
