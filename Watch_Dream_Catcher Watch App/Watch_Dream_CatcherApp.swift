//
//  Watch_Dream_CatcherApp.swift
//  Watch_Dream_Catcher Watch App
//
//  Created by Arseny Prostakov on 15/01/2026.
//

import SwiftUI

@main
struct Watch_Dream_Catcher_Watch_AppApp: App {
    @State private var sleepSession = WatchSleepSession()
    @State private var sessionManager = WatchSessionManager()

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
