import Foundation

enum ExposureEstimationError: Error {
    case invalidRoute
    case routeOutsideValidatedCoverage
    case unavailableData
    case modelPredictionFailed

    var userMessage: String {
        switch self {
        case .invalidRoute:
            return "Rute tidak memiliki data lokasi yang cukup untuk dihitung."
        case .routeOutsideValidatedCoverage:
            return "Rute melewati area di luar cakupan perhitungan yang divalidasi."
        case .unavailableData:
            return "Data kualitas udara sedang tidak tersedia. Silakan coba lagi."
        case .modelPredictionFailed:
            return "Prediksi paparan tidak dapat dihitung saat ini."
        }
    }
}
