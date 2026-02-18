//
//  PhoneWatchSync.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 15/01/2026.
//

import Foundation
import WatchConnectivity
import Observation

@Observable
final class PhoneWatchSync: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchSync()

    // --- TLR message types ---

    // Watch -> iPhone: REM detected, start cueing
    static let remDetected = "tlr_remDetected"
    static let motionDetected = "tlr_motionDetected"
    static let awakeningDetected = "tlr_awakeningDetected"
    static let remEnded = "tlr_remEnded"

    // iPhone -> Watch: play haptic cue
    static let playHaptic = "tlr_playHaptic"

    /// Set by AppCoordinator so Watch signals can reach the REMCueScheduler.
    weak var remCueScheduler: REMCueScheduler?

    // MARK: - Reachability (published to SwiftUI)

    /// True when interactive messaging to the Watch is available.
    /// This generally requires the Watch app to be in the foreground.
    private(set) var isReachable: Bool = false

    private override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Convenience

    /// Send a command to the Watch (e.g., playHaptic, sleepFocusOn/Off).
    func send(_ message: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { err in
                log("WC send error: \(err)")
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    /// Used by CueTestingView to trigger haptic tests.
    func sendTestHaptic(pattern: String) {
        send(["command": "testHaptic", "pattern": pattern])
    }

    // MARK: - Sending windows (unchanged)

    func sendRemWindowsToWatch(windows: [DateInterval], cuesPerWindow: Int, spacingSeconds: TimeInterval) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let encoded: [[Double]] = windows.map { w in
            [w.start.timeIntervalSince1970, w.end.timeIntervalSince1970]
        }

        let message: [String: Any] = [
            "windows": encoded,
            "cuesPerWindow": cuesPerWindow,
            "spacingSeconds": spacingSeconds
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { err in
                log("WC sendMessage error: \(err)")
            })
        } else {
            do {
                try session.updateApplicationContext(message)
            } catch {
                log("WC updateApplicationContext error: \(error)")
            }
        }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }

#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncoming(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    // MARK: - Incoming Message Handling

    private func handleIncoming(_ payload: [String: Any]) {
        guard let command = payload["command"] as? String else { return }

        DispatchQueue.main.async { [weak self] in
            switch command {
            case "tlr_remDetected":
                self?.remCueScheduler?.remDetected()
            case "tlr_motionDetected":
                self?.remCueScheduler?.motionDetected()
            case "tlr_awakeningDetected":
                self?.remCueScheduler?.awakeningDetected()
            case "tlr_remEnded":
                self?.remCueScheduler?.remEnded()
            default:
                break
            }
        }
    }
}

