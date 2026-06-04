//  REMCueScheduler.swift
//  Dream_Catcher (iPhone target only)
//
//  Replaces UNNotification-based cue scheduling with real-time adaptive delivery.
//
//  Why this replaces the old approach:
//  - UNNotificationRequest has unreliable timing (+/- seconds)
//  - .default notification sound cannot be volume-controlled
//  - No way to implement progressive volume ramping
//  - No motion-aware pausing
//
//  This uses AVAudioEngine for precise volume control and responds to
//  real-time Watch signals for motion/awakening detection.
//
//  Flow:
//   Watch REM classifier -> "remDetected" -> iPhone starts cue loop
//   Watch accelerometer  -> "motionDetected" -> pause 5 minutes
//   Watch HR spike       -> "awakeningDetected" -> pause 45 minutes

import Foundation
import Observation

@Observable
final class REMCueScheduler {

    // MARK: - State

    enum SchedulerState: Equatable {
        case idle
        case waitingForREM
        case delayingForStableREM
        case delivering(window: Int, cue: Int)
        case pausedForMotion
        case pausedForAwakening
        case nightComplete
    }

    private(set) var state: SchedulerState = .idle
    private(set) var cuesDeliveredTonight: Int = 0

    // MARK: - Configuration

    struct Config {
        var remOnsetDelay: TimeInterval = 5 * 60
        var cueInterval: TimeInterval = 30.0
        var initialVolumeRatio: Float = 0.70
        var volumeIncrement: Float = 0.002
        var maxVolumeRatio: Float = 1.15
        var maxCuesPerWindow: Int = 20
        var maxWindowsPerNight: Int = 3
        var motionPause: TimeInterval = 5 * 60
        var awakeningPause: TimeInterval = 45 * 60
        var minSleepHoursBeforeCueing: Double = 4.5
    }

    let config: Config

    // MARK: - Callbacks

    var onTriggerWatchHaptic: (() -> Void)?
    var onCueDelivered: ((CueEvent) -> Void)?

    // MARK: - Dependencies

    private let player: LucidCuePlayer
    private let calibration: VolumeCalibration

    private var cueTimer: Timer?
    private var windowIndex = 0
    private var cueIndex = 0
    private var volumeRatio: Float = 0.0
    private var sleepStartTime: Date?

    private(set) var nightLog: [CueEvent] = []

    // MARK: - Init

    init(
        player: LucidCuePlayer,
        calibration: VolumeCalibration,
        config: Config = Config()
    ) {
        self.player = player
        self.calibration = calibration
        self.config = config
    }

    // MARK: - Night Lifecycle

    func startNight() {
        sleepStartTime = Date()
        windowIndex = 0
        cueIndex = 0
        cuesDeliveredTonight = 0
        nightLog = []
        state = .waitingForREM
    }

    func stopNight() {
        stopTimer()
        state = .nightComplete
    }

    // MARK: - Signals from Watch

    func remDetected() {
        guard state == .waitingForREM else { return }

        guard windowIndex < config.maxWindowsPerNight else {
            state = .nightComplete; return
        }

        if let start = sleepStartTime {
            let hours = Date().timeIntervalSince(start) / 3600.0
            guard hours >= config.minSleepHoursBeforeCueing else { return }
        }

        state = .delayingForStableREM
        logEvent(.remWindowStarted(windowIndex: windowIndex))

        DispatchQueue.main.asyncAfter(deadline: .now() + config.remOnsetDelay) {
            [weak self] in
            guard let self, self.state == .delayingForStableREM else { return }
            self.beginCueDelivery()
        }
    }

    func motionDetected() {
        guard case .delivering = state else { return }
        stopTimer()
        state = .pausedForMotion
        logEvent(.pausedForMotion)

        DispatchQueue.main.asyncAfter(deadline: .now() + config.motionPause) {
            [weak self] in self?.state = .waitingForREM
        }
    }

    func awakeningDetected() {
        stopTimer()
        windowIndex += 1
        state = .pausedForAwakening
        logEvent(.pausedForAwakening)

        DispatchQueue.main.asyncAfter(deadline: .now() + config.awakeningPause) {
            [weak self] in
            guard let self else { return }
            self.state = self.windowIndex < self.config.maxWindowsPerNight
                ? .waitingForREM : .nightComplete
        }
    }

    func remEnded() {
        guard case .delivering = state else { return }
        stopTimer()
        windowIndex += 1
        state = windowIndex < config.maxWindowsPerNight
            ? .waitingForREM : .nightComplete
    }

    // MARK: - Delivery Engine

    private func beginCueDelivery() {
        cueIndex = 0
        volumeRatio = config.initialVolumeRatio
        state = .delivering(window: windowIndex, cue: 0)

        deliverOneCue()

        cueTimer = Timer.scheduledTimer(
            withTimeInterval: config.cueInterval,
            repeats: true
        ) { [weak self] _ in
            self?.deliverOneCue()
        }
    }

    private func deliverOneCue() {
        guard case .delivering = state else { stopTimer(); return }

        guard cueIndex < config.maxCuesPerWindow else {
            stopTimer()
            windowIndex += 1
            state = windowIndex < config.maxWindowsPerNight
                ? .waitingForREM : .nightComplete
            return
        }

        let vol = calibration.volume(
            atRatio: min(volumeRatio, config.maxVolumeRatio)
        )

        player.playCueWithFadeIn(targetVolume: vol, fadeDuration: 0.15)

        onTriggerWatchHaptic?()

        let event = CueEvent.cueDelivered(
            volume: vol,
            cueIndex: cueIndex,
            windowIndex: windowIndex
        )
        logEvent(event)
        onCueDelivered?(event)
        cuesDeliveredTonight += 1

        cueIndex += 1
        volumeRatio += config.volumeIncrement
        state = .delivering(window: windowIndex, cue: cueIndex)
    }

    private func stopTimer() {
        cueTimer?.invalidate()
        cueTimer = nil
    }

    // MARK: - Logging

    enum CueEvent {
        case cueDelivered(volume: Float, cueIndex: Int, windowIndex: Int)
        case remWindowStarted(windowIndex: Int)
        case pausedForMotion
        case pausedForAwakening
    }

    private func logEvent(_ event: CueEvent) {
        nightLog.append(event)
    }
}
