//
//  PhoneWatchSync.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 15/01/2026.
//

import Foundation
import WatchConnectivity

final class PhoneWatchSync: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchSync()

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

        // If reachable, use message; otherwise use application context (last state wins).
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

    // MARK: WCSessionDelegate (required stubs)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {}
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {}
}
