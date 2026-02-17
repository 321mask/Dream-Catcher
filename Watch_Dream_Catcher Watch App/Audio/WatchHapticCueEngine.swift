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

    /// Play the full three-tap ascending cue.
    /// Call from WatchCueScheduler when receiving "playHaptic" from iPhone,
    /// or directly when the Watch is delivering cues autonomously.
    func playCue() {
        let device = WKInterfaceDevice.current()

        for step in LucidCue.hapticPattern {
            let wkType = mapType(step.intensity)

            if step.delay == 0 {
                device.play(wkType)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                    device.play(wkType)
                }
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
