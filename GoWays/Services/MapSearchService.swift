import MapKit
import Combine

final class MapSearchService: NSObject, ObservableObject {
    @Published var results: [SearchResult] = []

    private let completer = MKLocalSearchCompleter()
    private(set) var currentRegion: MKCoordinateRegion?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func setRegion(_ region: MKCoordinateRegion) {
        currentRegion = region
        completer.region = region
    }

    func updateQuery(_ fragment: String) {
        completer.queryFragment = fragment
    }

    func cancel() {
        completer.cancel()
        results = []
    }
}

extension MapSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results.map(SearchResult.init)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("SearchCompleterService error: \(error.localizedDescription)")
        results = []
    }
}
