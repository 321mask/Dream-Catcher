//  CueTestingView.swift
//  Dream_Catcher (iPhone target)
//
//  Debug UI for testing audio cue volumes and Watch haptic vibrations.
//  Add as a NavigationLink in your SettingsView.

import SwiftUI
import SwiftData
import WatchConnectivity

struct CueTestingView: View {

    let coordinator: AppCoordinator

    // MARK: - Audio Presets

    struct AudioPreset: Identifiable {
        let id: String
        let label: String
        let icon: String
        let volume: Float
        let description: String
    }

    private let audioPresets: [AudioPreset] = [
        AudioPreset(id: "barely", label: "Barely", icon: "speaker", volume: 0.03,
                     description: "At the edge of hearing. Research starting point."),
        AudioPreset(id: "whisper", label: "Whisper", icon: "speaker.wave.1", volume: 0.08,
                     description: "~30 dB. Faint but recognizable."),
        AudioPreset(id: "soft", label: "Soft", icon: "speaker.wave.1", volume: 0.15,
                     description: "~40 dB. TLR protocol target range."),
        AudioPreset(id: "medium", label: "Medium", icon: "speaker.wave.2", volume: 0.25,
                     description: "~50 dB. Clearly audible. May wake light sleepers."),
        AudioPreset(id: "loud", label: "Loud", icon: "speaker.wave.3", volume: 0.40,
                     description: "~60 dB. Will likely wake you. For daytime testing."),
    ]

    // MARK: - Haptic Presets

    struct HapticPreset: Identifiable {
        let id: String
        let label: String
        let icon: String
        let pattern: String
        let description: String
    }

    private let hapticPresets: [HapticPreset] = [
        HapticPreset(id: "single_light", label: "Single Light", icon: "hand.tap",
                      pattern: "single_light", description: "One subtle tap. Similar to notification fallback."),
        HapticPreset(id: "single_strong", label: "Single Strong", icon: "hand.tap.fill",
                      pattern: "single_strong", description: "One firm tap. Maximum single vibration."),
        HapticPreset(id: "triple_ascending", label: "Triple Ascending", icon: "waveform.path",
                      pattern: "triple_ascending", description: "Light -> medium -> strong. The TLR cue pattern."),
        HapticPreset(id: "triple_uniform", label: "Triple Uniform", icon: "waveform",
                      pattern: "triple_uniform", description: "Three equal taps. For comparison with ascending."),
        HapticPreset(id: "double_strong", label: "Double Strong", icon: "hand.tap.fill",
                      pattern: "double_strong", description: "Two firm taps. Simpler alternative pattern."),
    ]

    // MARK: - State

    @State private var lastPlayedAudio: String?
    @State private var lastPlayedHaptic: String?
    @State private var customVolume: Float = 0.10
    @State private var showCustomSlider = false
    @State private var testDelayIndex: Int = 2
    @State private var testCueCount: Int = 3
    @State private var player = TestCuePlayer()

    @Environment(\.modelContext) private var modelContext

    private let testDelayOptions: [(label: String, seconds: TimeInterval)] = [
        ("10s", 10),
        ("30s", 30),
        ("1m", 60),
        ("2m", 120),
        ("5m", 300),
        ("10m", 600),
        ("61m", 3660)
    ]

    // Observe centralized WCSession reachability
    @State private var sync = PhoneWatchSync.shared

