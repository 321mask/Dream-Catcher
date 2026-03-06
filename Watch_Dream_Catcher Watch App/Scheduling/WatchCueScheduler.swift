//  WatchCueScheduler.swift
//  Watch_Dream_Catcher Watch App
//
//  Delivers haptic cues during an active WKExtendedRuntimeSession
//  (physical-therapy mode).
//
//  Haptics are played via WKInterfaceDevice.play(), which works in the
//  background during an active extended runtime session.
//
//  Flow:
//    - Cue fire dates are stored in scheduledFireDates.
//    - When hasLiveSession becomes true, DispatchWorkItems are scheduled
//      on the main queue for each fire date.
//    - Each DispatchWorkItem calls deliverCue() which plays a three-tap
//      ascending haptic pattern via WKInterfaceDevice.

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
                cuesDelivered = 0
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

    // MARK: - Cue Delivery via WKInterfaceDevice

    /// Ascending three-tap haptic pattern: click → directionUp → notification.
    /// Matches the iPhone audio cue rhythm (225ms between taps).
    private func deliverCue() {
        let device = WKInterfaceDevice.current()

        // Tap 1: light click (immediate)
        device.play(.click)

        // Tap 2: medium at 225ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
            device.play(.directionUp)
        }

        // Tap 3: strong at 450ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.450) {
            device.play(.notification)
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
