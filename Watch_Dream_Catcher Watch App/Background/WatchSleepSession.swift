//  WatchSleepSession.swift
//  Watch_Dream_Catcher Watch App
//
//  Manages WKExtendedRuntimeSession (physical-therapy mode) for background
//  haptic delivery during sleep.
//
//  Physical-therapy sessions:
//    - Run in the background (like alarm sessions)
//    - Use start(), not start(at:)
//    - Last up to 1 hour (vs 30 min for alarm)
//    - Do NOT require notifyUser() — no system alarm alert
//    - Haptics are delivered via WKInterfaceDevice.play()

import Observation
import WatchKit

@Observable
final class WatchSleepSession: NSObject {

    static let shared = WatchSleepSession()

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
                (.expired, .expired):
                return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    enum SessionControlSource {
        case localWatch
        case remotePhone
        case `internal`
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

    var isSessionRequested: Bool {
        sleepSessionRequested
    }

    var isBusyStarting: Bool {
        isStarting || pendingRenewal || pendingStop
    }

    // MARK: - Private

    private var session: WKExtendedRuntimeSession?
    private let renewalLeadTime: TimeInterval = 10
    private var manuallyStarted = false
    private var sleepSessionRequested = false

    private var isStarting = false

    private var pendingRenewal = false
    private var pendingStop = false

    private let postInvalidateCooldown: TimeInterval = 1.2
    private let minInterStartSpacing: TimeInterval = 1.8
    private var lastStartRequestAt: Date?
    private var lastInvalidationAt: Date?

    private func ensureMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }

    // MARK: - Start

    func start(source: SessionControlSource = .internal) {
        ensureMain {
            guard self.state == .inactive || self.state == .expired else {
                return
            }
            guard !self.pendingStop, !self.pendingRenewal else { return }
            guard !self.isBusyStarting, self.session == nil else { return }

            if source == .localWatch {
                WatchSessionManager.shared.sendStartSleepSessionToPhone()
            }
            self.manuallyStarted = true
            self.sleepSessionRequested = true
            WatchSessionManager.shared.publishSleepSessionState(isActive: true)
            self.startSession()
        }
    }

    func autoStartIfAppropriate() {
        ensureMain {
            guard self.state == .inactive || self.state == .expired else {
                return
            }
            guard self.isSleepFocusActive || self.sleepSessionRequested else {
                return
            }
            guard !self.pendingStop, !self.pendingRenewal else { return }
            guard !self.isBusyStarting, self.session == nil else { return }

            self.manuallyStarted = false
            self.sleepSessionRequested = true
            WatchSessionManager.shared.publishSleepSessionState(isActive: true)
            self.startSession()
        }
    }

    func stop(source: SessionControlSource = .internal) {
        ensureMain {
            if source == .localWatch {
                WatchSessionManager.shared.sendStopSleepSessionToPhone()
            }
            self.sleepSessionRequested = false
            self.manuallyStarted = false
            WatchSessionManager.shared.publishSleepSessionState(isActive: false)

            guard let s = self.session else {
                self.finishStopped()
                return
            }

            self.pendingStop = true
            s.invalidate()
        }
    }

    private func finishStopped() {
        isStarting = false
        pendingRenewal = false
        pendingStop = false

        session = nil
        state = .inactive
        sessionStartTime = nil
        sessionsRenewed = 0
        WatchCueScheduler.shared.hasLiveSession = false
        WatchSessionManager.shared.publishSleepSessionState(isActive: false)
    }

    // MARK: - Internal

    private func canIssueNewStartNow() -> Bool {
        if let t = lastStartRequestAt,
            Date().timeIntervalSince(t) < minInterStartSpacing
        {
            return false
        }
        if let t = lastInvalidationAt,
            Date().timeIntervalSince(t) < postInvalidateCooldown
        {
            return false
        }
        return true
    }

