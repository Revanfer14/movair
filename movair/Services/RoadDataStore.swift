import CoreLocation

protocol RoadDataProviding: Sendable {
    func attributes(for coordinate: CLLocationCoordinate2D) throws -> RoadAttributes
}

final class RoadDataStore: RoadDataProviding, @unchecked Sendable {
    private struct Dataset: Decodable {
        let meta: Metadata
        let cells: [String: [Double]]
    }

    private struct Metadata: Decodable {
        let latMin: Double
        let lonMin: Double
        let step: Double

        enum CodingKeys: String, CodingKey {
            case latMin = "lat_min"
            case lonMin = "lon_min"
            case step
        }
    }

    static let shared: RoadDataStore? = try? RoadDataStore()

    private let dataset: Dataset

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "roads_data", withExtension: "json") else {
            throw ExposureEstimationError.unavailableData
        }
        dataset = try JSONDecoder().decode(Dataset.self, from: Data(contentsOf: url))
    }

    func attributes(for coordinate: CLLocationCoordinate2D) throws -> RoadAttributes {
        let latitudeIndex = Int((coordinate.latitude - dataset.meta.latMin) / dataset.meta.step)
        let longitudeIndex = Int((coordinate.longitude - dataset.meta.lonMin) / dataset.meta.step)
        let key = "\(latitudeIndex)_\(longitudeIndex)"

        guard let values = dataset.cells[key], values.count == 2 else {
            return RoadAttributes(roadClass: 4, greeneryIndex: 0, usedDefault: true)
        }

        let roadClass = Int(values[0]) == 1 ? 3 : Int(values[0])
        return RoadAttributes(roadClass: roadClass, greeneryIndex: values[1], usedDefault: false)
    }
}
