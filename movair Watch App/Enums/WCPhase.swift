import Foundation

enum WCPhase: String {
    case idle
    case active
    case paused
    case completed

    init(from navigationPhase: String) {
        switch navigationPhase {
        case "navigating": self = .active
        case "paused": self = .paused
        case "tripSummary": self = .completed
        default: self = .idle
        }
    }
}
