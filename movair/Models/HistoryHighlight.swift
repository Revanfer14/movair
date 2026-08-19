import Foundation
import CoreLocation

struct HistoryHighlight: Identifiable {
    let id = UUID()
    let systemImage: String
    let text: String
}
