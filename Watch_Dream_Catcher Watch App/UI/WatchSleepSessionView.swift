//  WatchSleepSessionView.swift
//  Watch_Dream_Catcher Watch App
//
//  Sleep session controls for the Watch.
//
//  Auto-start behavior:
//    Sleep Focus ON  + view appears -> session starts automatically
//    Sleep Focus OFF + view appears -> shows "Start Sleep" button
//
//  Auto-stop behavior:
//    iPhone sends "sleepFocusOff" -> session stops (unless manually started)

import SwiftUI

struct WatchSleepSessionView: View {

    var sleepSession: WatchSleepSession

    @State private var showingConfirmStop = false
    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 12) {
            statusIndicator
            actionButton

            if sleepSession.isLive {
                sessionInfo
            }
        }
        .onAppear {
            sleepSession.autoStartIfAppropriate()
        }
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        VStack(spacing: 6) {
            ZStack {
                if sleepSession.isLive {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.3)
                        .animation(
                            .easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
            }
            .onAppear { pulseAnimation = true }

            Text(statusLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Button

    private var actionButton: some View {
        Group {
            switch sleepSession.state {
            case .inactive, .expired, .error:
                Button {
                    sleepSession.start()
                } label: {
                    Label("Start Sleep", systemImage: "moon.fill")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)

            case .active, .expiringSoon, .renewing:
                Button(role: .destructive) {
                    showingConfirmStop = true
                } label: {
                    Label("End Sleep", systemImage: "sun.max.fill")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .confirmationDialog(
                    "End sleep session?",
                    isPresented: $showingConfirmStop,
                    titleVisibility: .visible
                ) {
                    Button("End Sleep", role: .destructive) {
                        sleepSession.stop()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
    }

    // MARK: - Session Info

    private var sessionInfo: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.tap")
                .font(.system(size: 9))
                .foregroundColor(.green.opacity(0.6))

            Text("Enhanced cues active")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))

            if sleepSession.sessionsRenewed > 0 {
                Text("· \(sleepSession.sessionsRenewed)x renewed")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch sleepSession.state {
        case .active:       return .green
        case .expiringSoon: return .yellow
        case .renewing:     return .orange
        case .error:        return .red
        default:            return .gray.opacity(0.5)
        }
    }

    private var statusLabel: String {
        switch sleepSession.state {
        case .active:       return "Sleep session active"
        case .expiringSoon,
             .renewing:     return "Renewing..."
        case .inactive:     return "Ready"
        case .expired:      return "Session ended"
        case .error:        return "Error"
        }
    }
}
