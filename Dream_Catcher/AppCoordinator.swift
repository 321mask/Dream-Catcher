//
//  AppCoordinator.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation
import Observation
import SwiftData

@Observable
final class AppCoordinator {
    var statusText: String = "Idle"
    var lastUpdatedAt: Date?
    var nextWindows: [DateInterval] = []
    var lastCurve: [Double] = []

    private let healthClient = HealthKitClient()
    private let analyzer = RemCurveAnalyzer()
    private let windowSelector = RemWindowSelector()
    private let cueScheduler = CueScheduler()

    func bootstrapIfNeeded() async {
        do {
            try await healthClient.requestAuthorization()
            await MainActor.run { self.statusText = "Health permissions granted" }
        } catch {
            await MainActor.run { self.statusText = "Health permission error: \(error.localizedDescription)" }
        }
    }

    func runNightlyUpdate(modelContainer: ModelContainer, referenceNow: Date = .now) async {
        await MainActor.run { self.statusText = "Updating…" }

        let store = DataStore(modelContainer: modelContainer)

        do {
            // 1) HealthKit fetch (not main-thread)
            let nights = try await healthClient.fetchSleepNights(lastNDays: 45, now: referenceNow)

            // 2) Persist via ModelActor (not main-thread)
            try await store.replaceOverlappingNights(nights)

            // 3) Fetch stored nights
            let stored = try await store.fetchRecentNights(limit: 60)

            // 4) Compute curve (pure CPU; not main-thread)
            let curve = analyzer.computeProbabilityCurve(
                nights: stored,
                binCount: RemCurveAnalyzer.defaultBinCount,
                halfLifeDays: 14,
                smoothingRadiusBins: 1
            )

            // 5) Persist model state
            _ = try await store.upsertModelState(probBins: curve, halfLifeDays: 14, smoothingRadiusBins: 1)

            // 6) Infer bedtime + choose windows
            let expectedSleepStart = inferExpectedSleepStart(storedNights: stored, fallbackNow: referenceNow)
            let windows = windowSelector.selectTopWindows(
                curve: curve,
                expectedSleepStart: expectedSleepStart,
                binMinutes: 30,
                maxWindows: 2
            )
            
            PhoneWatchSync.shared.sendRemWindowsToWatch(
                windows: windows,
                cuesPerWindow: 5,
                spacingSeconds: 120
            )

            // 7) Notifications (async; keep it off main)
            try await cueScheduler.requestAuthorizationIfNeeded()
            cueScheduler.replaceScheduledCues(for: windows, cuesPerWindow: 5, spacingSeconds: 120)

            // 8) UI updates on main
            await MainActor.run {
                self.lastCurve = curve
                self.nextWindows = windows
                self.lastUpdatedAt = .now
                self.statusText = "Updated ✓"
            }

        } catch {
            await MainActor.run {
                self.statusText = "Update failed: \(error.localizedDescription)"
            }
        }
    }

    /*private func inferExpectedSleepStart(storedNights: [SleepNight], fallbackNow: Date) -> Date {
        let recent = storedNights.prefix(14)
        guard !recent.isEmpty else { return fallbackNow }
        let minutes = recent.map { DateUtils.minutesSinceMidnight($0.sleepStart) }.sorted()
        let median = minutes[minutes.count / 2]
        return DateUtils.todayAt(minutesSinceMidnight: median, now: fallbackNow)
    }*/
    
    private func inferExpectedSleepStart(storedNights: [SleepNight], fallbackNow: Date) -> Date {
        let recent = storedNights.prefix(14)
        guard !recent.isEmpty else { return fallbackNow }

        let minutes = recent
            .map { DateUtils.minutesSinceMidnight($0.sleepStart) }
            .sorted()

        let median = minutes[minutes.count / 2]

        // Build "today at that time"
        var candidate = DateUtils.todayAt(minutesSinceMidnight: median, now: fallbackNow)

        // If that time already passed today, move it to tomorrow
        if candidate <= fallbackNow {
            candidate = Calendar.current.date(byAdding: .day, value: 1, to: candidate)!
        }

        return candidate
    }
}
