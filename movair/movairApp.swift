//
//  movairApp.swift
//  movair
//
//  Created by Revan Ferdinand on 12/08/26.
//

import SwiftUI

@main
struct movairApp: App {
    @StateObject private var phoneConnectivity = PhoneConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
