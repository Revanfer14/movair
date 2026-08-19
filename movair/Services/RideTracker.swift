import CoreLocation

final class RideTracker {
    private let segments: [RouteSegment]
    private var segmentDurations: [TimeInterval]
    private var interpolatedSegmentFlags: [Bool]
    private var activeSegmentIndex: Int?
    private var backwardCandidateIndex: Int?
    private var backwardCandidateCount = 0
    private var lastUpdateUptime: TimeInterval?
    private var lastLocation: CLLocation?
    private var elapsedDuration: TimeInterval = 0
    private var unattributedDuration: TimeInterval = 0
    private var travelledDistanceMeters: Double = 0
    private var isOffRoute = false
    private var matchedRouteDistanceMeters: Double = 0
    private var distanceToRouteMeters: Double = 0
    private var projectedCoordinate: CLLocationCoordinate2D?
    private var travelledTracePoints: [RideTracePoint] = []
    private var lastTraceLocation: CLLocation?
    private var traceSpacingMeters = DoseConstants.traceMinimumSpacingMeters

    private var travelledCoordinates: [CLLocationCoordinate2D] {
        travelledTracePoints.map(\.coordinate)
    }

    init(segments: [RouteSegment]) {
        self.segments = segments
        segmentDurations = Array(repeating: 0, count: segments.count)
        interpolatedSegmentFlags = Array(repeating: false, count: segments.count)
    }

    func pause() {
        lastUpdateUptime = nil
        lastLocation = nil
        lastTraceLocation = nil
    }

    func process(location: CLLocation) -> RideTrackingSnapshot {
        let uptime = ProcessInfo.processInfo.systemUptime
        let delta = consumeElapsedDuration(at: uptime)
        updateTravelledDistance(with: location)
        recordTrace(with: location)

        guard let match = closestMatch(to: location.coordinate) else {
            return snapshot()
        }

        isOffRoute = match.distanceToRouteMeters > DoseConstants.offRouteDistanceMeters
        matchedRouteDistanceMeters = match.routeDistanceMeters
        distanceToRouteMeters = match.distanceToRouteMeters
        projectedCoordinate = match.projectedCoordinate
        let matchedIndex = segmentIndex(for: match.routeDistanceMeters)
        accumulate(elapsed: delta, toward: matchedIndex, routeDistanceMeters: match.routeDistanceMeters)
        return snapshot()
    }

    func snapshot() -> RideTrackingSnapshot {
        RideTrackingSnapshot(
            segmentDurations: segmentDurations,
            elapsedDuration: elapsedDuration,
            unattributedDuration: unattributedDuration,
            travelledDistanceMeters: travelledDistanceMeters,
            isOffRoute: isOffRoute,
            activeSegmentIndex: activeSegmentIndex,
            matchedRouteDistanceMeters: matchedRouteDistanceMeters,
            distanceToRouteMeters: distanceToRouteMeters,
            projectedCoordinate: projectedCoordinate,
            interpolatedSegmentFlags: interpolatedSegmentFlags,
            travelledCoordinates: travelledCoordinates,
            travelledTracePoints: travelledTracePoints
        )
    }

    private func consumeElapsedDuration(at uptime: TimeInterval) -> TimeInterval {
        defer { lastUpdateUptime = uptime }
        guard let lastUpdateUptime else { return 0 }
        let delta = max(0, uptime - lastUpdateUptime)
        elapsedDuration += delta
        return delta
    }

    private func updateTravelledDistance(with location: CLLocation) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= DoseConstants.traceMaximumAccuracyMeters else { return }

        guard let lastLocation else {
            lastLocation = location
            return
        }

        let distance = location.distance(from: lastLocation)
        guard distance >= DoseConstants.minimumMovementMeters else { return }

        guard distance <= 100 else {
            self.lastLocation = location
            return
        }

