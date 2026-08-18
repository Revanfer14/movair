import Foundation

protocol RoutePlanArchiving: Sendable {
    func archive(_ payload: RoutePlanPayload) async
}

final class RoutePlanArchiver: RoutePlanArchiving {
    private let api: MovairAPI

    init(api: MovairAPI = MovairAPIClient()) {
        self.api = api
    }

    func archive(_ payload: RoutePlanPayload) async {
        let totalSegments = payload.routes.reduce(0) { $0 + $1.segments.count }
        guard totalSegments <= DoseConstants.maxArchivedSegments else {
            return
        }
        _ = try? await api.archiveRoutePlan(payload)
    }
}
