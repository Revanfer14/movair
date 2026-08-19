import CoreLocation

protocol PolylineSimplifying {
    func simplify(_ coordinates: [CLLocationCoordinate2D], maxPointCount: Int) -> [CLLocationCoordinate2D]
}

struct PolylineSimplifier: PolylineSimplifying {
    private let initialToleranceMeters = 2.0
    private let maxToleranceDoublings = 12

    func simplify(_ coordinates: [CLLocationCoordinate2D], maxPointCount: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPointCount, maxPointCount > 1 else { return coordinates }

        var toleranceMeters = initialToleranceMeters
        var simplified = douglasPeucker(coordinates, toleranceMeters: toleranceMeters)

        var doublings = 0
        while simplified.count > maxPointCount, doublings < maxToleranceDoublings {
            toleranceMeters *= 2
            simplified = douglasPeucker(coordinates, toleranceMeters: toleranceMeters)
            doublings += 1
        }

        if simplified.count > maxPointCount {
            simplified = uniformStride(simplified, maxPointCount: maxPointCount)
        }

        return simplified
    }

    private func douglasPeucker(_ points: [CLLocationCoordinate2D], toleranceMeters: Double) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }

        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        markSignificantPoints(points, fromIndex: 0, toIndex: points.count - 1, toleranceMeters: toleranceMeters, keep: &keep)

        return points.indices.filter { keep[$0] }.map { points[$0] }
    }

    private func markSignificantPoints(
        _ points: [CLLocationCoordinate2D],
        fromIndex: Int,
        toIndex: Int,
        toleranceMeters: Double,
        keep: inout [Bool]
    ) {
        guard toIndex > fromIndex + 1 else { return }

        var maxDistance = 0.0
        var maxIndex = fromIndex

        for index in (fromIndex + 1)..<toIndex {
            let distance = perpendicularDistanceMeters(
                point: points[index],
                lineStart: points[fromIndex],
                lineEnd: points[toIndex]
            )
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = index
            }
        }

        guard maxDistance > toleranceMeters else { return }

        keep[maxIndex] = true
        markSignificantPoints(points, fromIndex: fromIndex, toIndex: maxIndex, toleranceMeters: toleranceMeters, keep: &keep)
        markSignificantPoints(points, fromIndex: maxIndex, toIndex: toIndex, toleranceMeters: toleranceMeters, keep: &keep)
    }

    private func perpendicularDistanceMeters(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let referenceLatitudeRadians = lineStart.latitude * .pi / 180
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = 111_320.0 * cos(referenceLatitudeRadians)

        func toLocalMeters(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            (
                x: (coordinate.longitude - lineStart.longitude) * metersPerDegreeLongitude,
                y: (coordinate.latitude - lineStart.latitude) * metersPerDegreeLatitude
            )
        }

        let p = toLocalMeters(point)
        let a = toLocalMeters(lineStart)
        let b = toLocalMeters(lineEnd)

        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy

        guard lengthSquared > 0 else {
            return hypot(p.x - a.x, p.y - a.y)
        }

        let projectionFraction = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projectedX = a.x + projectionFraction * dx
        let projectedY = a.y + projectionFraction * dy

        return hypot(p.x - projectedX, p.y - projectedY)
    }

    private func uniformStride(_ coordinates: [CLLocationCoordinate2D], maxPointCount: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPointCount, maxPointCount > 1 else { return coordinates }
        let stride = Double(coordinates.count - 1) / Double(maxPointCount - 1)
        return (0..<maxPointCount).map { index in
            coordinates[Int((Double(index) * stride).rounded())]
        }
    }
}
