//
//  movairApp.swift
//  movair
//
//  Created by Revan Ferdinand on 12/08/26.
//

import SwiftUI

@main
struct movairApp: App {
    // Activate WatchConnectivity as early as possible
    @StateObject private var phoneConnectivity = PhoneConnectivityManager.shared

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
