import CoreLocation

protocol RouteSegmenting {
    func makeSegments(from coordinates: [CLLocationCoordinate2D]) -> [RouteSegment]
}

struct RouteSegmenter: RouteSegmenting {
    private let targetSegmentLengthMeters = DoseConstants.segmentLengthMeters

    func makeSegments(from coordinates: [CLLocationCoordinate2D]) -> [RouteSegment] {
        guard coordinates.count > 1 else { return [] }

        var segments: [RouteSegment] = []
        var segmentStart = coordinates[0]
        var currentCoordinate = coordinates[0]
        var accumulatedDistance = 0.0
        var cumulativeDistance = 0.0

        for coordinate in coordinates.dropFirst() {
            var edgeStart = currentCoordinate
            var remainingEdgeDistance = CLLocation(latitude: edgeStart.latitude, longitude: edgeStart.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))

            while remainingEdgeDistance > 0 {
                let neededDistance = targetSegmentLengthMeters - accumulatedDistance
                if remainingEdgeDistance < neededDistance {
                    accumulatedDistance += remainingEdgeDistance
                    edgeStart = coordinate
                    remainingEdgeDistance = 0
                } else {
                    let fraction = neededDistance / remainingEdgeDistance
                    let segmentEnd = interpolatedCoordinate(from: edgeStart, to: coordinate, fraction: fraction)
                    segments.append(
                        makeSegment(
                            from: segmentStart,
                            to: segmentEnd,
                            distanceMeters: targetSegmentLengthMeters,
                            startDistanceMeters: cumulativeDistance
                        )
                    )
                    cumulativeDistance += targetSegmentLengthMeters
                    segmentStart = segmentEnd
                    edgeStart = segmentEnd
                    accumulatedDistance = 0
                    remainingEdgeDistance = CLLocation(latitude: edgeStart.latitude, longitude: edgeStart.longitude)
                        .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                }
            }
            currentCoordinate = coordinate
        }

        if accumulatedDistance > 0 {
            segments.append(
                makeSegment(
                    from: segmentStart,
                    to: currentCoordinate,
                    distanceMeters: accumulatedDistance,
                    startDistanceMeters: cumulativeDistance
                )
            )
        }
        return segments
    }

    private func makeSegment(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        distanceMeters: Double,
        startDistanceMeters: Double
    ) -> RouteSegment {
        RouteSegment(
            start: start,
            end: end,
            midpoint: interpolatedCoordinate(from: start, to: end, fraction: 0.5),
            distanceMeters: distanceMeters,
            startDistanceMeters: startDistanceMeters,
            endDistanceMeters: startDistanceMeters + distanceMeters
        )
    }

    private func interpolatedCoordinate(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        fraction: Double
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: start.latitude + (end.latitude - start.latitude) * fraction,
            longitude: start.longitude + (end.longitude - start.longitude) * fraction
        )
    }
}
