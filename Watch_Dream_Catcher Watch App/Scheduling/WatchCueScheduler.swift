//  WatchCueScheduler.swift
//  Watch_Dream_Catcher Watch App
//
//  HYBRID: Notifications as reliable fallback + direct haptic when session is live.
//
//  Integration with WatchSleepSession:
//    When WatchSleepSession is .active:
//      -> hasLiveSession = true
//      -> Cues delivered via WKInterfaceDevice.play() (three-tap pattern)
//      -> Notifications still scheduled as safety net but suppressed in delegate
//    When WatchSleepSession is .inactive / .expired / killed by watchOS:
//      -> hasLiveSession = false
//      -> Cues delivered via scheduled notifications (single default haptic)

import Foundation
import UserNotifications
import WatchKit
import Observation

enum WatchCueSchedulerError: Error { case denied }

@Observable
final class WatchCueScheduler: NSObject {

    static let shared = WatchCueScheduler()
    private let center = UNUserNotificationCenter.current()
    private let hapticEngine = WatchHapticCueEngine()

    // MARK: - Session State

    var hasLiveSession = false {
        didSet {
            if hasLiveSession && !oldValue {
                if !scheduledFireDates.isEmpty {
                    startDirectDelivery(fireDates: scheduledFireDates)
                }
            } else if !hasLiveSession && oldValue {
                stopDirectDelivery()
            }
        }
    }

    private(set) var isDeliveringDirectly = false

    // MARK: - Pause State

    private var isPaused = false
    private var pauseResumeWork: DispatchWorkItem?

    // MARK: - Scheduled Cues

    private var scheduledFireDates: [Date] = []
    private var directDispatchItems: [DispatchWorkItem] = []

    // MARK: - Init

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Authorization

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

    // MARK: - Main API

    func replaceScheduledCues(
        for windows: [DateInterval],
        cuesPerWindow: Int,
        spacingSeconds: TimeInterval
    ) {
        var dates: [Date] = []
        for window in windows {
            for i in 0..<cuesPerWindow {
                let date = window.start.addingTimeInterval(TimeInterval(i) * spacingSeconds)
                guard date < window.end, date > Date().addingTimeInterval(5) else { continue }
                dates.append(date)
            }
        }
        dates.sort()
        scheduledFireDates = dates

        removePending { [weak self] in
            self?.scheduleNotifications(for: windows, cuesPerWindow: cuesPerWindow, spacingSeconds: spacingSeconds)
        }

        if hasLiveSession {
            startDirectDelivery(fireDates: dates)
        }
    }

    // MARK: - Direct Delivery

    private func startDirectDelivery(fireDates: [Date]) {
        stopDirectDelivery()
        isDeliveringDirectly = true

        for date in fireDates {
            let delay = date.timeIntervalSinceNow
            guard delay > 0 else { continue }

            let item = DispatchWorkItem { [weak self] in
                guard let self, self.isDeliveringDirectly, !self.isPaused else { return }
                self.hapticEngine.playCue()
                WatchSessionManager.shared.notifyCueDeliveredToPhone()
            }
            directDispatchItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    private func stopDirectDelivery() {
        isDeliveringDirectly = false
        for item in directDispatchItems { item.cancel() }
        directDispatchItems.removeAll()
    }

    // MARK: - Motion-Aware Pause

    func pauseForMotion(duration: TimeInterval = 5 * 60) {
        isPaused = true
        pauseResumeWork?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.isPaused = false
        }
        pauseResumeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func pauseForAwakening(duration: TimeInterval = 45 * 60) {
        pauseForMotion(duration: duration)
    }

    // MARK: - Notification Fallback

    private func removePending(completion: @escaping () -> Void) {
        center.getPendingNotificationRequests { [weak self] reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix("remcue.") }
            self?.center.removePendingNotificationRequests(withIdentifiers: ids)
            completion()
        }
    }

    private func scheduleNotifications(
        for windows: [DateInterval],
        cuesPerWindow: Int,
        spacingSeconds: TimeInterval
    ) {
        guard cuesPerWindow > 0 else { return }

        for (wIndex, window) in windows.enumerated() {
            for cueIndex in 0..<cuesPerWindow {
                let fireDate = window.start.addingTimeInterval(
                    TimeInterval(cueIndex) * spacingSeconds
                )
                if fireDate >= window.end { break }
                if fireDate <= .now.addingTimeInterval(5) { continue }

                let content = UNMutableNotificationContent()
                content.categoryIdentifier = "REM_CUE"
                content.title = ""
                content.body = ""
                content.sound = .default

                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: comps, repeats: false
                )

                let id = "remcue.\(wIndex).\(cueIndex).\(Int(fireDate.timeIntervalSince1970))"
                center.add(UNNotificationRequest(
                    identifier: id, content: content, trigger: trigger
                ))
            }
        }
    }

    // MARK: - Test Cues

    /// Schedule test cues at the given offsets (in seconds) from now.
    /// Uses the same direct-delivery + notification-fallback path as real cues.
    func scheduleTestCues(offsets: [TimeInterval]) {
        let sanitized = offsets
            .map { max(1.0, $0) }
            .sorted()

        guard !sanitized.isEmpty else { return }

        isPaused = false
        pauseResumeWork?.cancel()

        let now = Date()
        let dates = sanitized.map { now.addingTimeInterval($0) }
        scheduledFireDates = dates

        Task {
            try? await requestAuthorizationIfNeeded()

            // Schedule notification fallback using relative triggers for near-term test cues.
            removePending { [weak self] in
                guard let self else { return }
                for (i, offset) in sanitized.enumerated() {
                    let content = UNMutableNotificationContent()
                    content.categoryIdentifier = "REM_CUE"
                    content.title = ""
                    content.body = ""
                    content.sound = .default

                    let trigger = UNTimeIntervalNotificationTrigger(
                        timeInterval: offset,
                        repeats: false
                    )
                    let id = "remcue.test.\(i).\(Int(now.timeIntervalSince1970))"
                    self.center.add(UNNotificationRequest(
                        identifier: id,
                        content: content,
                        trigger: trigger
                    ))
                }
            }
        }

        // If session is live, also schedule direct haptic delivery.
        // If not live yet, hasLiveSession didSet will start delivery once active.
        if hasLiveSession {
            startDirectDelivery(fireDates: dates)
        }
    }

    // MARK: - Cleanup

    func removeAllScheduledCues() {
        stopDirectDelivery()
        scheduledFireDates.removeAll()
        isPaused = false
        pauseResumeWork?.cancel()
        removePending {}
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension WatchCueScheduler: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.content.categoryIdentifier == "REM_CUE" else {
            completionHandler([.banner, .sound])
            return
        }

        if isPaused {
            completionHandler([])
        } else if isDeliveringDirectly {
            completionHandler([])
        } else {
            hapticEngine.playCue()
            completionHandler([])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
