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

            // Haptics tester navigation
            NavigationLink {
                HapticsControlView()
            } label: {
                Label("Haptics Test", systemImage: "waveform.path")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.bordered)
            .tint(.purple.opacity(0.8))
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
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Button

    private var actionButton: some View {
        Group {
            switch sleepSession.state {
            case .inactive, .error:
                Button {
                    sleepSession.start(source: .localWatch)
                } label: {
                    Label(sleepSession.isBusyStarting ? "Starting..." : "Start Sleep", systemImage: "moon.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(sleepSession.isBusyStarting)
                .accessibilityHint("Starts the watch sleep session")

            case .active:
                Button(role: .destructive) {
                    showingConfirmStop = true
                } label: {
                    Label("End Sleep", systemImage: "sun.max.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Stops the watch sleep session")
                .confirmationDialog(
                    "End sleep session?",
                    isPresented: $showingConfirmStop,
                    titleVisibility: .visible
                ) {
                    Button("End Sleep", role: .destructive) {
                        sleepSession.stop(source: .localWatch)
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
                .font(.caption2)
                .foregroundColor(.green.opacity(0.6))
                .accessibilityHidden(true)

            Text("Enhanced cues active")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))

        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch sleepSession.state {
        case .active: return .green
        case .error: return .red
        default: return .gray.opacity(0.5)
        }
    }

    private var statusLabel: String {
        switch sleepSession.state {
        case .active: return "Sleep session active"
        case .inactive: return "Ready"
        case .error: return "Error"
        }
    }
}
