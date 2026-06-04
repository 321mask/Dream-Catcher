//  WatchHapticCueEngine.swift
//  Watch_Dream_Catcher Watch App (Watch target only)
//
//  Delivers the three-tap haptic pattern that mirrors the iPhone audio cue.
//
//  Pattern:
//    Tap 1 at 0ms    → .click        (light)   — matches 400 Hz tone
//    Tap 2 at 225ms  → .directionUp  (medium)  — matches 600 Hz tone
//    Tap 3 at 450ms  → .notification (strong)  — matches 800 Hz tone
//
//  This MUST be the same rhythm as the audio cue. During pre-sleep training,
//  the user experiences both simultaneously, conditioning the brain to
//  associate this haptic pattern with lucid awareness.

import WatchKit

final class WatchHapticCueEngine {

    /// Play the ascending TLR cue pattern (click → directionUp → notification).
    /// The user-chosen strength (0/1/2) controls how many times the pattern
    /// repeats (1×, 2×, 3×), preserving the correct frequency progression.
    func playCue() {
        let device = WKInterfaceDevice.current()
        let saved = UserDefaults.standard.integer(forKey: "hapticStrength")
        let repetitions = saved + 1  // 0→1, 1→2, 2→3

        let patternDuration: TimeInterval = 0.650
        for rep in 0..<repetitions {
            let base = Double(rep) * patternDuration

            let tap1 = base
            let tap2 = base + 0.225
            let tap3 = base + 0.450

            if tap1 == 0 {
                device.play(.click)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + tap1) {
                    device.play(.click)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + tap2) {
                device.play(.directionUp)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + tap3) {
                device.play(.notification)
            }
        }
    }

    /// Play a single tap (useful for reality-check reminders during the day).
    func playSingleTap(_ intensity: LucidCue.HapticIntensity = .medium) {
        WKInterfaceDevice.current().play(mapType(intensity))
    }

    // MARK: - Private

    private func mapType(_ intensity: LucidCue.HapticIntensity) -> WKHapticType {
        switch intensity {
        case .light:  return .click
        case .medium: return .directionUp
        case .strong: return .notification
        }
    }
}
