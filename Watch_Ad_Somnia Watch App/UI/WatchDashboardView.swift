//
//  WatchDashboardView.swift
//  Watch_Dream_Catcher Watch App
//
//  Created by Arseny Prostakov on 15/01/2026.
//

import SwiftUI

struct WatchDashboardView: View {
    var sleepSession: WatchSleepSession
    var sessionManager: WatchSessionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Sleep session controls (start/stop, status)
                    WatchSleepSessionView(sleepSession: sleepSession)

                    Divider()
                        .padding(.horizontal)

                    // Connection status and REM windows
                    windowsSection
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Windows Section

    private var windowsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Status")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(sessionManager.status)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 8)

            if !sessionManager.lastReceivedWindows.isEmpty {
                ForEach(Array(sessionManager.lastReceivedWindows.enumerated()), id: \.offset) { i, w in
                    HStack {
                        Text("Window \(i + 1)")
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(w.start.formatted(date: .omitted, time: .shortened)) - \(w.end.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 8)
                }
            } else {
                Text("No windows yet")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .padding(.horizontal, 4)
    }
}
