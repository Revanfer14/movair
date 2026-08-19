import Foundation
import CoreLocation

enum RouteTraceSplitter {
    static func splitAtGaps(_ coordinates: [CLLocationCoordinate2D]) -> [[CLLocationCoordinate2D]] {
        guard coordinates.count >= 2 else { return [coordinates] }
        var runs: [[CLLocationCoordinate2D]] = []
        var currentRun: [CLLocationCoordinate2D] = [coordinates[0]]

        for index in 1..<coordinates.count {
            let previous = CLLocation(latitude: coordinates[index - 1].latitude, longitude: coordinates[index - 1].longitude)
            let current = CLLocation(latitude: coordinates[index].latitude, longitude: coordinates[index].longitude)
            if previous.distance(from: current) > DoseConstants.traceBreakDistanceMeters {
                runs.append(currentRun)
                currentRun = [coordinates[index]]
            } else {
                currentRun.append(coordinates[index])
            }
        }
        runs.append(currentRun)
        return runs
    }
}
