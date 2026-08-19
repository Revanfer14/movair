import Foundation

enum ExposureEstimationError: Error {
    case invalidRoute
    case routeOutsideValidatedCoverage
    case unavailableData
    case modelPredictionFailed

    var userMessage: String {
        switch self {
        case .invalidRoute:
            return "This route doesn't have enough location data to calculate."
        case .routeOutsideValidatedCoverage:
            return "This route passes through an area outside our validated coverage."
        case .unavailableData:
            return "Air quality data is currently unavailable. Please try again."
        case .modelPredictionFailed:
            return "Exposure prediction couldn't be calculated right now."
        }
    }
}
