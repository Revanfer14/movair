import Foundation

protocol RideRecordArchiving: Sendable {
    func archive(_ payload: RideRecordPayload) async
    func drainPending() async
}

final class RideRecordArchiver: RideRecordArchiving {
    static let shared = RideRecordArchiver()

    private let api: GoWaysAPI
    private let fileManager: FileManager
    private let pendingDirectoryURL: URL

    init(api: GoWaysAPI = GoWaysAPIClient(), fileManager: FileManager = .default) {
        self.api = api
        self.fileManager = fileManager
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        pendingDirectoryURL = directory.appendingPathComponent("pending-ride-records", isDirectory: true)
        try? fileManager.createDirectory(at: pendingDirectoryURL, withIntermediateDirectories: true)
    }

    func archive(_ payload: RideRecordPayload) async {
        guard payload.segments.count <= DoseConstants.maxArchivedSegments else { return }
        guard let bodyData = try? JSONEncoder().encode(payload) else { return }

        let fileURL = pendingFileURL(forID: payload.id)
        try? bodyData.write(to: fileURL, options: [.atomic])

        guard (try? await api.archiveRideRecord(bodyData: bodyData)) != nil else { return }
        try? fileManager.removeItem(at: fileURL)
    }

    func drainPending() async {
        removeExpiredPendingFiles()

        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: pendingDirectoryURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in fileURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let bodyData = try? Data(contentsOf: fileURL) else { continue }
            do {
                try await api.archiveRideRecord(bodyData: bodyData)
                try? fileManager.removeItem(at: fileURL)
            } catch {
                return
            }
        }
    }

    private func pendingFileURL(forID id: String) -> URL {
        pendingDirectoryURL.appendingPathComponent("\(id).json")
    }

    private func removeExpiredPendingFiles() {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: pendingDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-DoseConstants.pendingRideRecordRetentionSeconds)
        for fileURL in fileURLs {
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt < cutoff else { continue }
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
