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
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var coordinator: AppCoordinator
    @State private var modelContainer = AppContainer.makeModelContainer()

    init() {
        let coordinator = AppCoordinator()
        _coordinator = State(initialValue: coordinator)
        PhoneWatchSync.shared.sleepSessionController = coordinator
        PhoneWatchSync.shared.refreshSleepSessionStateFromController()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    DashboardView(coordinator: coordinator)
                } else {
                    OnboardingView(coordinator: coordinator) {
                        hasSeenOnboarding = true
                    }
                }
            }
            .task {
                await coordinator.bootstrapIfNeeded()
                await coordinator.runNightlyUpdate(modelContainer: modelContainer)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await coordinator.runNightlyUpdate(modelContainer: modelContainer)
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
