import Foundation
import MapKit
import Combine

@MainActor
final class MapSearchViewModel: ObservableObject {
    @Published var searchText: String = "" {
        didSet { scheduleSearch() }
    }

    let recentStore: MapSearchDataStore
    let completerService: MapSearchService

    var results: [SearchResult] { completerService.results }
    var recents: [RecentSearch] { recentStore.recents }

    private let debounceDelay: Duration = .milliseconds(300)
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(recentStore: MapSearchDataStore = MapSearchDataStore(),
         completerService: MapSearchService = MapSearchService()) {
        self.recentStore = recentStore
        self.completerService = completerService

        // Re-publish nested ObservableObjects' changes so SwiftUI updates.
        recentStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        completerService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func biasSearch(around coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        
        completerService.setRegion(region)
    }

    func selectRecent(_ recent: RecentSearch) {
        searchText = recent.title
        recentStore.add(recent.title) // bump to top / refresh timestamp
    }

    func selectResult(_ result: SearchResult) {
        recentStore.add(result.title)
        // TODO: forward the selected MKLocalSearchCompletion up to trigger
        // route generation (e.g. via a delegate/closure passed into the view).
    }

    func deleteRecent(_ recent: RecentSearch) {
        recentStore.remove(recent)
    }

    func clearAllRecents() {
        recentStore.clearAll()
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            completerService.cancel()
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: self?.debounceDelay ?? .milliseconds(500))
            
            guard !Task.isCancelled, let self else { return }
            
            self.completerService.updateQuery(query)
        }
    }
}
