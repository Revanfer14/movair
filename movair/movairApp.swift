import SwiftUI

@main
struct movairApp: App {
    var body: some Scene {
        WindowGroup {
            AppTabView()
                .task {
                    // Debug: load HealthKit profile (age/sex/height) and print to console
                    let provider = HealthKitVentilationRateProvider()
                    await provider.prepare()
                }
        }
    }
}
