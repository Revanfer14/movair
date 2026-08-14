import Foundation
import CoreLocation
import MapKit

enum NavigationPhase: Equatable {
    case browsing
    case routeSelection
    case navigating
    case paused
}
