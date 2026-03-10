//
//  WatchSleepSession.swift
//  Watch_Dream_Catcher Watch App
//
//  Manages an HKWorkoutSession to keep the watch app alive while haptic
//  cues are delivered during sleep.
//

import HealthKit
import Observation

@Observable
final class WatchSleepSession: NSObject {

    static let shared = WatchSleepSession()

    enum SessionState: Equatable {
        case inactive
        case active
        case error(String)

        static func == (lhs: SessionState, rhs: SessionState) -> Bool {
            switch (lhs, rhs) {
            case (.inactive, .inactive), (.active, .active):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
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
        state == .active
    }

    var isSessionRequested: Bool {
        sleepSessionRequested
    }

    var isBusyStarting: Bool {
        isStarting || isAuthorizing
    }

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var manuallyStarted = false
    private var sleepSessionRequested = false
    private var isStarting = false
    private var isAuthorizing = false
    private var isStopping = false

    private func ensureMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }

    func start(source: SessionControlSource = .internal) {
        ensureMain {
            guard !self.isLive, !self.isBusyStarting else { return }

            if source == .localWatch {
                WatchSessionManager.shared.sendStartSleepSessionToPhone()
            }

            self.manuallyStarted = true
            self.sleepSessionRequested = true
            WatchSessionManager.shared.publishSleepSessionState(isActive: true)
            self.startWorkoutSessionIfNeeded()
        }
    }

    func autoStartIfAppropriate() {
        ensureMain {
            guard !self.isLive, !self.isBusyStarting else { return }
            guard self.isSleepFocusActive || self.sleepSessionRequested else { return }

            self.manuallyStarted = false
            self.sleepSessionRequested = true
            WatchSessionManager.shared.publishSleepSessionState(isActive: true)
            self.startWorkoutSessionIfNeeded()
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

            guard let workoutSession = self.workoutSession else {
                self.finishStopped()
                return
            }

            self.isStopping = true

            switch workoutSession.state {
            case .running, .paused:
                workoutSession.stopActivity(with: Date())
            case .notStarted, .prepared, .stopped, .ended:
                workoutSession.end()
            @unknown default:
                workoutSession.end()
            }
        }
    }

    private func startWorkoutSessionIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable() else {
            state = .error("HealthKit unavailable")
            sleepSessionRequested = false
            return
        }

        guard workoutSession == nil else { return }

        isStarting = true
        requestAuthorization { [weak self] success, error in
            guard let self else { return }

            self.ensureMain {
                self.isAuthorizing = false

                guard self.sleepSessionRequested else {
                    self.isStarting = false
                    return
                }

                guard success else {
                    self.isStarting = false
                    self.state = .error(error?.localizedDescription ?? "Workout authorization failed")
                    self.sleepSessionRequested = false
                    WatchSessionManager.shared.publishSleepSessionState(isActive: false)
                    return
                }

                do {
                    let configuration = HKWorkoutConfiguration()
                    configuration.activityType = .mindAndBody
                    configuration.locationType = .unknown

                    let workoutSession = try HKWorkoutSession(
                        healthStore: self.healthStore,
                        configuration: configuration
                    )
                    workoutSession.delegate = self
                    self.workoutSession = workoutSession
                    workoutSession.prepare()
                    workoutSession.startActivity(with: Date())
                    WatchCueScheduler.shared.hasLiveSession = false
                } catch {
                    self.isStarting = false
                    self.state = .error(error.localizedDescription)
                    self.sleepSessionRequested = false
                    self.workoutSession = nil
                    WatchSessionManager.shared.publishSleepSessionState(isActive: false)
                }
            }
        }
    }

    private func requestAuthorization(
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard !isAuthorizing else { return }

        isAuthorizing = true
        let shareTypes: Set = [HKObjectType.workoutType()]

        healthStore.requestAuthorization(toShare: shareTypes, read: []) {
            success,
            error in
            completion(success, error)
        }
    }

    private func finishStopped() {
        isStarting = false
        isAuthorizing = false
        isStopping = false
        workoutSession?.delegate = nil
        workoutSession = nil
        state = .inactive
        sessionStartTime = nil
        WatchCueScheduler.shared.hasLiveSession = false
        WatchSessionManager.shared.publishSleepSessionState(isActive: false)
    }
}

extension WatchSleepSession: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async {
            guard workoutSession == self.workoutSession else { return }

            switch toState {
            case .running:
                self.state = .active
                self.isStarting = false
                self.isStopping = false
                self.sessionStartTime = self.sessionStartTime ?? date
                WatchCueScheduler.shared.hasLiveSession = true

            case .stopped:
                workoutSession.end()

            case .ended:
                self.finishStopped()

            case .notStarted, .prepared, .paused:
                break

            @unknown default:
                self.state = .error("Unknown workout state")
                self.isStarting = false
                self.isStopping = false
                WatchCueScheduler.shared.hasLiveSession = false
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: any Error
    ) {
        DispatchQueue.main.async {
            guard workoutSession == self.workoutSession else { return }

            self.isStarting = false
            self.isStopping = false
            self.state = .error(error.localizedDescription)
            self.workoutSession?.delegate = nil
            self.workoutSession = nil
            self.sleepSessionRequested = false
            WatchCueScheduler.shared.hasLiveSession = false
            WatchSessionManager.shared.publishSleepSessionState(isActive: false)
        }
    }
}
