import Foundation
import SwiftUI

enum ExposureLevel: String, Codable, Equatable {
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

    var aqiSymbolName: String {
        switch self {
        case .low: return "aqi.low"
        case .moderate: return "aqi.medium"
        case .high: return "aqi.medium"
        case .veryHigh, .extreme: return "aqi.high"
        }
    }

    var primaryColor: Color {
        switch self {
        case .low: return Color.Brand.primaryGreen
        case .moderate: return Color.Brand.primaryYellow
        case .high: return Color.Brand.primaryOrange
        case .veryHigh: return Color.Brand.primaryRed
        case .extreme: return Color.Brand.primaryMaroon
        }
    }

    var secondaryColor: Color {
        switch self {
        case .low: return Color.Brand.secondaryGreen
        case .moderate: return Color.Brand.secondaryYellow
        case .high: return Color.Brand.secondaryOrange
        case .veryHigh: return Color.Brand.secondaryRed
        case .extreme: return Color.Brand.secondaryMaroon
        }
    }

    static func from(exposureUg: Int) -> ExposureLevel {
        switch exposureUg {
        case ..<50: return .low
        case 50..<100: return .moderate
        case 100..<150: return .high
        case 150..<200: return .veryHigh
        default: return .extreme
        }
    }
}
