//
//  HapticsControlView.swift
//  Watch_Dream_Catcher Watch App
//
//  Simple tester for Watch haptics using WKInterfaceDevice.
//

import SwiftUI
import WatchKit

struct HapticsControlView: View {
    // 0 = light, 1 = medium, 2 = strong
    @State private var strengthIndex: Int = 1
    @State private var lastPlayedDescription: String?

    // Scheduled cue test state
    @State private var selectedDelayIndex: Int = 0
    @State private var cueCount: Int = 3
    @State private var scheduledStatus: String?
    @State private var sleepSession = WatchSleepSession.shared

    private let delayOptions: [(label: String, seconds: TimeInterval)] = [
        ("10s", 10),
        ("30s", 30),
        ("1m", 60),
        ("2m", 120),
        ("5m", 300),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                instantHapticSection
                Divider().padding(.horizontal)
                scheduledCueSection
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Haptics Test")
    }

    // MARK: - Instant Haptic Section

    private var instantHapticSection: some View {
        VStack(spacing: 8) {
            Text("Instant Haptic")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))

            VStack(spacing: 8) {
                HStack {
                    Text("Strength")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(currentLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }

                Slider(value: Binding(
                    get: { Double(strengthIndex) },
                    set: { strengthIndex = Int(round($0)) }
                ), in: 0...2, step: 1)
                .tint(.purple)

                HStack {
                    Text("Light")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Medium")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Strong")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Button {
                playSelected()
            } label: {
                Label("Play", systemImage: "hand.tap")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)

            if let desc = lastPlayedDescription {
                Text("Played: \(desc)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Scheduled Cue Test Section

    private var scheduledCueSection: some View {
        VStack(spacing: 10) {
            Text("Scheduled Cue Test")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))

            // Session status
            HStack(spacing: 6) {
                Circle()
                    .fill(sleepSession.isLive ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(sleepSession.isLive ? "Session active" : "No session")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 8)

            // Start session button if not active
            if !sleepSession.isLive {
                Button {
                    sleepSession.start(source: .localWatch)
                } label: {
                    Label(
                        sleepSession.isBusyStarting ? "Starting..." : "Start Session",
                        systemImage: "moon.fill"
                    )
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.bordered)
                .tint(.indigo)
                .disabled(sleepSession.isBusyStarting)
            }

            // First cue delay picker
            VStack(spacing: 4) {
                Text("First cue in")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                Picker("Delay", selection: $selectedDelayIndex) {
                    ForEach(0..<delayOptions.count, id: \.self) { i in
                        Text(delayOptions[i].label).tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 50)
            }

            // Cue count stepper
            HStack {
                Text("Cues")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    if cueCount > 1 { cueCount -= 1 }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                Text("\(cueCount)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .frame(width: 24)

                Button {
                    if cueCount < 10 { cueCount += 1 }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            // Schedule button
            Button {
                scheduleTestCues()
            } label: {
                Label("Schedule Cues", systemImage: "clock.badge.checkmark")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)

            // Status feedback
            if let status = scheduledStatus {
                Text(status)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }

            Text("Schedules haptic cues via direct delivery (session) + notification fallback. Start a session first for direct haptics.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Helpers

    private var currentLabel: String {
        switch strengthIndex {
        case 0: return "Light"
        case 1: return "Medium"
        default: return "Strong"
        }
    }

    private func playSelected() {
        let device = WKInterfaceDevice.current()
        let type: WKHapticType
        switch strengthIndex {
        case 0:
            type = .click          // light
        case 1:
            type = .directionUp    // medium-ish
        default:
            type = .notification   // strong
        }
        device.play(type)
        lastPlayedDescription = currentLabel
    }

    private func scheduleTestCues() {
        let baseDelay = delayOptions[selectedDelayIndex].seconds
        // Space cues 30s apart starting at the chosen delay
        let spacing: TimeInterval = 30
        let offsets = (0..<cueCount).map { i in
            baseDelay + TimeInterval(i) * spacing
        }

        WatchCueScheduler.shared.scheduleTestCues(offsets: offsets)

        let firstLabel = delayOptions[selectedDelayIndex].label
        let lastOffset = offsets.last ?? baseDelay
        let lastLabel = lastOffset < 60
            ? "\(Int(lastOffset))s"
            : "\(Int(lastOffset / 60))m\(Int(lastOffset.truncatingRemainder(dividingBy: 60)))s"
        scheduledStatus = "\(cueCount) cue\(cueCount == 1 ? "" : "s") scheduled: \(firstLabel)–\(lastLabel) from now"

        if sleepSession.isLive {
            scheduledStatus! += "\nDirect delivery active"
        } else {
            scheduledStatus! += "\nNotification fallback only"
        }
    }
}
