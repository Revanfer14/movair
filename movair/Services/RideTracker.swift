import CoreLocation

final class RideTracker {
    private let segments: [RouteSegment]
    private var segmentDurations: [TimeInterval]
    private var activeSegmentIndex: Int?
    private var backwardCandidateIndex: Int?
    private var backwardCandidateCount = 0
    private var lastUpdateUptime: TimeInterval?
    private var lastLocation: CLLocation?
    private var elapsedDuration: TimeInterval = 0
    private var unattributedDuration: TimeInterval = 0
    private var travelledDistanceMeters: Double = 0
    private var offRouteStartedUptime: TimeInterval?
    private var isOffRoute = false

    init(segments: [RouteSegment]) {
        self.segments = segments
        segmentDurations = Array(repeating: 0, count: segments.count)
    }

    func process(location: CLLocation) -> RideTrackingSnapshot {
        let uptime = ProcessInfo.processInfo.systemUptime
        let delta = consumeElapsedDuration(at: uptime)
        updateTravelledDistance(with: location)

        guard let match = closestMatch(to: location.coordinate) else {
            return snapshot()
        }

        if match.distanceToRouteMeters > 50 {
            updateOffRouteState(at: uptime, elapsed: delta)
            return snapshot()
        }

        offRouteStartedUptime = nil
        isOffRoute = false
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
            isOffRoute: isOffRoute
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
        defer { lastLocation = location }
        guard let lastLocation, location.horizontalAccuracy >= 0 else { return }
        let distance = location.distance(from: lastLocation)
        guard distance <= 100 else { return }
        travelledDistanceMeters += distance
    }

    private func updateOffRouteState(at uptime: TimeInterval, elapsed: TimeInterval) {
        if offRouteStartedUptime == nil {
            offRouteStartedUptime = uptime
            accumulate(elapsed: elapsed, toward: activeSegmentIndex, routeDistanceMeters: nil)
            return
        }
        if let offRouteStartedUptime, uptime - offRouteStartedUptime > 15 {
            isOffRoute = true
            unattributedDuration += elapsed
        } else {
            accumulate(elapsed: elapsed, toward: activeSegmentIndex, routeDistanceMeters: nil)
        }
    }

    private func accumulate(
        elapsed: TimeInterval,
        toward matchedIndex: Int?,
        routeDistanceMeters: Double?
    ) {
        guard !segments.isEmpty else { return }
        let matchedIndex = matchedIndex ?? activeSegmentIndex ?? 0

        guard let activeSegmentIndex else {
            self.activeSegmentIndex = matchedIndex
            return
        }

        if matchedIndex == activeSegmentIndex {
            segmentDurations[activeSegmentIndex] += elapsed
            return
        }

        if matchedIndex > activeSegmentIndex {
            let boundary = segments[activeSegmentIndex].endDistanceMeters + 20
            if let routeDistanceMeters, routeDistanceMeters < boundary {
                segmentDurations[activeSegmentIndex] += elapsed
                return
            }
            distribute(elapsed: elapsed, from: activeSegmentIndex, through: matchedIndex)
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

        guard backwardCandidateCount >= 3 else {
            segmentDurations[activeSegmentIndex] += elapsed
            return
        }

        segmentDurations[matchedIndex] += elapsed
        self.activeSegmentIndex = matchedIndex
        backwardCandidateIndex = nil
        backwardCandidateCount = 0
    }

    private func distribute(elapsed: TimeInterval, from startIndex: Int, through endIndex: Int) {
        let indices = startIndex...endIndex
        let totalDistance = indices.reduce(0.0) { $0 + segments[$1].distanceMeters }
        guard totalDistance > 0 else {
            segmentDurations[startIndex] += elapsed
            return
        }
        for index in indices {
            segmentDurations[index] += elapsed * (segments[index].distanceMeters / totalDistance)
        }
    }

    private func segmentIndex(for routeDistanceMeters: Double) -> Int {
        segments.firstIndex { routeDistanceMeters <= $0.endDistanceMeters } ?? max(0, segments.count - 1)
    }

    private func closestMatch(to coordinate: CLLocationCoordinate2D) -> RouteMatch? {
        guard !segments.isEmpty else { return nil }
        return segments.enumerated().compactMap { index, segment in
            let projection = projection(of: coordinate, onto: segment)
            return RouteMatch(
                routeDistanceMeters: segment.startDistanceMeters + segment.distanceMeters * projection.fraction,
                distanceToRouteMeters: projection.distanceMeters,
                segmentIndex: index
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
    }
}
