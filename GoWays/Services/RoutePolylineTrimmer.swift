import CoreLocation

protocol RoutePolylineTrimming {
    func remainingCoordinates(
        from coordinates: [CLLocationCoordinate2D],
        traveledDistanceMeters: Double
    ) -> [CLLocationCoordinate2D]
}

struct RoutePolylineTrimmer: RoutePolylineTrimming {
    func remainingCoordinates(
        from coordinates: [CLLocationCoordinate2D],
        traveledDistanceMeters: Double
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 1, traveledDistanceMeters > 0 else { return coordinates }

        var cumulativeDistance = 0.0

        for index in 0..<(coordinates.count - 1) {
            let start = coordinates[index]
            let end = coordinates[index + 1]
            let edgeDistanceMeters = CLLocation(latitude: start.latitude, longitude: start.longitude)
                .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))

            if cumulativeDistance + edgeDistanceMeters >= traveledDistanceMeters {
                let neededDistanceMeters = traveledDistanceMeters - cumulativeDistance
                let fraction = edgeDistanceMeters > 0 ? neededDistanceMeters / edgeDistanceMeters : 0
                let cutCoordinate = CLLocationCoordinate2D(
                    latitude: start.latitude + (end.latitude - start.latitude) * fraction,
                    longitude: start.longitude + (end.longitude - start.longitude) * fraction
                )
                return [cutCoordinate] + coordinates[(index + 1)...]
            }

            cumulativeDistance += edgeDistanceMeters
        }

        return [coordinates[coordinates.count - 1]]
    }
}