    var body: some View {
        List {
            audioSection
            hapticSection
            combinedSection
            schedulingSection
            if showCustomSlider {
                customVolumeSection
            }
        }
        .appBackground()
        .navigationTitle("Cue Testing")
        .onAppear {
            try? player.setup()
        }
        .onDisappear {
            player.teardown()
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        Section {
            ForEach(audioPresets) { preset in
                Button {
                    playAudio(preset)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: preset.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.indigo)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(preset.label)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)

                                Text("(\(Int(preset.volume * 100))%)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Text(preset.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if lastPlayedAudio == preset.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        }
                    }
                }
            }

            Button {
                withAnimation { showCustomSlider.toggle() }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("Custom volume...")
                        .font(.system(size: 15))
                    Spacer()
                    Image(systemName: showCustomSlider ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Audio (iPhone Speaker)")
        } footer: {
            Text("Plays the three-tone TLR cue (400 -> 600 -> 800 Hz). Place phone on your nightstand to test realistic volume.")
        }
    }

    // MARK: - Custom Volume Slider

    private var customVolumeSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    Text("Volume")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(customVolume * 100))%")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.primary)
                }

                Slider(value: $customVolume, in: 0.01...0.50, step: 0.01)
                    .tint(.orange)

                HStack {
                    Text("0.01")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("0.50")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Button {
                    player.playCue(atVolume: customVolume)
                    lastPlayedAudio = "custom"
                } label: {
                    Text("Play at \(Int(customVolume * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Custom Volume")
        }
    }

    // MARK: - Haptic Section

    private var hapticSection: some View {
        Section {
            if !sync.isReachable {
                HStack(spacing: 8) {
                    Image(systemName: "applewatch.slash")
                        .foregroundColor(.orange)
                    Text("Watch not reachable. Open the Watch app first.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            ForEach(hapticPresets) { preset in
                Button {
                    playHaptic(preset)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: preset.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.label)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)

                            Text(preset.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if lastPlayedHaptic == preset.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        }
                    }
                }
                .disabled(!sync.isReachable)
                .opacity(sync.isReachable ? 1 : 0.4)
            }
        } header: {
            Text("Haptic (Apple Watch)")
        } footer: {
            Text("Sends vibration pattern to Apple Watch. Wear the Watch and test in your sleeping position.")
        }
    }

    // MARK: - Combined Section

    private var combinedSection: some View {
        Section {
            Button {
                playCombined(audioVolume: 0.08, hapticPattern: "triple_ascending")
            } label: {
                presetRow(icon: "sparkles", color: .cyan,
                          title: "Whisper + Triple",
                          subtitle: "Audio at 8% + ascending haptic. Subtle combo.")
            }
            .disabled(!sync.isReachable)

            Button {
                playCombined(audioVolume: 0.15, hapticPattern: "triple_ascending")
            } label: {
                presetRow(icon: "sparkles", color: .cyan,
                          title: "Soft + Triple",
                          subtitle: "Audio at 15% + ascending haptic. TLR target.")
            }
            .disabled(!sync.isReachable)

            Button {
                playCombined(audioVolume: 0.25, hapticPattern: "single_strong")
            } label: {
                presetRow(icon: "sparkles", color: .cyan,
                          title: "Medium + Single Strong",
                          subtitle: "Audio at 25% + one firm tap. Maximum salience.")
            }
            .disabled(!sync.isReachable)
        } header: {
            Text("Combined (Audio + Haptic)")
        } footer: {
            Text("Tests audio and haptic firing simultaneously, as they would during REM cue delivery.")
        }
    }

    // MARK: - Scheduling Section

    private var schedulingSection: some View {
        Section {
            Button("Run nightly update now") {
                let container = modelContext.container
                Task { await coordinator.runNightlyUpdate(modelContainer: container) }
            }

            Picker("First cue in", selection: $testDelayIndex) {
                ForEach(0..<testDelayOptions.count, id: \.self) { i in
                    Text(testDelayOptions[i].label).tag(i)
                }
            }

            Stepper("Cues: \(testCueCount)", value: $testCueCount, in: 1...10)

            Button("Schedule test cues") {
                Task { await scheduleTest() }
            }
        } header: {
            Text("Schedule Test Cues")
        } footer: {
            Text("Starts a Watch session and schedules cues at the selected delay. Also schedules iPhone notification cues.")
        }
    }

    // MARK: - Helpers

    private func presetRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private func playAudio(_ preset: AudioPreset) {
        player.playCue(atVolume: preset.volume)
        lastPlayedAudio = preset.id
    }

    private func playHaptic(_ preset: HapticPreset) {
        PhoneWatchSync.shared.sendTestHaptic(pattern: preset.pattern)
        lastPlayedHaptic = preset.id
    }

    private func playCombined(audioVolume: Float, hapticPattern: String) {
        player.playCue(atVolume: audioVolume)
        PhoneWatchSync.shared.sendTestHaptic(pattern: hapticPattern)
    }

    private func scheduleTest() async {
        let baseDelay = testDelayOptions[testDelayIndex].seconds
        let spacing: TimeInterval = 30
        let offsets = (0..<testCueCount).map { i in
            baseDelay + TimeInterval(i) * spacing
        }

        let windowStart = Date().addingTimeInterval(baseDelay)
        let windowEnd = Date().addingTimeInterval(offsets.last! + 60)
        let window = DateInterval(start: windowStart, end: windowEnd)
        coordinator.nextWindows = [window]

        PhoneWatchSync.shared.sendStartSleepSession()
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        do {
            try await CueScheduler().requestAuthorizationIfNeeded()
            CueScheduler().replaceScheduledCues(
                for: [window],
                cuesPerWindow: testCueCount,
                spacingSeconds: spacing
            )

            PhoneWatchSync.shared.sendScheduleTestCues(offsets: offsets)

            let delayLabel = testDelayOptions[testDelayIndex].label
            coordinator.statusText = "\(testCueCount) test cue\(testCueCount == 1 ? "" : "s") scheduled from \(delayLabel)"
        } catch {
            coordinator.statusText = "Notifications denied"
        }
    }
}

// MARK: - Test Player (thin wrapper around LucidCuePlayer)

private struct TestCuePlayer {
    private let player = LucidCuePlayer()

    func setup() throws { try player.setup() }
    func teardown() { player.teardown() }

    func playCue(atVolume volume: Float) {
        player.playCueWithFadeIn(targetVolume: volume, fadeDuration: 0.1)
    }
}

