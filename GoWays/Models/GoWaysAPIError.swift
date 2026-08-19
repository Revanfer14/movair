import Foundation

enum GoWaysAPIError: Error, Equatable {
    case missingBaseURL
    case invalidRequest
    case invalidInputValue
    case payloadTooLarge
    case notFound
    case rateLimited(retryAfterSeconds: Int)
    case serviceUnavailable
    case requestFailed(statusCode: Int)
    case decodingFailed
    case timedOut

    var userMessage: String {
        switch self {
        case .missingBaseURL:
            return "Server configuration is incomplete. Contact the app developer."
        case .invalidRequest:
            return "Invalid request."
        case .invalidInputValue:
            return "Invalid input value."
        case .payloadTooLarge:
            return "Request is too large."
        case .notFound:
            return "Data not found."
        case .rateLimited:
            return "Too many requests — try again shortly."
        case .serviceUnavailable:
            return "The service is having issues, please try again."
        case .requestFailed:
            return "The service is having issues, please try again."
        case .decodingFailed:
            return "The server's response couldn't be read."
        case .timedOut:
            return "The connection to the server timed out. Please try again."
        }
    }
}
