import MapKit

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion?

    init(completion: MKLocalSearchCompletion) {
        self.title = completion.title
        self.subtitle = completion.subtitle
        self.completion = completion
    }

    init(title: String, subtitle: String = "") {
        self.title = title
        self.subtitle = subtitle
        self.completion = nil
    }
}
