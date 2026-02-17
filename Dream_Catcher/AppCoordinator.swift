//
//  AppCoordinator.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation
import Observation
import SwiftData
import UIKit

@Observable
final class AppCoordinator {
    var statusText: String = "Idle"
    var lastUpdatedAt: Date?
    var nextWindows: [DateInterval] = []
    var lastCurve: [Double] = []

    // MARK: - Sleep Session State

    enum SleepPhase: Equatable {
        case idle
        case calibrating
        case training
        case monitoring
    }

    var sleepPhase: SleepPhase = .idle

    /// Saved calibration (loaded from UserDefaults on launch).
    var calibration: VolumeCalibration?

    /// Active pre-sleep training session (non-nil during training).
    var trainingSession: PreSleepTrainingSession?

    /// Active REM cue scheduler (non-nil during overnight monitoring).
    private(set) var remScheduler: REMCueScheduler?

    // MARK: - Dependencies

    private let healthClient = HealthKitClient()
    private let analyzer = RemCurveAnalyzer()
    private let windowSelector = RemWindowSelector()
    private let cueScheduler = CueScheduler()
    let cuePlayer = LucidCuePlayer()
    let sleepFocusObserver = SleepFocusObserver()

    // MARK: - Bootstrap

    func bootstrapIfNeeded() async {
        calibration = VolumeCalibration.load()

        do {
            try await healthClient.requestAuthorization()
            await MainActor.run { self.statusText = "Health permissions granted" }
        } catch {
            await MainActor.run { self.statusText = "Health permission error: \(error.localizedDescription)" }
        }
    }

    // MARK: - Nightly Update

    func runNightlyUpdate(modelContainer: ModelContainer, referenceNow: Date = .now) async {
        await MainActor.run { self.statusText = "Updating..." }

        let store = DataStore(modelContainer: modelContainer)

        do {
            let nights = try await healthClient.fetchSleepNights(lastNDays: 45, now: referenceNow)
            try await store.replaceOverlappingNights(nights)
            let stored = try await store.fetchRecentNights(limit: 60)

            let curve = analyzer.computeProbabilityCurve(
                nights: stored,
                binCount: RemCurveAnalyzer.defaultBinCount,
                halfLifeDays: 14,
                smoothingRadiusBins: 1
            )

            _ = try await store.upsertModelState(probBins: curve, halfLifeDays: 14, smoothingRadiusBins: 1)

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

            try await cueScheduler.requestAuthorizationIfNeeded()
            cueScheduler.replaceScheduledCues(for: windows, cuesPerWindow: 5, spacingSeconds: 120)

            await MainActor.run {
                self.lastCurve = curve
                self.nextWindows = windows
                self.lastUpdatedAt = .now
                self.statusText = "Updated"
            }

        } catch {
            await MainActor.run {
                self.statusText = "Update failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Sleep Session Flow

    /// Whether calibration is missing or stale.
    var needsCalibration: Bool {
        guard let cal = calibration else { return true }
        return cal.needsRecalibration
    }

    /// Begin the sleep session flow. Returns the phase to present.
    func beginSleepFlow() throws {
        if needsCalibration {
            sleepPhase = .calibrating
        } else {
            try startTraining()
        }
    }

    /// Called after CalibrationView finishes. Starts training automatically.
    func calibrationCompleted() throws {
        try startTraining()
    }

    /// Start the training phase: setup audio, create session, begin cues.
    private func startTraining() throws {
        guard let cal = calibration else { return }

        try cuePlayer.setup()
        try cuePlayer.startBackgroundKeepalive()

        let training = PreSleepTrainingSession(player: cuePlayer, calibration: cal)
        training.onTriggerWatchHaptic = {
            PhoneWatchSync.shared.send(["command": PhoneWatchSync.playHaptic])
        }
        self.trainingSession = training
        training.start()
        sleepPhase = .training
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Called when training completes. Transitions to night monitoring.
    func trainingCompleted() {
        trainingSession = nil
        startNightMonitoring()
    }

    /// Start overnight REM cue monitoring.
    private func startNightMonitoring() {
        guard let cal = calibration else { return }
        let scheduler = REMCueScheduler(player: cuePlayer, calibration: cal)
        scheduler.onTriggerWatchHaptic = {
            PhoneWatchSync.shared.send(["command": PhoneWatchSync.playHaptic])
        }
        self.remScheduler = scheduler
        PhoneWatchSync.shared.remCueScheduler = scheduler
        scheduler.startNight()
        sleepPhase = .monitoring
        statusText = "Monitoring sleep"
    }

    /// End the sleep session and return the night log.
    @discardableResult
    func endSleepSession() -> [REMCueScheduler.CueEvent] {
        let nightLog = remScheduler?.nightLog ?? []
        remScheduler?.stopNight()
        remScheduler = nil
        PhoneWatchSync.shared.remCueScheduler = nil
        trainingSession = nil
        cuePlayer.stopBackgroundKeepalive()
        cuePlayer.teardown()
        sleepPhase = .idle
        statusText = "Idle"
        UIApplication.shared.isIdleTimerDisabled = false
        return nightLog
    }

    // MARK: - Private

    private func inferExpectedSleepStart(storedNights: [SleepNight], fallbackNow: Date) -> Date {
        let recent = storedNights.prefix(14)
        guard !recent.isEmpty else { return fallbackNow }

        let minutes = recent
            .map { DateUtils.minutesSinceMidnight($0.sleepStart) }
            .sorted()

        let median = minutes[minutes.count / 2]

        var candidate = DateUtils.todayAt(minutesSinceMidnight: median, now: fallbackNow)

        if candidate <= fallbackNow {
            candidate = Calendar.current.date(byAdding: .day, value: 1, to: candidate)!
        }

        return candidate
    }
}
