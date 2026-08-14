import Foundation
import MapKit
import Combine

@MainActor
final class MapSearchViewModel: ObservableObject {

    @Published var searchText: String = "" {
        didSet { scheduleSearch() }
    }

    @Published var selectedDestination: SelectedDestination?

    let dataStore: MapSearchDataStore
    let searchService: MapSearchService

    var results: [SearchResult] { searchService.results }
    var recents: [RecentSearch] { dataStore.recents }

    private let debounceDelay: Duration = .milliseconds(500)
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(dataStore: MapSearchDataStore? = nil,
         searchService: MapSearchService? = nil) {
        self.dataStore = dataStore ?? MapSearchDataStore()
        self.searchService = searchService ?? MapSearchService()

        self.dataStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        self.searchService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func biasSearch(around coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        searchService.setRegion(region)
    }

    func selectRecent(_ recent: RecentSearch) {
        searchText = recent.title
        dataStore.add(recent.title)
        // Resolve as destination with dummy coordinate near BSD if no map result
        selectedDestination = SelectedDestination(
            title: recent.title,
            subtitle: "",
            coordinate: CLLocationCoordinate2D(latitude: -6.3015, longitude: 106.6532)
        )
    }

    func selectResult(_ result: SearchResult) {
        dataStore.add(result.title)
        Task {
            await resolveAndSelect(result)
        }
    }

    func clearSelection() {
        selectedDestination = nil
    }

    func deleteRecent(_ recent: RecentSearch) {
        dataStore.remove(recent)
    }

    func clearAllRecents() {
        dataStore.clearAll()
    }

    private func resolveAndSelect(_ result: SearchResult) async {
        if let completion = result.completion {
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            do {
                let response = try await search.start()
                if let item = response.mapItems.first, let coordinate = item.placemark.location?.coordinate {
                    selectedDestination = SelectedDestination(
                        title: result.title,
                        subtitle: result.subtitle,
                        coordinate: coordinate
                    )
                    return
                }
            } catch {
                print("Resolve destination error: \(error.localizedDescription)")
            }
        }

        // Fallback dummy coordinate (BXChange Mall / BSD area)
        selectedDestination = SelectedDestination(
            title: result.title,
            subtitle: result.subtitle,
            coordinate: CLLocationCoordinate2D(latitude: -6.3015, longitude: 106.6532)
        )
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchService.cancel()
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: self?.debounceDelay ?? .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.searchService.updateQuery(query)
        }
    }
}
