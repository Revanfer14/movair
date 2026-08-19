import Foundation
import CoreLocation

struct WatchRouteSync {
    let coordinates: [CLLocationCoordinate2D]

    init?(from dictionary: [String: Any]) {
        guard let points = dictionary[WCKeys.routePoints] as? [[Double]] else {
            return nil
        }
        coordinates = points.compactMap { point in
            guard point.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: point[0], longitude: point[1])
        }
    }
}
