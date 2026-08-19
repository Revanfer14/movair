import Foundation

struct PredictResponse: Decodable {
    let modelVersion: String
    let cBase: [Double]

    enum CodingKeys: String, CodingKey {
        case modelVersion = "model_version"
        case cBase = "c_base"
    }
}
