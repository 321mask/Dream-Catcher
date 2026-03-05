//  VolumeCalibration.swift
//  Dream_Catcher (iPhone target only)
//
//  Interactive calibration: user lies in sleeping position, app plays cue
//  at increasing volumes, user taps when barely audible -> that's the threshold.
//  All REM cue volumes are computed relative to this threshold.

import Foundation
import AVFoundation
import Observation

// MARK: - Calibration Model

struct VolumeCalibration: Codable {
    /// Software volume (0.0-1.0) at which user reported barely hearing the cue
    var perceptualThreshold: Float

    /// System volume at calibration time (warn user if it changed)
    var systemVolumeAtCalibration: Float

    /// When calibration was performed (prompt re-calibration after ~7 days)
    var calibrationDate: Date

    /// Whether done in actual sleep environment (more reliable)
    var inSleepEnvironment: Bool

    // MARK: - Volume Computation

    func volume(atRatio ratio: Float) -> Float {
        max(0.0, min(1.0, perceptualThreshold * ratio))
    }

    var needsRecalibration: Bool {
        Date().timeIntervalSince(calibrationDate) > 7 * 24 * 3600
    }

    // MARK: - Persistence

    private static let key = "lucid_volume_calibration"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func load() -> VolumeCalibration? {
        guard let data = UserDefaults.standard.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(VolumeCalibration.self, from: data)
    }
}

// MARK: - Calibration Wizard

@Observable
final class VolumeCalibrationWizard {

    /// Current software volume (0.0–1.0), driven by the slider.
    var volume: Float = 0.05

    private let player: LucidCuePlayer
    static let minVolume: Float = 0.01
    static let maxVolume: Float = 0.50

    init(player: LucidCuePlayer) {
        self.player = player
    }

    var playerIsReady: Bool { player.isReady }

    func ensurePlayerReady() throws {
        if !player.isReady {
            try player.setup()
        }
    }

    func teardownPlayer() {
        player.teardown()
    }

    /// Play the cue at the current volume. Called when slider value changes.
    func playAtCurrentVolume() {
        player.playCue(atVolume: volume)
    }

    /// Save the current volume as the perceptual threshold.
    func saveCalibration() -> VolumeCalibration {
        let systemVol = AVAudioSession.sharedInstance().outputVolume

        let cal = VolumeCalibration(
            perceptualThreshold: volume,
            systemVolumeAtCalibration: systemVol,
            calibrationDate: Date(),
            inSleepEnvironment: true
        )
        cal.save()
        return cal
    }
}
