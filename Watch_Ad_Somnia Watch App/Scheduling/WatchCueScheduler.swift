//  WatchCueScheduler.swift
//  Watch_Dream_Catcher Watch App
//
//  Delivers haptic cues while the watch app is alive in the background.
//
//  Haptics are played via WKInterfaceDevice.play(), which works while
//  WatchSleepSession's AVAudioSession is active (audio background mode).
//
//  Design: a single repeating poll Timer asks every few seconds whether
//  any scheduled cue is due. This is resilient to state churn, audio
//  interruptions, and the watchOS scheduler deferring long one-shot
//  timers — much more reliable than per-cue DispatchWorkItems for
//  delays measured in tens of minutes or hours.

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
                lastDeliveredAt = nil
                firedDates.removeAll()
                startPolling()
            } else if !hasLiveSession && oldValue {
                stopPolling()
            }
        }
    }

    private(set) var cuesDelivered: Int = 0
    private(set) var lastDeliveredAt: Date?

    // MARK: - Pause State

    private var isPaused = false
    private var pauseResumeWork: DispatchWorkItem?

    // MARK: - Scheduled Cues

    private(set) var scheduledFireDates: [Date] = []
    private var firedDates: Set<Date> = []

    // MARK: - Polling

    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 5.0
    /// How late a cue can fire after its scheduled time before being skipped.
    /// Without this, a session that wakes up an hour late would dump every
    /// missed cue at once.
    private let cueExpiryWindow: TimeInterval = 60.0

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
        firedDates.removeAll()

        if hasLiveSession {
            startPolling()
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
        firedDates.removeAll()

        if hasLiveSession {
            startPolling()
        }
    }

    // MARK: - Polling

    private func startPolling() {
        stopPolling()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        // Let watchOS coalesce timer fires for better battery behavior.
        timer.tolerance = pollInterval / 2
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        // Fire once immediately for any cue that's already due.
        poll()
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        guard hasLiveSession else { return }
        let now = Date()

        for date in scheduledFireDates {
            guard !firedDates.contains(date) else { continue }
            let delta = now.timeIntervalSince(date)
            if delta < 0 { continue }              // not yet due
            if delta > cueExpiryWindow {           // missed window
                firedDates.insert(date)
                continue
            }
            firedDates.insert(date)
            guard !isPaused else { continue }
            deliverCue()
        }

        // Auto-stop: all cues fired and the last fire was over a minute ago.
        let hasUpcoming = scheduledFireDates.contains(where: { now < $0 })
        if !hasUpcoming, let last = lastDeliveredAt, now.timeIntervalSince(last) > 60 {
            WatchSleepSession.shared.stop(source: .internal)
        }
    }

    // MARK: - Cue Delivery via WKInterfaceDevice

    /// Ascending three-tap haptic pattern: click → directionUp → notification.
    /// Matches the TLR audio cue rhythm (225ms between taps).
    /// The user-chosen strength (0/1/2) controls how many times the
    /// pattern repeats (1×, 2×, 3×), not the haptic type.
    private func deliverCue() {
        let device = WKInterfaceDevice.current()
        let saved = UserDefaults.standard.integer(forKey: "hapticStrength")
        let repetitions = saved + 1  // 0→1, 1→2, 2→3

        let patternDuration: TimeInterval = 0.650  // 450ms last tap + ~200ms settle
        for rep in 0..<repetitions {
            let base = Double(rep) * patternDuration

            let tap1 = base
            let tap2 = base + 0.225
            let tap3 = base + 0.450

            if tap1 == 0 {
                device.play(.click)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + tap1) {
                    device.play(.click)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + tap2) {
                device.play(.directionUp)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + tap3) {
                device.play(.notification)
            }
        }

        cuesDelivered += 1
        lastDeliveredAt = Date()
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
        stopPolling()
        scheduledFireDates.removeAll()
        firedDates.removeAll()
        cuesDelivered = 0
        lastDeliveredAt = nil
        isPaused = false
        pauseResumeWork?.cancel()
    }
}
