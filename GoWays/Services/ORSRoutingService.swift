import Foundation
import CoreLocation

protocol ORSRouting: Sendable {
    func fetchRoutes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> [ORSRoute]
}

final class ORSRoutingService: ORSRouting {
    private static let directionsURL = URL(string: "https://api.openrouteservice.org/v2/directions/cycling-regular/geojson")!
    private static let alternativeRouteCount = 3
    private static let alternativeShareFactor = 0.6
    private static let alternativeWeightFactor = 1.6
    private static let cacheKeyPrecision = 4
    private static let requestTimeout: TimeInterval = 15

    private let session: URLSession
    private var cache: [String: [ORSRoute]] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchRoutes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> [ORSRoute] {
        let cacheKey = Self.cacheKey(origin: origin, destination: destination)
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "ORS_API_KEY") as? String,
              !apiKey.isEmpty else {
            throw ORSRoutingError.invalidAPIKey
        }

        var request = URLRequest(url: Self.directionsURL, timeoutInterval: Self.requestTimeout)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(
            coordinates: [
                [origin.longitude, origin.latitude],
                [destination.longitude, destination.latitude]
            ],
            alternativeRoutes: AlternativeRoutesOptions(
                targetCount: Self.alternativeRouteCount,
                shareFactor: Self.alternativeShareFactor,
                weightFactor: Self.alternativeWeightFactor
            ),
            instructions: true,
            elevation: false
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ORSRoutingError.timedOut
        } catch {
            throw ORSRoutingError.requestFailed(statusCode: 0)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ORSRoutingError.requestFailed(statusCode: 0)
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw ORSRoutingError.invalidAPIKey
        case 403:
            throw ORSRoutingError.quotaExceeded
        case 404:
            throw ORSRoutingError.noRouteFound
        default:
            throw ORSRoutingError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let decoded: DirectionsResponse
        do {
            decoded = try JSONDecoder().decode(DirectionsResponse.self, from: data)
        } catch {
            throw ORSRoutingError.decodingFailed
        }

        guard !decoded.features.isEmpty else {
            throw ORSRoutingError.noRouteFound
        }

        let routes = decoded.features.map { feature -> ORSRoute in
            let coordinates = feature.geometry.coordinates.map {
                CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
            }

            var steps: [RouteStep] = []
            if let segments = feature.properties.segments {
                for segment in segments {
                    if let rawSteps = segment.steps {
                        for step in rawSteps {
                            let startWaypoint = step.wayPoints.first ?? 0
                            let coordinate = coordinates.indices.contains(startWaypoint)
                                ? coordinates[startWaypoint]
                                : (coordinates.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0))
                            steps.append(
                                RouteStep(
                                    distanceMeters: step.distance,
                                    durationSeconds: step.duration,
                                    maneuverType: step.type,
                                    text: step.instruction,
                                    streetName: step.name,
                                    coordinate: coordinate,
                                    waypointIndex: startWaypoint
                                )
                            )
                        }
                    }
                }
            }

            return ORSRoute(
                coordinates: coordinates,
                distanceMeters: feature.properties.summary.distance,
                durationSeconds: feature.properties.summary.duration,
                steps: steps
            )
        }

        cache[cacheKey] = routes
        return routes
    }

    private static func cacheKey(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) -> String {
        func rounded(_ value: Double) -> Double {
            let multiplier = pow(10, Double(cacheKeyPrecision))
            return (value * multiplier).rounded() / multiplier
        }
        return "\(rounded(origin.latitude)),\(rounded(origin.longitude))_\(rounded(destination.latitude)),\(rounded(destination.longitude))"
    }

    private struct RequestBody: Encodable {
        let coordinates: [[Double]]
        let alternativeRoutes: AlternativeRoutesOptions
        let instructions: Bool
        let elevation: Bool
    }

    private struct AlternativeRoutesOptions: Encodable {
        let targetCount: Int
        let shareFactor: Double
        let weightFactor: Double
    }

    private struct DirectionsResponse: Decodable {
        let features: [Feature]
    }

    private struct Feature: Decodable {
        let geometry: Geometry
        let properties: Properties
    }

    private struct Geometry: Decodable {
        let coordinates: [[Double]]
    }

    private struct Properties: Decodable {
        let summary: Summary
        let segments: [Segment]?
    }

    private struct Segment: Decodable {
        let distance: Double
        let duration: Double
        let steps: [Step]?
    }

    private struct Step: Decodable {
        let distance: Double
        let duration: Double
        let type: Int
        let instruction: String
        let name: String
        let wayPoints: [Int]

        enum CodingKeys: String, CodingKey {
            case distance
            case duration
            case type
            case instruction
            case name
            case wayPoints = "way_points"
        }
    }

    private struct Summary: Decodable {
        let distance: Double
        let duration: Double
    }
}
