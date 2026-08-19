import CoreLocation

protocol SegmentFetchGrouping {
    func makeGroups(from segments: [RouteSegment]) -> [SegmentFetchGroup]
}

struct SegmentFetchGrouper: SegmentFetchGrouping {
    func makeGroups(from segments: [RouteSegment]) -> [SegmentFetchGroup] {
        guard !segments.isEmpty else { return [] }

        var groups: [(reference: CLLocation, indices: [Int])] = []
        var currentReference: CLLocation?
        var currentIndices: [Int] = []

        for (index, segment) in segments.enumerated() {
            let segmentLocation = CLLocation(
                latitude: segment.midpoint.latitude,
                longitude: segment.midpoint.longitude
            )

            if let currentReference, segmentLocation.distance(from: currentReference) <= DoseConstants.fetchGroupingRadiusMeters {
                currentIndices.append(index)
                continue
            }

            if let currentReference {
                groups.append((currentReference, currentIndices))
            }
            currentReference = segmentLocation
            currentIndices = [index]
        }

        if let currentReference {
            groups.append((currentReference, currentIndices))
        }

        return groups.map {
            SegmentFetchGroup(referenceCoordinate: $0.reference.coordinate, segmentIndices: $0.indices)
        }
    }
}
