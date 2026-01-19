//
//  CueScheduler.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation
import UserNotifications
import UIKit

enum CueSchedulerError: Error {
    case notificationsDenied
}

final class CueScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async throws {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted { throw CueSchedulerError.notificationsDenied }
        case .denied:
            throw CueSchedulerError.notificationsDenied
        @unknown default:
            throw CueSchedulerError.notificationsDenied
        }
    }

    func replaceScheduledCues(for windows: [DateInterval], cuesPerWindow: Int, spacingSeconds: TimeInterval) {
        removePendingCues { [weak self] in
            self?.scheduleCues(for: windows, cuesPerWindow: cuesPerWindow, spacingSeconds: spacingSeconds)
        }
    }

    private func removePendingCues(completion: @escaping () -> Void) {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(NotificationIdentifiers.cuePrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            completion()
        }
    }

    private func scheduleCues(for windows: [DateInterval], cuesPerWindow: Int, spacingSeconds: TimeInterval) {
        guard cuesPerWindow > 0 else { return }

        for (wIndex, window) in windows.enumerated() {
            // Spread cues inside the window from start forward
            for cueIndex in 0..<cuesPerWindow {
                let fireDate = window.start.addingTimeInterval(TimeInterval(cueIndex) * spacingSeconds)
                if fireDate >= window.end { break }
                if fireDate <= .now.addingTimeInterval(5) { continue } // don't schedule in the past/too soon

                let id = "\(NotificationIdentifiers.cuePrefix)\(wIndex).\(cueIndex).\(Int(fireDate.timeIntervalSince1970))"

                let content = UNMutableNotificationContent()
                content.title = "REM cue"
                content.body = "Quick reality check."
                content.sound = .default // best chance of haptic depending on system settings

                let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }
}
