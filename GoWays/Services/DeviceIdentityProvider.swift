import Foundation

protocol DeviceIdentifying: Sendable {
    var deviceID: String { get }
}

final class DeviceIdentityProvider: DeviceIdentifying, @unchecked Sendable {
    private static let defaultsKey = "movairDeviceID"

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var deviceID: String {
        lock.lock()
        defer { lock.unlock() }

        if let stored = defaults.string(forKey: Self.defaultsKey), !stored.isEmpty {
            return stored
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: Self.defaultsKey)
        return generated
    }
}
