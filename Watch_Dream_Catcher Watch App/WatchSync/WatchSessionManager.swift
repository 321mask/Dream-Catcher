//
//  WatchSessionManager.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 15/01/2026.
//

import Foundation
import WatchConnectivity
import Observation

@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {
    var lastReceivedWindows: [DateInterval] = []
    var status: String = "Waiting…"

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

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        status = (activationState == .activated) ? "Connected" : "Not active"
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handle(payload: applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handle(payload: message)
    }

    private func handle(payload: [String: Any]) {
        guard
            let raw = payload["windows"] as? [[Double]]
        else {
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

        // Schedule cues as Watch local notifications for reliable haptics.
        Task {
            do {
                try await WatchCueScheduler.shared.requestAuthorizationIfNeeded()
                WatchCueScheduler.shared.replaceScheduledCues(
                    for: windows,
                    cuesPerWindow: cuesPerWindow,
                    spacingSeconds: spacingSeconds
                )
                status = "Cues scheduled"
            } catch {
                status = "Notif denied"
            }
        }
    }
}
