//
//  Dream_CatcherApp.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI
import SwiftData

@main
struct Dream_CatcherApp: App {

    @State private var coordinator: AppCoordinator

    init() {
        let coordinator = AppCoordinator()
        _coordinator = State(initialValue: coordinator)
        PhoneWatchSync.shared.sleepSessionController = coordinator
        PhoneWatchSync.shared.refreshSleepSessionStateFromController()
    }
    
    var body: some Scene {
        WindowGroup {
            OnboardingView(coordinator: coordinator)
        }
        .modelContainer(AppContainer.makeModelContainer())
    }
}
