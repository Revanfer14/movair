//
//  GoWaysApp.swift
//  GoWays
//
//  Created by Revan Ferdinand on 12/08/26.
//

import SwiftUI

@main
struct GoWaysApp: App {
    @StateObject private var phoneConnectivity = PhoneConnectivityManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                AppTabView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}
