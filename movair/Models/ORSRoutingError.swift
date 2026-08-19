import Foundation

enum ORSRoutingError: Error, Equatable {
    case invalidAPIKey
    case quotaExceeded
    case noRouteFound
    case timedOut
    case requestFailed(statusCode: Int)
    case decodingFailed

    var userMessage: String {
        switch self {
        case .invalidAPIKey:
            return "Route search isn't configured correctly. Please try again later."
        case .quotaExceeded:
            return "Route search is temporarily unavailable. Please try again in a bit."
        case .noRouteFound:
            return "No cycling route was found between these two points."
        case .timedOut:
            return "The route search timed out. Check your connection and try again."
        case .requestFailed:
            return "Something went wrong while searching for routes."
        case .decodingFailed:
            return "Something went wrong while reading the route data."
        }
    }
}
