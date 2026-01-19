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
    @State private var coordinator = AppCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DashboardView(coordinator: coordinator)
                .modelContainer(AppContainer.makeModelContainer())
                .task {
                    BackgroundTasks.register()
                    BackgroundTasks.scheduleNightlyRefresh()
                    await coordinator.bootstrapIfNeeded()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Deterministic catch-up on foregrounding
                Task { await runCatchUpIfNeeded() }
            }
        }
    }

    @MainActor
    private func runCatchUpIfNeeded() async {
        // We need a ModelContext here; simplest is to create a container.
        // If you prefer, pass modelContext through environment in a root view.
        let container = AppContainer.makeModelContainer()
        let context = ModelContext(container)

        let last = DailyUpdatePolicy.readLastUpdatedAt(modelContext: context)
        if DailyUpdatePolicy.shouldRunNow(lastUpdatedAt: last) {
            await coordinator.runNightlyUpdate(modelContainer: container)
        }
    }
}

