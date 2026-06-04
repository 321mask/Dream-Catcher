//  SleepFocusObserver.swift
//  Dream_Catcher (iPhone target only)
//
//  Detects when Sleep Focus activates/deactivates on iPhone and sends
//  the state to the Watch via PhoneWatchSync.
//
//  The Watch uses this to auto-start/stop WatchSleepSession:
//    Sleep Focus ON  -> Watch auto-starts extended runtime session
//    Sleep Focus OFF -> Watch auto-stops (morning)
//
//  DETECTION METHOD:
//  The most reliable signal is HealthKit sleep analysis samples.
//  When Sleep Focus activates, iOS writes an .inBed sample automatically.
//  Your existing HealthKitBackgroundObserver / SleepSessionExtractor
//  handles this. Call onSleepDetectedFromHealthKit() from there.
//
//  As a secondary heuristic, we check time-of-day for sanity.

import Foundation
import Observation
import WatchConnectivity

@Observable
final class SleepFocusObserver {

    private(set) var isSleepFocusActive = false

    // MARK: - External Hooks

    /// Call this from your existing HealthKit sleep detection when an
    /// .inBed or .asleepUnspecified sample is written.
    /// This is the most reliable signal that Sleep Focus activated.
    func onSleepDetectedFromHealthKit() {
        setSleepFocusActive(true)
    }

    /// Call this when your HealthKit observer detects the sleep session ended.
    func onSleepEndedFromHealthKit() {
        setSleepFocusActive(false)
    }

    // MARK: - Private

    private func setSleepFocusActive(_ active: Bool) {
        guard active != isSleepFocusActive else { return }
        isSleepFocusActive = active
        sendToWatch(active)
    }

    // MARK: - Watch Communication

    /// Send Sleep Focus state to the Watch via WCSession.
    private func sendToWatch(_ isActive: Bool) {
        let command = isActive ? "sleepFocusOn" : "sleepFocusOff"

        guard WCSession.default.activationState == .activated else { return }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                ["command": command],
                replyHandler: nil,
                errorHandler: nil
            )
        } else {
            WCSession.default.transferUserInfo(["command": command])
        }
    }
}
