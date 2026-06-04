//
//  BackgroundTasks.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation
import BackgroundTasks
import SwiftData

enum BackgroundTasks {
    static let nightlyRefreshID = "com.ya.mask2012@yandex.ru.Dream_Catcher.nightlyRefresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: nightlyRefreshID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Task { await handleRefresh(task: task) }
        }
    }

    /// Schedules the next refresh request around the next 10:00 deadline.
    static func scheduleNightlyRefresh(now: Date = .now) {
        let request = BGAppRefreshTaskRequest(identifier: nightlyRefreshID)

        // Ask the system to run near the next deadline.
        // If we’re already past today’s deadline, schedule for tomorrow’s.
        let deadline = DailyUpdatePolicy.todayDeadline(now: now)
        let cal = Calendar.current
        let next = (now < deadline) ? deadline : cal.date(byAdding: .day, value: 1, to: deadline)!

        // Give the system a little slack (e.g. start requesting at 09:45)
        request.earliestBeginDate = next.addingTimeInterval(-15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            log("Scheduled BG refresh around \(next)")
        } catch {
            log("Failed to submit BG task: \(error)")
        }
    }

    private static func handleRefresh(task: BGAppRefreshTask) async {
        let container = AppContainer.makeModelContainer()
        let context = ModelContext(container)
        let coordinator = AppCoordinator()

        task.expirationHandler = {
            log("BG task expired")
        }

        await coordinator.bootstrapIfNeeded()

        let last = DailyUpdatePolicy.readLastUpdatedAt(modelContext: context)
        if DailyUpdatePolicy.shouldRunNow(lastUpdatedAt: last) {
            await coordinator.runNightlyUpdate(modelContainer: container)
        } else {
            log("BG refresh skipped: not needed yet")
        }

        task.setTaskCompleted(success: true)
        scheduleNightlyRefresh()
    }
}
