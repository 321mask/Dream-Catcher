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

    var currentStep: Int = 0
    var isComplete = false

    private let player: LucidCuePlayer
    private let totalSteps = 20
    private let startVolume: Float = 0.01
    private let endVolume: Float = 0.40

    init(player: LucidCuePlayer) {
        self.player = player
    }

    func playCurrentStep() -> Float {
        let volume = volumeForStep(currentStep)
        player.playCue(atVolume: volume)
        return volume
    }

    @discardableResult
    func nextStep() -> Bool {
        currentStep += 1
        if currentStep >= totalSteps {
            isComplete = true
            return false
        }
        return true
    }

    func userHeardCue() -> VolumeCalibration {
        let threshold = volumeForStep(currentStep)
        let systemVol = AVAudioSession.sharedInstance().outputVolume

        let cal = VolumeCalibration(
            perceptualThreshold: threshold,
            systemVolumeAtCalibration: systemVol,
            calibrationDate: Date(),
            inSleepEnvironment: true
        )
        cal.save()
        return cal
    }

    func reset() {
        currentStep = 0
        isComplete = false
    }

    // MARK: - Private

    private func volumeForStep(_ step: Int) -> Float {
        let fraction = Float(step) / Float(totalSteps - 1)
        return startVolume + fraction * (endVolume - startVolume)
    }
}