        travelledDistanceMeters += distance
        self.lastLocation = location
    }

    private func recordTrace(with location: CLLocation) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= DoseConstants.traceMaximumAccuracyMeters else { return }

        let tracePoint = RideTracePoint(
            coordinate: location.coordinate,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed
        )

        guard let previousTraceLocation = lastTraceLocation else {
            lastTraceLocation = location
            travelledTracePoints.append(tracePoint)
            return
        }

        guard location.distance(from: previousTraceLocation) >= traceSpacingMeters else { return }
        lastTraceLocation = location
        travelledTracePoints.append(tracePoint)

        if travelledTracePoints.count > DoseConstants.traceMaximumPointCount {
            decimateTracePoints()
        }
    }

    private func decimateTracePoints() {
        guard travelledTracePoints.count > 2 else { return }
        var decimated: [RideTracePoint] = []
        decimated.reserveCapacity(travelledTracePoints.count / 2 + 1)
        for (index, point) in travelledTracePoints.enumerated() {
            let isEndpoint = index == 0 || index == travelledTracePoints.count - 1
            if isEndpoint || index % 2 == 0 {
                decimated.append(point)
            }
        }
        travelledTracePoints = decimated
        traceSpacingMeters *= 2
    }

    private func accumulate(
        elapsed: TimeInterval,
        toward matchedIndex: Int,
        routeDistanceMeters: Double
    ) {
        guard !segments.isEmpty else { return }

        guard let activeSegmentIndex else {
            self.activeSegmentIndex = matchedIndex
            segmentDurations[matchedIndex] += elapsed
            return
        }

        if matchedIndex == activeSegmentIndex {
            segmentDurations[activeSegmentIndex] += elapsed
            return
        }

        if matchedIndex > activeSegmentIndex {
            let boundary = segments[activeSegmentIndex].endDistanceMeters
                + DoseConstants.forwardTransitionBufferMeters
            if routeDistanceMeters < boundary {
                segmentDurations[activeSegmentIndex] += elapsed
                return
            }
            segmentDurations[matchedIndex] += elapsed
            self.activeSegmentIndex = matchedIndex
            backwardCandidateIndex = nil
            backwardCandidateCount = 0
            return
        }

        if backwardCandidateIndex == matchedIndex {
            backwardCandidateCount += 1
        } else {
            backwardCandidateIndex = matchedIndex
            backwardCandidateCount = 1
        }

        guard backwardCandidateCount >= DoseConstants.backwardTransitionConfirmCount else {
            segmentDurations[activeSegmentIndex] += elapsed
            return
        }

        segmentDurations[matchedIndex] += elapsed
        self.activeSegmentIndex = matchedIndex
        backwardCandidateIndex = nil
        backwardCandidateCount = 0
    }

    private func segmentIndex(for routeDistanceMeters: Double) -> Int {
        segments.firstIndex { routeDistanceMeters <= $0.endDistanceMeters } ?? max(0, segments.count - 1)
    }

    private func closestMatch(to coordinate: CLLocationCoordinate2D) -> RouteMatch? {
        guard !segments.isEmpty else { return nil }

        guard let activeSegmentIndex else {
            return bestMatch(in: 0...(segments.count - 1), near: coordinate)
        }

        var radius = DoseConstants.localMatchInitialRadiusSegments
        while true {
            let start = max(0, activeSegmentIndex - radius)
            let end = min(segments.count - 1, activeSegmentIndex + radius)
            let coversWholeRoute = start == 0 && end == segments.count - 1

            guard let candidate = bestMatch(in: start...end, near: coordinate) else { return nil }

            if coversWholeRoute || candidate.distanceToRouteMeters <= DoseConstants.localMatchWindowMeters {
                return candidate
            }
            radius *= 4
        }
    }

    private func bestMatch(in range: ClosedRange<Int>, near coordinate: CLLocationCoordinate2D) -> RouteMatch? {
        range.compactMap { index -> RouteMatch? in
            let segment = segments[index]
            let projection = projection(of: coordinate, onto: segment)
            let projectedCoordinate = CLLocationCoordinate2D(
                latitude: segment.start.latitude + (segment.end.latitude - segment.start.latitude) * projection.fraction,
                longitude: segment.start.longitude + (segment.end.longitude - segment.start.longitude) * projection.fraction
            )
            return RouteMatch(
                routeDistanceMeters: segment.startDistanceMeters + segment.distanceMeters * projection.fraction,
                distanceToRouteMeters: projection.distanceMeters,
                segmentIndex: index,
                projectedCoordinate: projectedCoordinate
            )
        }
        .min { $0.distanceToRouteMeters < $1.distanceToRouteMeters }
    }

    private func projection(of coordinate: CLLocationCoordinate2D, onto segment: RouteSegment) -> Projection {
        let latitudeScale = 111_320.0
        let longitudeScale = latitudeScale * cos(coordinate.latitude * .pi / 180)
        let startX = (segment.start.longitude - coordinate.longitude) * longitudeScale
        let startY = (segment.start.latitude - coordinate.latitude) * latitudeScale
        let endX = (segment.end.longitude - coordinate.longitude) * longitudeScale
        let endY = (segment.end.latitude - coordinate.latitude) * latitudeScale
        let deltaX = endX - startX
        let deltaY = endY - startY
        let lengthSquared = deltaX * deltaX + deltaY * deltaY
        let unclampedFraction = lengthSquared > 0 ? -(startX * deltaX + startY * deltaY) / lengthSquared : 0
        let fraction = min(1, max(0, unclampedFraction))
        let closestX = startX + deltaX * fraction
        let closestY = startY + deltaY * fraction
        return Projection(fraction: fraction, distanceMeters: hypot(closestX, closestY))
    }

    private struct Projection {
        let fraction: Double
        let distanceMeters: Double
    }

    private struct RouteMatch {
        let routeDistanceMeters: Double
        let distanceToRouteMeters: Double
        let segmentIndex: Int
        let projectedCoordinate: CLLocationCoordinate2D
    }
}
