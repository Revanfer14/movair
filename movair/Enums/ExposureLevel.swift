import Foundation
import CoreLocation
import MapKit

enum ExposureLevel: String, Equatable {
    case low
    case moderate
    case high
    case veryHigh
    case extreme

    var title: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very high"
        case .extreme: return "Extreme"
        }
    }
}
