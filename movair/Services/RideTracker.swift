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
    private var travelledCoordinates: [CLLocationCoordinate2D] = []
    private var lastTraceLocation: CLLocation?
    private var traceSpacingMeters = DoseConstants.traceMinimumSpacingMeters

    init(segments: [RouteSegment]) {
        self.segments = segments
        segmentDurations = Array(repeating: 0, count: segments.count)
        interpolatedSegmentFlags = Array(repeating: false, count: segments.count)
    }

    func process(location: CLLocation) -> RideTrackingSnapshot {
        let uptime = ProcessInfo.processInfo.systemUptime
        let delta = consumeElapsedDuration(at: uptime)
        updateTravelledDistance(with: location)
        recordTrace(with: location)

        guard let match = closestMatch(to: location.coordinate) else {
            attributeToActiveSegment(elapsed: delta)
            return snapshot()
        }

        if match.distanceToRouteMeters > DoseConstants.offRouteDistanceMeters {
            isOffRoute = true
            attributeToActiveSegment(elapsed: delta, fallbackRouteDistance: match.routeDistanceMeters)
            return snapshot()
        }

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
            isOffRoute: isOffRoute,
            activeSegmentIndex: activeSegmentIndex,
            interpolatedSegmentFlags: interpolatedSegmentFlags,
            travelledCoordinates: travelledCoordinates
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

    private func recordTrace(with location: CLLocation) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= DoseConstants.traceMaximumAccuracyMeters else { return }

        guard let previousTraceLocation = lastTraceLocation else {
            lastTraceLocation = location
            travelledCoordinates.append(location.coordinate)
            return
        }

        guard location.distance(from: previousTraceLocation) >= traceSpacingMeters else { return }
        lastTraceLocation = location
        travelledCoordinates.append(location.coordinate)

        if travelledCoordinates.count > DoseConstants.traceMaximumPointCount {
            decimateTravelledCoordinates()
        }
    }

    private func decimateTravelledCoordinates() {
        guard travelledCoordinates.count > 2 else { return }
        var decimated: [CLLocationCoordinate2D] = []
        decimated.reserveCapacity(travelledCoordinates.count / 2 + 1)
        for (index, coordinate) in travelledCoordinates.enumerated() {
            let isEndpoint = index == 0 || index == travelledCoordinates.count - 1
            if isEndpoint || index % 2 == 0 {
                decimated.append(coordinate)
            }
        }
        travelledCoordinates = decimated
        traceSpacingMeters *= 2
    }

    private func attributeToActiveSegment(elapsed: TimeInterval, fallbackRouteDistance: Double? = nil) {
        guard !segments.isEmpty else { return }
        if let activeSegmentIndex {
            segmentDurations[activeSegmentIndex] += elapsed
        } else {
            let initialIndex: Int
            if let fallbackRouteDistance {
                initialIndex = segmentIndex(for: fallbackRouteDistance)
            } else {
                initialIndex = 0
            }
            activeSegmentIndex = initialIndex
            segmentDurations[initialIndex] += elapsed
        }
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

        if let activeSegmentIndex {
            let localStart = max(0, activeSegmentIndex - 2)
            let localEnd = min(segments.count - 1, activeSegmentIndex + 5)
            let localMatches = (localStart...localEnd).compactMap { index -> RouteMatch? in
                let segment = segments[index]
                let projection = projection(of: coordinate, onto: segment)
                return RouteMatch(
                    routeDistanceMeters: segment.startDistanceMeters + segment.distanceMeters * projection.fraction,
                    distanceToRouteMeters: projection.distanceMeters,
                    segmentIndex: index
                )
            }
            if let bestLocal = localMatches.min(by: { $0.distanceToRouteMeters < $1.distanceToRouteMeters }),
               bestLocal.distanceToRouteMeters <= DoseConstants.offRouteDistanceMeters {
                return bestLocal
            }
        } else {
            let initialEnd = min(segments.count - 1, 4)
            let initialMatches = (0...initialEnd).compactMap { index -> RouteMatch? in
                let segment = segments[index]
                let projection = projection(of: coordinate, onto: segment)
                return RouteMatch(
                    routeDistanceMeters: segment.startDistanceMeters + segment.distanceMeters * projection.fraction,
                    distanceToRouteMeters: projection.distanceMeters,
                    segmentIndex: index
                )
            }
            if let bestInitial = initialMatches.min(by: { $0.distanceToRouteMeters < $1.distanceToRouteMeters }),
               bestInitial.distanceToRouteMeters <= DoseConstants.offRouteDistanceMeters {
                return bestInitial
            }
        }

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
