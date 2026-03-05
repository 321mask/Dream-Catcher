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
    static let shared = WatchSessionManager()
    static let syncSleepSessionState = "syncSleepSessionState"
    static let syncSleepSessionUpdatedAt = "syncSleepSessionUpdatedAt"
    static let cueDelivered = "cueDelivered"

    var lastReceivedWindows: [DateInterval] = []
    var status: String = "Waiting..."

    /// Set externally by the Watch app entry point so we can
    /// forward Sleep Focus and session commands to it.
    weak var sleepSession: WatchSleepSession? {
        didSet {
            refreshSleepSessionStateFromSession()
        }
    }

    private override init() {
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
            self.refreshSleepSessionStateFromSession()
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

    func sendStartSleepSessionToPhone() {
        sendCommandToPhone("startSleepSession")
        publishSleepSessionState(isActive: true)
    }

    func sendStopSleepSessionToPhone() {
        sendCommandToPhone("stopSleepSession")
        publishSleepSessionState(isActive: false)
    }

    func notifyCueDeliveredToPhone() {
        sendCommandToPhone("cueDelivered")
    }

    func publishSleepSessionState(isActive: Bool) {
        publishApplicationContext([
            Self.syncSleepSessionState: isActive,
            Self.syncSleepSessionUpdatedAt: Date().timeIntervalSince1970
        ])
    }

    func refreshSleepSessionStateFromSession() {
        guard sleepSession != nil else { return }
        handle(payload: WCSession.default.receivedApplicationContext)
    }

    private func sendCommandToPhone(_ command: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload: [String: Any] = ["command": command]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("Watch->Phone WC sendMessage error: \(error)")
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func handle(payload: [String: Any]) {
        if let isActive = payload[Self.syncSleepSessionState] as? Bool {
            applyPhoneSessionState(isActive: isActive)
        }

        // Check for command-based messages first
        if let command = payload["command"] as? String {
            handleCommand(command, payload: payload)
            return
        }

        // Otherwise, treat as REM window payload
        if payload["windows"] != nil {
            handleWindowPayload(payload)
        }
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
            sleepSession?.start(source: .remotePhone)

        case "stopSleepSession":
            sleepSession?.stop(source: .remotePhone)

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

        // Scheduled test cues from iPhone — starts session + schedules haptic cues
        case "scheduleTestCues":
            let offsets = decodeOffsets(from: payload)
            guard !offsets.isEmpty else { break }

            // Start the extended runtime session if not already live
            if let session = sleepSession, !session.isLive {
                session.start(source: .remotePhone)
            }

            WatchCueScheduler.shared.scheduleTestCues(offsets: offsets)

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

    private func applyPhoneSessionState(isActive: Bool) {
        guard let sleepSession else { return }

        if isActive {
            if sleepSession.isSessionRequested { return }
            sleepSession.start(source: .remotePhone)
        } else if sleepSession.isSessionRequested {
            sleepSession.stop(source: .remotePhone)
        }
    }

    private func decodeOffsets(from payload: [String: Any]) -> [TimeInterval] {
        if let offsets = payload["offsets"] as? [TimeInterval] {
            return offsets
        }
        if let offsets = payload["offsets"] as? [Double] {
            return offsets
        }
        if let offsets = payload["offsets"] as? [NSNumber] {
            return offsets.map { $0.doubleValue }
        }
        return []
    }

    private func publishApplicationContext(_ values: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var context = session.applicationContext
        for (key, value) in values {
            context[key] = value
        }

        do {
            try session.updateApplicationContext(context)
        } catch {
            print("Watch WC updateApplicationContext error: \(error)")
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

        WatchCueScheduler.shared.replaceScheduledCues(
            for: windows,
            cuesPerWindow: cuesPerWindow,
            spacingSeconds: spacingSeconds
        )
        status = "Cues scheduled"
    }
}
