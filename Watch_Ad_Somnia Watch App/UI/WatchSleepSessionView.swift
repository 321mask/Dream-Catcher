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
    @State private var scheduler = WatchCueScheduler.shared

    @State private var showingConfirmStop = false
    @State private var pulseAnimation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusIndicator

                if case .error(let message) = sleepSession.state {
                    errorBox(message: message)
                }

                actionButton

                if sleepSession.isLive {
                    sessionInfo
                    diagnosticsBox
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

    // MARK: - Diagnostics

    /// Surfaces information useful for verifying the session truly stayed
    /// alive overnight: elapsed time, scheduled cue count, delivered count.
    private var diagnosticsBox: some View {
        VStack(spacing: 4) {
            diagnosticsRow(
                label: "Running for",
                value: formattedElapsed(sleepSession.sessionStartTime)
            )
            diagnosticsRow(
                label: "Cues delivered",
                value: "\(scheduler.cuesDelivered) / \(scheduler.scheduledFireDates.count)"
            )
            diagnosticsRow(
                label: "Last cue",
                value: formattedLastCue(scheduler.lastDeliveredAt)
            )
            diagnosticsRow(
                label: "Last poll",
                value: formattedLastCue(scheduler.lastPollAt)
            )
            diagnosticsRow(
                label: "Longest gap",
                value: formattedGap(scheduler.longestPollGap)
            )
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Healthy sessions poll every ~5s; a gap of minutes or hours means the
    /// app was suspended and the audio keepalive failed for that stretch.
    private func formattedGap(_ gap: TimeInterval) -> String {
        guard gap > 0 else { return "—" }
        let s = Int(gap)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }

    private func formattedLastCue(_ date: Date?) -> String {
        guard let date else { return "—" }
        let ago = Int(Date().timeIntervalSince(date))
        if ago < 60 { return "\(ago)s ago" }
        let m = ago / 60
        if m < 60 { return "\(m)m ago" }
        return "\(m / 60)h \(m % 60)m ago"
    }

    private func diagnosticsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.caption2.monospacedDigit())
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private func formattedElapsed(_ start: Date?) -> String {
        guard let start else { return "—" }
        let seconds = Int(Date().timeIntervalSince(start))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        }
        return String(format: "%dm %02ds", m, s)
    }

    // MARK: - Error Box

    private func errorBox(message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                Text("Session failed")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
            }
            Text(message)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
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
