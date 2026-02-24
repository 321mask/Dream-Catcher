//
//  WatchSessionManager.swift
//  Watch_Dream_Catcher Watch App
//
//  Created by Arseny Prostakov on 15/01/2026.
//
//  Handles all WCSession communication from iPhone:
//  - REM window scheduling (windows, cuesPerWindow, spacingSeconds)
//  - Sleep Focus commands (sleepFocusOn / sleepFocusOff)
//  - Sleep session commands (startSleepSession / stopSleepSession)
//  - Haptic test commands (testHaptic with pattern)
//  - TLR haptic cue commands (tlr_playHaptic)

import Foundation
import WatchConnectivity
import Observation
import WatchKit

@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {
    var lastReceivedWindows: [DateInterval] = []
    var status: String = "Waiting..."

    /// Set externally by the Watch app entry point so we can
    /// forward Sleep Focus and session commands to it.
    weak var sleepSession: WatchSleepSession?

    override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard WCSession.isSupported() else {
            status = "WC not supported"
            return
        }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.status = (activationState == .activated) ? "Connected" : "Not active"
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.handle(payload: applicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handle(payload: message)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            self.handle(payload: userInfo)
        }
    }

    // MARK: - Payload Handling

    private func handle(payload: [String: Any]) {
        // Check for command-based messages first
        if let command = payload["command"] as? String {
            handleCommand(command, payload: payload)
            return
        }

        // Otherwise, treat as REM window payload
        handleWindowPayload(payload)
    }

    private func handleCommand(_ command: String, payload: [String: Any]) {
        switch command {

        // Sleep Focus detection from iPhone
        case "sleepFocusOn":
            sleepSession?.isSleepFocusActive = true

        case "sleepFocusOff":
            sleepSession?.isSleepFocusActive = false

        // Explicit session control from iPhone
        case "startSleepSession":
            sleepSession?.start()

        case "stopSleepSession":
            sleepSession?.stop()

        // REM cue scheduling from iPhone
        case "scheduleRemCues":
            if let windowsData = payload["windows"] as? [[String: TimeInterval]] {
                let windows = windowsData.compactMap { dict -> DateInterval? in
                    guard let start = dict["start"], let end = dict["end"] else { return nil }
                    return DateInterval(
                        start: Date(timeIntervalSince1970: start),
                        end: Date(timeIntervalSince1970: end)
                    )
                }
                let cuesPerWindow = payload["cuesPerWindow"] as? Int ?? 10
                let spacing = payload["spacing"] as? TimeInterval ?? 30.0

                WatchCueScheduler.shared.replaceScheduledCues(
                    for: windows,
                    cuesPerWindow: cuesPerWindow,
                    spacingSeconds: spacing
                )
            }

        // Haptic test from iPhone's CueTestingView
        case "testHaptic":
            if let pattern = payload["pattern"] as? String {
                WatchHapticTestHandler.play(pattern: pattern)
            }

        // TLR haptic cue from iPhone (during REM cue delivery)
        case "tlr_playHaptic":
            WatchHapticCueEngine().playCue()

        // NEW: Persist haptic strength sent from iPhone (0,1,2)
        case "setHapticStrength":
            if let value = payload["value"] as? Int {
                UserDefaults.standard.set(value, forKey: "hapticStrength")
            }

        // NEW: Play one tap at the saved strength immediately
        case "playSavedStrength":
            let saved = UserDefaults.standard.integer(forKey: "hapticStrength")
            let type: WKHapticType
            switch saved {
            case 0: type = .click
            case 2: type = .notification
            default: type = .directionUp
            }
            WKInterfaceDevice.current().play(type)

        default:
            break
        }
    }

    private func handleWindowPayload(_ payload: [String: Any]) {
        guard let raw = payload["windows"] as? [[Double]] else {
            status = "Bad payload"
            return
        }

        let windows: [DateInterval] = raw.compactMap { pair in
            guard pair.count == 2 else { return nil }
            let start = Date(timeIntervalSince1970: pair[0])
            let end = Date(timeIntervalSince1970: pair[1])
            guard end > start else { return nil }
            return DateInterval(start: start, end: end)
        }

        let cuesPerWindow = payload["cuesPerWindow"] as? Int ?? 5
        let spacingSeconds = payload["spacingSeconds"] as? Double ?? 120

        lastReceivedWindows = windows
        status = "Received \(windows.count) windows"

        Task {
            do {
                try await WatchCueScheduler.shared.requestAuthorizationIfNeeded()
                WatchCueScheduler.shared.replaceScheduledCues(
                    for: windows,
                    cuesPerWindow: cuesPerWindow,
                    spacingSeconds: spacingSeconds
                )
                await MainActor.run { self.status = "Cues scheduled" }
            } catch {
                await MainActor.run { self.status = "Notif denied" }
            }
        }
    }
}

