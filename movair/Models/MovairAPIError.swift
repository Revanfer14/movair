import Foundation

enum MovairAPIError: Error, Equatable {
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
            return "Konfigurasi server belum lengkap. Hubungi pengembang aplikasi."
        case .invalidRequest:
            return "Permintaan tidak valid."
        case .invalidInputValue:
            return "Nilai input tidak valid."
        case .payloadTooLarge:
            return "Permintaan terlalu besar."
        case .notFound:
            return "Data tidak ditemukan."
        case .rateLimited:
            return "Terlalu banyak permintaan, coba lagi sebentar."
        case .serviceUnavailable:
            return "Layanan lagi gangguan, coba lagi."
        case .requestFailed:
            return "Layanan lagi gangguan, coba lagi."
        case .decodingFailed:
            return "Respons server tidak dapat dibaca."
        case .timedOut:
            return "Koneksi ke server terlalu lama. Silakan coba lagi."
        }
    }
}
