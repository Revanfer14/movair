import Foundation
import Combine

final class MapSearchDataStore: ObservableObject {
    @Published private(set) var recents: [RecentSearch] = []

    private let defaultsKey = "recentSearches"
    private let maxItems = 10
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Avoid duplicates, most-recent-first.
        recents.removeAll { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }
        recents.insert(RecentSearch(title: trimmed), at: 0)
        if recents.count > maxItems {
            recents = Array(recents.prefix(maxItems))
        }
        save()
    }

    func remove(_ item: RecentSearch) {
        recents.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        recents.removeAll()
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([RecentSearch].self, from: data) else { return }
        recents = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(recents) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
