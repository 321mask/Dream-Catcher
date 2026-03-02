//
//  Watch_Dream_CatcherApp.swift
//  Watch_Dream_Catcher Watch App
//
//  Created by Arseny Prostakov on 15/01/2026.
//

import SwiftUI
import WatchKit

// MARK: - App Delegate

/// Handles system callbacks that require WKApplicationDelegate, most importantly
/// re-attaching the session delegate when the system relaunches the app for a
/// previously-scheduled alarm session.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        WatchSleepSession.shared.handleSystemSession(extendedRuntimeSession)
    }
}

// MARK: - App

@main
struct Watch_Dream_Catcher_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor var appDelegate: WatchAppDelegate

    @State private var sleepSession = WatchSleepSession.shared
    @State private var sessionManager = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            WatchDashboardView(
                sleepSession: sleepSession,
                sessionManager: sessionManager
            )
            .onAppear {
                sessionManager.sleepSession = sleepSession
            }
        }
    }
}
