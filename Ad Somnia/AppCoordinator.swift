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
import HealthKit

@Observable
final class AppCoordinator {
    var statusText: String = "Idle"
    var lastUpdatedAt: Date?
    var nextWindows: [DateInterval] = []
    var lastCurve: [Double] = []
    var watchCuesDeliveredTonight: Int = 0

    // MARK: - Sleep Session State

    enum SleepPhase: Equatable {
        case idle
        case calibrating
        case training
        case monitoring
    }

    enum SleepControlSource {
        case local
        case remoteWatch
    }

    var sleepPhase: SleepPhase = .idle {
        didSet {
            guard (sleepPhase != .idle) != (oldValue != .idle) else { return }
            PhoneWatchSync.shared.publishSleepSessionState(isActive: isSleepSessionOngoing)
        }
    }

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
    let cuePlayer = LucidCuePlayer()
    let sleepFocusObserver = SleepFocusObserver()

    private var isNightlyUpdateRunning = false

    init() {}

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
        guard !isNightlyUpdateRunning else { return }
        isNightlyUpdateRunning = true
        defer { isNightlyUpdateRunning = false }

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

            await MainActor.run {
                self.lastCurve = curve
                self.nextWindows = windows
                self.lastUpdatedAt = .now
                self.statusText = "Updated"
            }

        } catch {
            await MainActor.run {
                self.statusText = self.nightlyUpdateErrorMessage(for: error)
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
    func beginSleepFlow(source: SleepControlSource = .local) throws {
        guard sleepPhase == .idle else { return }
        watchCuesDeliveredTonight = 0

        if source == .local {
            PhoneWatchSync.shared.sendStartSleepSession()
            scheduleKnownWindowsForActiveSession()
        }

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
    func endSleepSession(source: SleepControlSource = .local) -> [REMCueScheduler.CueEvent] {
        guard sleepPhase != .idle else { return [] }

        if source == .local {
            PhoneWatchSync.shared.sendStopSleepSession()
        }

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
        watchCuesDeliveredTonight = 0
        return nightLog
    }

    // MARK: - Private

    private func scheduleKnownWindowsForActiveSession() {
        guard !nextWindows.isEmpty else { return }

        PhoneWatchSync.shared.sendRemWindowsToWatch(
            windows: nextWindows,
            cuesPerWindow: 5,
            spacingSeconds: 120
        )
    }

    private func nightlyUpdateErrorMessage(for error: Error) -> String {
        if let hkError = error as? HealthKitClientError {
            switch hkError {
            case .healthDataUnavailable:
                return "Update failed: Health data is unavailable on this device."
            case .authorizationDenied:
                return "Update failed: Sleep permission denied. Please allow Health access and try again."
            case .authorizationNotDetermined:
                return "Update failed: Health authorization not determined. Please try again to grant access."
            }
        }

        let nsError = error as NSError
        if nsError.domain == HKErrorDomain,
           nsError.code == HKError.errorAuthorizationDenied.rawValue {
            return "Update failed: Sleep permission denied. Please allow Health access and try again."
        }

        if nsError.localizedDescription == "Authorization not determined." {
            return "Update failed: Health authorization not determined. Please try again to grant access."
        }

        return "Update failed: \(error.localizedDescription)"
    }

    private func inferExpectedSleepStart(storedNights: [SleepNight], fallbackNow: Date) -> Date {
        let recent = storedNights.prefix(14)
        guard !recent.isEmpty else { return fallbackNow }

        let minutes = recent
            .map { DateUtils.minutesSinceMidnight($0.sleepStart) }
            .sorted()

        let median = minutes[minutes.count / 2]
        let calendar = Calendar.current
        let todayCandidate = DateUtils.todayAt(minutesSinceMidnight: median, now: fallbackNow)

        guard
            let yesterdayCandidate = calendar.date(byAdding: .day, value: -1, to: todayCandidate),
            let tomorrowCandidate = calendar.date(byAdding: .day, value: 1, to: todayCandidate)
        else {
            return todayCandidate
        }

        let candidates = [yesterdayCandidate, todayCandidate, tomorrowCandidate]
        return candidates.min(by: { abs($0.timeIntervalSince(fallbackNow)) < abs($1.timeIntervalSince(fallbackNow)) }) ?? todayCandidate
    }
}

extension AppCoordinator: PhoneSleepSessionControlling {
    var isSleepSessionOngoing: Bool {
        sleepPhase != .idle
    }

    func handleWatchRequestedSleepStart() {
        applyRemoteWatchSleepStart()
    }

    func handleWatchRequestedSleepStop() {
        _ = endSleepSession(source: .remoteWatch)
    }

    func applyWatchSessionState(isActive: Bool) {
        if isActive {
            applyRemoteWatchSleepStart()
        } else if sleepPhase != .idle {
            _ = endSleepSession(source: .remoteWatch)
        }
    }

    private func applyRemoteWatchSleepStart() {
        guard sleepPhase == .idle else { return }

        watchCuesDeliveredTonight = 0

        if calibration != nil {
            startNightMonitoring()
        } else {
            sleepPhase = .monitoring
            statusText = "Monitoring sleep (watch session)"
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    func handleWatchCueDelivered() {
        watchCuesDeliveredTonight += 1
    }
}
