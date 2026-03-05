//  WatchCueScheduler.swift
//  Watch_Dream_Catcher Watch App
//
//  Delivers haptic cues via WKExtendedRuntimeSession (smart alarm).
//
//  Smart alarm sessions run in the background. The ONLY way to play
//  haptics from a background alarm session is:
//    session.notifyUser(hapticType:repeatHandler:)
//
//  WKInterfaceDevice.play() is silently ignored in the background,
//  so it is NOT used for cue delivery.
//
//  Flow:
//    - Cue fire dates are stored in scheduledFireDates.
//    - When hasLiveSession becomes true, DispatchWorkItems are scheduled
//      on the main queue for each fire date.
//    - Each DispatchWorkItem calls deliverCue() which triggers
//      session.notifyUser() on the live WKExtendedRuntimeSession.
//    - The repeatHandler plays a short ascending pattern, then stops.

import Foundation
import WatchKit
import Observation

@Observable
final class WatchCueScheduler {

    static let shared = WatchCueScheduler()

    // MARK: - Session State

    var hasLiveSession = false {
        didSet {
            if hasLiveSession && !oldValue {
                if !scheduledFireDates.isEmpty {
                    startDirectDelivery(fireDates: scheduledFireDates)
                }
            } else if !hasLiveSession && oldValue {
                stopDirectDelivery()
            }
        }
    }

    private(set) var isDeliveringDirectly = false
    private(set) var cuesDelivered: Int = 0

    // MARK: - Pause State

    private var isPaused = false
    private var pauseResumeWork: DispatchWorkItem?

    // MARK: - Scheduled Cues

    private(set) var scheduledFireDates: [Date] = []
    private var directDispatchItems: [DispatchWorkItem] = []

    /// Number of haptic taps per cue delivery (the ascending three-tap pattern).
    private let tapsPerCue = 3

    // MARK: - Init

    private init() {}

    // MARK: - Main API

    func replaceScheduledCues(
        for windows: [DateInterval],
        cuesPerWindow: Int,
        spacingSeconds: TimeInterval
    ) {
        var dates: [Date] = []
        for window in windows {
            for i in 0..<cuesPerWindow {
                let date = window.start.addingTimeInterval(TimeInterval(i) * spacingSeconds)
                guard date < window.end, date > Date().addingTimeInterval(2) else { continue }
                dates.append(date)
            }
        }
        dates.sort()
        scheduledFireDates = dates

        if hasLiveSession {
            startDirectDelivery(fireDates: dates)
        }
    }

    // MARK: - Test Cues

    /// Schedule test cues at the given offsets (in seconds) from now.
    func scheduleTestCues(offsets: [TimeInterval]) {
        let sanitized = offsets
            .map { max(1.0, $0) }
            .sorted()

        guard !sanitized.isEmpty else { return }

        isPaused = false
        pauseResumeWork?.cancel()

        let now = Date()
        let dates = sanitized.map { now.addingTimeInterval($0) }
        scheduledFireDates = dates

        if hasLiveSession {
            startDirectDelivery(fireDates: dates)
        }
    }

    // MARK: - Direct Delivery

    private func startDirectDelivery(fireDates: [Date]) {
        stopDirectDelivery()
        isDeliveringDirectly = true

        for date in fireDates {
            let delay = date.timeIntervalSinceNow
            guard delay > 0 else { continue }

            let item = DispatchWorkItem { [weak self] in
                guard let self, self.isDeliveringDirectly, !self.isPaused else { return }
                self.deliverCue()
            }
            directDispatchItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    private func stopDirectDelivery() {
        isDeliveringDirectly = false
        for item in directDispatchItems { item.cancel() }
        directDispatchItems.removeAll()
    }

    // MARK: - Cue Delivery via notifyUser

    private func deliverCue() {
        let session = WatchSleepSession.shared
        guard session.isLive, let runtimeSession = session.currentSession else {
            // Foreground-only fallback — will be silent in background
            WKInterfaceDevice.current().play(.notification)
            return
        }

        // Use notifyUser for background-capable haptics.
        // Play tapsPerCue taps with a short interval, then return 0 to stop.
        var remaining = tapsPerCue

        // Haptic types for ascending pattern: click -> directionUp -> notification
        let hapticSequence: [WKHapticType] = [.click, .directionUp, .notification]

        runtimeSession.notifyUser(hapticType: hapticSequence[0]) { outHapticType in
            remaining -= 1
            if remaining <= 0 {
                return 0
            }
            let index = self.tapsPerCue - remaining
            if index < hapticSequence.count {
                outHapticType.pointee = hapticSequence[index]
            }
            // 225ms between taps to match the audio cue rhythm
            return 0.225
        }

        cuesDelivered += 1
        WatchSessionManager.shared.notifyCueDeliveredToPhone()
    }

    // MARK: - Motion-Aware Pause

    func pauseForMotion(duration: TimeInterval = 5 * 60) {
        isPaused = true
        pauseResumeWork?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.isPaused = false
        }
        pauseResumeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func pauseForAwakening(duration: TimeInterval = 45 * 60) {
        pauseForMotion(duration: duration)
    }

    // MARK: - Cleanup

    func removeAllScheduledCues() {
        stopDirectDelivery()
        scheduledFireDates.removeAll()
        cuesDelivered = 0
        isPaused = false
        pauseResumeWork?.cancel()
    }
}
