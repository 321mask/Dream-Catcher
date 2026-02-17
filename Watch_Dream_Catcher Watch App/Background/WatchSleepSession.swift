//  WatchSleepSession.swift
//  Watch_Dream_Catcher Watch App
//
//  Manages WKExtendedRuntimeSession for background haptic delivery during sleep.
//
//  WHY WKExtendedRuntimeSession (.smartAlarm), NOT HKWorkoutSession:
//    HKWorkoutSession:
//      - Logs a "workout" to Health -> corrupts Activity Rings
//      - Shows persistent workout indicator on Watch face
//      - Apple increasingly rejects sleep apps abusing workout sessions
//    WKExtendedRuntimeSession (.smartAlarm):
//      - Designed for sleep apps that deliver cues at calculated times
//      - No workout artifacts, no Activity Ring pollution
//      - Grants ~30 min of background runtime per session
//      - Can be renewed: start a new session when one expires
//
//  SLEEP FOCUS INTEGRATION:
//    iPhone sends "sleepFocusOn" / "sleepFocusOff" via WCSession.
//    When isSleepFocusActive flips to true and the Watch app is foregrounded,
//    the session auto-starts. When Sleep Focus turns off (morning),
//    the session auto-stops (unless the user manually started it).

import WatchKit
import Observation

@Observable
final class WatchSleepSession: NSObject {

    // MARK: - State

    enum SessionState: Equatable {
        case inactive
        case active
        case expiringSoon
        case renewing
        case expired
        case error(String)

        static func == (lhs: SessionState, rhs: SessionState) -> Bool {
            switch (lhs, rhs) {
            case (.inactive, .inactive),
                 (.active, .active),
                 (.expiringSoon, .expiringSoon),
                 (.renewing, .renewing),
                 (.expired, .expired): return true
            case let (.error(a), .error(b)): return a == b
            default: return false
            }
        }
    }

    private(set) var state: SessionState = .inactive
    private(set) var sessionStartTime: Date?
    private(set) var sessionsRenewed: Int = 0

    /// Updated by iPhone via WCSession ("sleepFocusOn" / "sleepFocusOff").
    var isSleepFocusActive: Bool = false {
        didSet {
            if isSleepFocusActive && !oldValue {
                autoStartIfAppropriate()
            } else if !isSleepFocusActive && oldValue && !manuallyStarted {
                stop()
            }
        }
    }

    var isLive: Bool {
        state == .active || state == .expiringSoon
    }

    // MARK: - Private

    private var session: WKExtendedRuntimeSession?
    private let renewalLeadTime: TimeInterval = 10
    private var manuallyStarted = false
    private var sleepSessionRequested = false

    // MARK: - Start

    func start() {
        manuallyStarted = true
        sleepSessionRequested = true
        startSession()
    }

    func autoStartIfAppropriate() {
        guard state == .inactive || state == .expired else { return }
        guard isSleepFocusActive || sleepSessionRequested else { return }

        manuallyStarted = false
        sleepSessionRequested = true
        startSession()
    }

    func stop() {
        sleepSessionRequested = false
        manuallyStarted = false
        session?.invalidate()
        session = nil
        state = .inactive
        sessionStartTime = nil
        sessionsRenewed = 0
        WatchCueScheduler.shared.hasLiveSession = false
    }

    // MARK: - Internal

    private func startSession() {
        guard session == nil || state == .inactive || state == .expired else {
            return
        }

        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        self.session = newSession
        newSession.start()

        state = .active
        sessionStartTime = sessionStartTime ?? Date()
        WatchCueScheduler.shared.hasLiveSession = true
    }

    // MARK: - Renewal

    private func renewSession() {
        guard sleepSessionRequested else {
            state = .expired
            WatchCueScheduler.shared.hasLiveSession = false
            return
        }

        state = .renewing
        session?.invalidate()
        session = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.sleepSessionRequested else { return }

            let newSession = WKExtendedRuntimeSession()
            newSession.delegate = self
            self.session = newSession
            newSession.start()

            self.sessionsRenewed += 1
            self.state = .active
            WatchCueScheduler.shared.hasLiveSession = true
        }
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension WatchSleepSession: WKExtendedRuntimeSessionDelegate {

    func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        state = .active
        WatchCueScheduler.shared.hasLiveSession = true
    }

    func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        state = .expiringSoon
        DispatchQueue.main.asyncAfter(deadline: .now() + renewalLeadTime) {
            [weak self] in self?.renewSession()
        }
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        switch reason {
        case .expired:
            if state != .renewing { renewSession() }
        case .sessionInProgress:
            state = .error("Another session is already running")
            WatchCueScheduler.shared.hasLiveSession = false
        case .error:
            state = .error(error?.localizedDescription ?? "Unknown error")
            WatchCueScheduler.shared.hasLiveSession = false
        case .none:
            if state != .renewing {
                state = .inactive
                WatchCueScheduler.shared.hasLiveSession = false
            }
        @unknown default:
            state = .expired
            WatchCueScheduler.shared.hasLiveSession = false
        }
    }
}
