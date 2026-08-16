import Foundation

struct RecentSearch: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let date: Date

    init(id: UUID = UUID(), title: String, date: Date = Date()) {
        self.id = id
        self.title = title
        self.date = date
    }
}