    private func startSession() {
        guard !isStarting else { return }
        guard canIssueNewStartNow() else { return }
        guard session == nil else { return }
        guard state == .inactive || state == .expired else { return }
        guard !pendingStop, !pendingRenewal else { return }

        isStarting = true
        lastStartRequestAt = Date()

        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        self.session = newSession
        newSession.start()

        WatchCueScheduler.shared.hasLiveSession = false
    }

    // MARK: - Renewal

    private func renewSession() {
        guard sleepSessionRequested else {
            state = .expired
            WatchCueScheduler.shared.hasLiveSession = false
            return
        }
        guard !pendingStop else { return }

        guard let s = session else {
            state = .renewing
            isStarting = false
            pendingRenewal = true
            DispatchQueue.main.asyncAfter(
                deadline: .now() + postInvalidateCooldown
            ) { [weak self] in
                self?.attemptStartAfterInvalidationIfPending()
            }
            return
        }

        state = .renewing
        pendingRenewal = true

        s.invalidate()
    }

    private func attemptStartAfterInvalidationIfPending() {
        guard pendingRenewal, sleepSessionRequested else { return }
        guard !pendingStop else { return }
        guard canIssueNewStartNow() else {
            let delay: TimeInterval = minInterStartSpacing
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                [weak self] in
                self?.attemptStartAfterInvalidationIfPending()
            }
            return
        }
        guard session == nil, !isStarting else { return }

        isStarting = true
        lastStartRequestAt = Date()

        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        self.session = newSession
        newSession.start()

        sessionsRenewed += 1
        WatchCueScheduler.shared.hasLiveSession = false
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension WatchSleepSession: WKExtendedRuntimeSessionDelegate {

    func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        ensureMain {
            guard extendedRuntimeSession === self.session else { return }
            self.state = .active
            WatchCueScheduler.shared.hasLiveSession = true
            self.isStarting = false
            self.pendingRenewal = false
            if self.sessionStartTime == nil {
                self.sessionStartTime = Date()
            }
            if self.pendingStop {
                extendedRuntimeSession.invalidate()
            }
        }
    }

    func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        ensureMain {
            guard extendedRuntimeSession === self.session else { return }
            self.state = .expiringSoon
            DispatchQueue.main.asyncAfter(
                deadline: .now() + self.renewalLeadTime
            ) {
                [weak self] in self?.renewSession()
            }
        }
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        ensureMain {
            self.lastInvalidationAt = Date()

            if self.session == nil || extendedRuntimeSession === self.session {
                if extendedRuntimeSession === self.session {
                    self.session?.delegate = nil
                    self.session = nil
                }

                switch reason {
                case .expired:
                    if self.pendingStop {
                        self.finishStopped()
                    } else if self.pendingRenewal {
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + self.postInvalidateCooldown
                        ) {
                            [weak self] in
                            self?.attemptStartAfterInvalidationIfPending()
                        }
                    } else {
                        self.state = .expired
                        self.isStarting = false
                        WatchCueScheduler.shared.hasLiveSession = false
                    }

                case .sessionInProgress:
                    self.isStarting = false

                case .error:
                    self.state = .error(
                        error?.localizedDescription ?? "Unknown error"
                    )
                    self.isStarting = false
                    self.pendingRenewal = false
                    self.pendingStop = false
                    WatchCueScheduler.shared.hasLiveSession = false

                case .none:
                    if self.pendingStop {
                        self.finishStopped()
                    } else if self.pendingRenewal {
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + self.postInvalidateCooldown
                        ) {
                            [weak self] in
                            self?.attemptStartAfterInvalidationIfPending()
                        }
                    } else if self.state != .renewing {
                        self.state = .inactive
                        self.isStarting = false
                        WatchCueScheduler.shared.hasLiveSession = false
                    }

                default:
                    self.state = .expired
                    self.isStarting = false
                    self.pendingRenewal = false
                    self.pendingStop = false
                    WatchCueScheduler.shared.hasLiveSession = false
                }
            }
        }
    }
}
