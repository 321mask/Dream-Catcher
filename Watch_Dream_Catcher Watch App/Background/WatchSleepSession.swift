//  WatchSleepSession.swift
//  Watch_Dream_Catcher Watch App
//
//  Manages WKExtendedRuntimeSession for background haptic delivery during sleep.

import WatchKit
import Observation

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
                 (.expired, .expired): return true
            case let (.error(a), .error(b)): return a == b
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

    // Expose a consolidated "busy" flag to gate UI and WC starts
    var isBusyStarting: Bool {
        isStarting || isScheduled || pendingRenewal || pendingStop
    }

    // MARK: - Private

    private var session: WKExtendedRuntimeSession?
    private let renewalLeadTime: TimeInterval = 10
    private var manuallyStarted = false
    private var sleepSessionRequested = false

    // Strict guards for scheduling/starting
    private var isStarting = false
    private var isScheduled = false

    // Flow coordination
    private var pendingRenewal = false
    private var pendingStop = false

    // Cooldowns to avoid overlapping scheduled starts/invalidation races
    private let postInvalidateCooldown: TimeInterval = 1.2
    private let minInterStartSpacing: TimeInterval = 1.8
    private var lastStartRequestAt: Date?
    private var lastInvalidationAt: Date?

    // Smart alarm sessions are schedulable and must use start(at:), not start().
    private let scheduledAlarmStartLeadTime: TimeInterval = 2
    private let usesSchedulableAlarmRuntime: Bool = {
        let modes = (Bundle.main.object(forInfoDictionaryKey: "WKBackgroundModes") as? [String]) ?? []
        return modes.contains { $0.caseInsensitiveCompare("alarm") == .orderedSame }
    }()

    // Ensure main-thread mutations
    private func ensureMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() }
        else { DispatchQueue.main.async { block() } }
    }

    // MARK: - Start

    func start(source: SessionControlSource = .internal) {
        ensureMain {
            // Only allow explicit user start from inactive/expired
            guard self.state == .inactive || self.state == .expired else { return }
            // Don’t start while any stop/renewal is pending
            guard !self.pendingStop, !self.pendingRenewal else { return }
            // Don’t re-enter while internal start/schedule is in flight.
            guard !self.isBusyStarting, self.session == nil else { return }

            if source == .localWatch {
                WatchSessionManager.shared.sendStartSleepSessionToPhone()
            }
            self.manuallyStarted = true
            self.sleepSessionRequested = true
            self.startSession()
        }
    }

    func autoStartIfAppropriate() {
        ensureMain {
            // Only auto-start from inactive/expired, not during renewal or active.
            guard self.state == .inactive || self.state == .expired else { return }
            guard self.isSleepFocusActive || self.sleepSessionRequested else { return }
            // Don’t auto-start while any stop/renewal is pending
            guard !self.pendingStop, !self.pendingRenewal else { return }
            // Don’t re-enter while internal start/schedule is in flight.
            guard !self.isBusyStarting, self.session == nil else { return }

            self.manuallyStarted = false
            self.sleepSessionRequested = true
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

            // If there's no session object, just reset state.
            guard let s = self.session else {
                self.finishStopped()
                return
            }

            // Mark stop pending and invalidate. Do NOT nil out session here.
            self.pendingStop = true
            s.invalidate()
        }
    }

    private func finishStopped() {
        isStarting = false
        isScheduled = false
        pendingRenewal = false
        pendingStop = false

        session = nil
        state = .inactive
        sessionStartTime = nil
        sessionsRenewed = 0
        WatchCueScheduler.shared.hasLiveSession = false
    }

    // MARK: - Internal

    private func canIssueNewStartNow() -> Bool {
        if let t = lastStartRequestAt, Date().timeIntervalSince(t) < minInterStartSpacing {
            return false
        }
        if let t = lastInvalidationAt, Date().timeIntervalSince(t) < postInvalidateCooldown {
            return false
        }
        return true
    }

    private func startSession() {
        // Prevent any overlapping starts when already starting or scheduled.
        guard !isStarting, !isScheduled else { return }
        // Respect cooldowns between starts/invalidation.
        guard canIssueNewStartNow() else { return }
        // If any current session object exists, don't create another one.
        guard session == nil else { return }
        // Only create/start when state is appropriate.
        guard state == .inactive || state == .expired else { return }
        // Don’t start if a stop/renewal is pending
        guard !pendingStop, !pendingRenewal else { return }

        isStarting = true
        isScheduled = true
        lastStartRequestAt = Date()

        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        self.session = newSession
        startRuntime(newSession)

        // Do not optimistically set .active; wait for delegate confirmation.
        WatchCueScheduler.shared.hasLiveSession = false
    }

    // MARK: - Renewal

    private func renewSession() {
        // If the user canceled between expiry and renewal, mark expired.
        guard sleepSessionRequested else {
            state = .expired
            WatchCueScheduler.shared.hasLiveSession = false
            return
        }
        // Don’t renew if a stop is pending
        guard !pendingStop else { return }

        // If there's no live session object, try a fresh start after cooldown.
        guard let s = session else {
            state = .renewing
            isStarting = false
            isScheduled = false
            pendingRenewal = true
            // Enforce cooldown before attempting to start.
            DispatchQueue.main.asyncAfter(deadline: .now() + postInvalidateCooldown) { [weak self] in
                self?.attemptStartAfterInvalidationIfPending()
            }
            return
        }

        // Normal renewal path: invalidate then start again after invalidation.
        state = .renewing
        isStarting = true
        isScheduled = false
        pendingRenewal = true

        // Do NOT nil out session here; wait for didInvalidate.
        s.invalidate()
    }

    private func attemptStartAfterInvalidationIfPending() {
        // Called after didInvalidate or cooldown, only if renewal is pending and still requested.
        guard pendingRenewal, sleepSessionRequested else { return }
        // Don’t start if a stop is pending
        guard !pendingStop else { return }
        // Respect cooldowns
        guard canIssueNewStartNow() else {
            // Try once more when cooldown likely ends
            let delay: TimeInterval = minInterStartSpacing
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.attemptStartAfterInvalidationIfPending()
            }
            return
        }
        // Don’t double-start if something already exists/scheduled.
        guard session == nil, !isScheduled, !isStarting else { return }

        isStarting = true
        isScheduled = true
        lastStartRequestAt = Date()

        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        self.session = newSession
        startRuntime(newSession)

        sessionsRenewed += 1
        WatchCueScheduler.shared.hasLiveSession = false
        // Wait for didStart to set .active and clear flags.
    }

    private func startRuntime(_ runtime: WKExtendedRuntimeSession) {
        // Schedulable alarm sessions reject start() with SessionErrorDomain Code=17.
        if usesSchedulableAlarmRuntime {
            runtime.start(at: Date().addingTimeInterval(scheduledAlarmStartLeadTime))
        } else {
            runtime.start()
        }
    }

    // Called by WKApplicationDelegate when the system relaunches the app
    // for a previously-scheduled alarm session (or crash recovery).
    func handleSystemSession(_ session: WKExtendedRuntimeSession) {
        ensureMain {
            // If we already have a live session, ignore the handed-back one.
            guard self.session == nil else {
                session.invalidate()
                return
            }
            session.delegate = self
            self.session = session
            self.sleepSessionRequested = true
            self.pendingRenewal = false

            if session.state == .running {
                self.state = .active
                self.isStarting = false
                self.isScheduled = false
                if self.sessionStartTime == nil {
                    self.sessionStartTime = Date()
                }
                WatchCueScheduler.shared.hasLiveSession = true
            } else {
                // If the system hands us a scheduled session, wait for didStart.
                self.state = .inactive
                self.isStarting = true
                self.isScheduled = true
                WatchCueScheduler.shared.hasLiveSession = false
            }
        }
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
            self.isScheduled = false
            self.pendingRenewal = false
            if self.sessionStartTime == nil {
                self.sessionStartTime = Date()
            }
            // If a stop was requested while starting, immediately invalidate.
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
            DispatchQueue.main.asyncAfter(deadline: .now() + self.renewalLeadTime) {
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
            // Record invalidation time for cooldown gating.
            self.lastInvalidationAt = Date()

            // Only react if this is the tracked session or we have none.
            if self.session == nil || extendedRuntimeSession === self.session {
                // Now it is safe to release the session object.
                if extendedRuntimeSession === self.session {
                    self.session?.delegate = nil
                    self.session = nil
                }

                switch reason {
                case .expired:
                    if self.pendingStop {
                        self.finishStopped()
                    } else if self.pendingRenewal {
                        // Start new after a short cooldown.
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.postInvalidateCooldown) {
                            [weak self] in self?.attemptStartAfterInvalidationIfPending()
                        }
                    } else {
                        // Expired without renewal intent.
                        self.state = .expired
                        self.isStarting = false
                        self.isScheduled = false
                        WatchCueScheduler.shared.hasLiveSession = false
                    }

                case .sessionInProgress:
                    // Another session is already running/scheduled; wait for its callbacks.
                    self.isStarting = false
                    // Keep isScheduled conservative; do not reissue start immediately.

                case .error:
                    self.state = .error(error?.localizedDescription ?? "Unknown error")
                    self.isStarting = false
                    self.isScheduled = false
                    self.pendingRenewal = false
                    self.pendingStop = false
                    WatchCueScheduler.shared.hasLiveSession = false

                case .none:
                    if self.pendingStop {
                        self.finishStopped()
                    } else if self.pendingRenewal {
                        // Start new after a short cooldown.
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.postInvalidateCooldown) {
                            [weak self] in self?.attemptStartAfterInvalidationIfPending()
                        }
                    } else if self.state != .renewing {
                        self.state = .inactive
                        self.isStarting = false
                        self.isScheduled = false
                        WatchCueScheduler.shared.hasLiveSession = false
                    }

                @unknown default:
                    self.state = .expired
                    self.isStarting = false
                    self.isScheduled = false
                    self.pendingRenewal = false
                    self.pendingStop = false
                    WatchCueScheduler.shared.hasLiveSession = false
                }
            }
        }
    }
}
