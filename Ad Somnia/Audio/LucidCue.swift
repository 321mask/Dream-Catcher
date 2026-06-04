//  LucidCue.swift
//  Dream_Catcher
//
//  Shared cue definition — add to BOTH iPhone and Watch targets.
//  Based on Carr, Konkoly, Mallett et al. (2023) TLR protocol.

import Foundation

/// The core TLR cue shared between iPhone (audio) and Watch (haptic).
///
/// Audio: three ascending pure tones — 400 Hz → 600 Hz → 800 Hz
/// Each tone 200ms, 25ms silent gaps between them. Total ~650ms.
///
/// Haptic: three taps with ascending intensity, timed to match.
struct LucidCue {

    // MARK: - Audio Parameters

    static let frequencies: [Double] = [400.0, 600.0, 800.0]
    static let toneDuration: TimeInterval = 0.200
    static let gapDuration: TimeInterval = 0.025
    static let fadeDuration: TimeInterval = 0.010

    static var totalDuration: TimeInterval {
        Double(frequencies.count) * toneDuration +
        Double(frequencies.count - 1) * gapDuration
    }

    // MARK: - Haptic Parameters

    enum HapticIntensity: String, Codable, CaseIterable {
        case light    // WKHapticType.click
        case medium   // WKHapticType.directionUp
        case strong   // WKHapticType.notification
    }

    struct HapticStep {
        let delay: TimeInterval
        let intensity: HapticIntensity
    }

    /// Three taps matching the ascending audio rhythm:
    ///   0ms   → light  (400 Hz tone)
    ///   225ms → medium (600 Hz tone)
    ///   450ms → strong (800 Hz tone)
    static let hapticPattern: [HapticStep] = [
        HapticStep(delay: 0.000, intensity: .light),
        HapticStep(delay: 0.225, intensity: .medium),
        HapticStep(delay: 0.450, intensity: .strong),
    ]
}
