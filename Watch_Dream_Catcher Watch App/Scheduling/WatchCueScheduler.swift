//
//  WatchCueScheduler.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 15/01/2026.
//

import Foundation
import UserNotifications

enum WatchCueSchedulerError: Error { case denied }

final class WatchCueScheduler {
    static let shared = WatchCueScheduler()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    func requestAuthorizationIfNeeded() async throws {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted { throw WatchCueSchedulerError.denied }
        case .denied:
            throw WatchCueSchedulerError.denied
        @unknown default:
            throw WatchCueSchedulerError.denied
        }
    }

    func replaceScheduledCues(for windows: [DateInterval], cuesPerWindow: Int, spacingSeconds: TimeInterval) {
        removePending { [weak self] in
            self?.schedule(for: windows, cuesPerWindow: cuesPerWindow, spacingSeconds: spacingSeconds)
        }
    }

    private func removePending(completion: @escaping () -> Void) {
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix("remcue.") }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            completion()
        }
    }

    private func schedule(for windows: [DateInterval], cuesPerWindow: Int, spacingSeconds: TimeInterval) {
        guard cuesPerWindow > 0 else { return }

        for (wIndex, window) in windows.enumerated() {
            for cueIndex in 0..<cuesPerWindow {
                let fireDate = window.start.addingTimeInterval(TimeInterval(cueIndex) * spacingSeconds)
                if fireDate >= window.end { break }
                if fireDate <= .now.addingTimeInterval(5) { continue }

                let content = UNMutableNotificationContent()
                content.title = "REM cue"
                content.body = "Reality check"
                content.sound = .default  // On Watch, this commonly triggers a haptic (settings-dependent)

                let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

                let id = "remcue.\(wIndex).\(cueIndex).\(Int(fireDate.timeIntervalSince1970))"
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }
}
