//
//  WatchSleepSession.swift
//  Watch_Dream_Catcher Watch App
//
//  Keeps the watch app running through the night via the `audio` background
//  mode. A looping low-volume ambient sleep sound is played through
//  AVAudioPlayer; while that audio session is active, the app stays alive
//  and WatchCueScheduler can deliver haptic cues via WKInterfaceDevice.
//

import AVFoundation
import Observation
import WatchKit

@Observable
final class WatchSleepSession: NSObject {

    static let shared = WatchSleepSession()

    enum SessionState: Equatable {
        case inactive
        case active
        case error(String)

        static func == (lhs: SessionState, rhs: SessionState) -> Bool {
            switch (lhs, rhs) {
            case (.inactive, .inactive), (.active, .active):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    enum SessionControlSource {
        case localWatch
        case remotePhone
        case `internal`
    }

    /// Filename (without extension) of the ambient sleep loop bundled with
    /// the Watch app. Drop the file into the Watch target with this name.
    private static let ambientAudioResource = "ambientSleep"
    private static let ambientAudioExtensions = ["m4a", "caf", "mp3", "wav"]

    /// UserDefaults key for the user-controlled ambient volume (0.0–1.0).
    static let ambientVolumeDefaultsKey = "watchAmbientVolume"
    /// Default volume if the user has never set one. Kept low so the watch
    /// speaker does not wake the sleeper.
    private static let defaultAmbientVolume: Float = 0.05

    private(set) var state: SessionState = .inactive
    private(set) var sessionStartTime: Date?

    /// Updated by iPhone via WCSession ("sleepFocusOn" / "sleepFocusOff").
    var isSleepFocusActive: Bool = false {
        didSet {
            if isSleepFocusActive && !oldValue {
                autoStartIfAppropriate()
            } else if !isSleepFocusActive && oldValue && !manuallyStarted {
                stop()
            }
        }
    }

    var isLive: Bool {
        state == .active
    }

    var isSessionRequested: Bool {
        sleepSessionRequested
    }

    var isBusyStarting: Bool {
        isStarting
    }

    private var audioPlayer: AVAudioPlayer?
    private var manuallyStarted = false
    private var sleepSessionRequested = false
    private var isStarting = false
    private var isStopping = false

    private func ensureMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }

    // MARK: - Public API

    func start(source: SessionControlSource = .internal) {
        ensureMain {
            guard !self.isLive, !self.isBusyStarting else { return }

            if source == .localWatch {
                WatchSessionManager.shared.sendStartSleepSessionToPhone()
            }

            self.manuallyStarted = true
            self.sleepSessionRequested = true
            WatchSessionManager.shared.publishSleepSessionState(isActive: true)
            self.startAudioSessionIfNeeded()
        }
    }

    func autoStartIfAppropriate() {
        ensureMain {
            guard !self.isLive, !self.isBusyStarting else { return }
            guard self.isSleepFocusActive || self.sleepSessionRequested else { return }

            self.manuallyStarted = false
            self.sleepSessionRequested = true
            WatchSessionManager.shared.publishSleepSessionState(isActive: true)
            self.startAudioSessionIfNeeded()
        }
    }

    func stop(source: SessionControlSource = .internal) {
        ensureMain {
            if source == .localWatch {
                WatchSessionManager.shared.sendStopSleepSessionToPhone()
            }

            self.sleepSessionRequested = false
            self.manuallyStarted = false
            WatchSessionManager.shared.publishSleepSessionState(isActive: false)

            guard self.audioPlayer != nil else {
                self.finishStopped()
                return
            }

            self.isStopping = true
            self.finishStopped()
        }
    }

    /// Update the ambient volume while a session is live. Called from the
    /// settings UI. Persists the value to UserDefaults for next session.
    func setAmbientVolume(_ value: Float) {
        let clamped = max(0.0, min(1.0, value))
        UserDefaults.standard.set(Double(clamped), forKey: Self.ambientVolumeDefaultsKey)
        audioPlayer?.volume = clamped
    }

    // MARK: - Audio Session

    private func startAudioSessionIfNeeded() {
        guard audioPlayer == nil else { return }

        guard let url = Self.ambientAudioURL() else {
            state = .error("Missing ambient audio asset")
            sleepSessionRequested = false
            isStarting = false
            WatchSessionManager.shared.publishSleepSessionState(isActive: false)
            return
        }

        isStarting = true

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            isStarting = false
            state = .error("Audio session failed: \(error.localizedDescription)")
            sleepSessionRequested = false
            WatchSessionManager.shared.publishSleepSessionState(isActive: false)
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = Self.preferredAmbientVolume()
            player.delegate = self
            player.prepareToPlay()

            guard player.play() else {
                throw NSError(
                    domain: "WatchSleepSession",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "AVAudioPlayer refused to play"]
                )
            }

            audioPlayer = player
            isStarting = false
            sessionStartTime = sessionStartTime ?? Date()
            state = .active
            WatchCueScheduler.shared.hasLiveSession = true
        } catch {
            isStarting = false
            state = .error(error.localizedDescription)
            sleepSessionRequested = false
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            WatchSessionManager.shared.publishSleepSessionState(isActive: false)
        }
    }

    private func finishStopped() {
        audioPlayer?.stop()
        audioPlayer?.delegate = nil
        audioPlayer = nil

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )

        isStarting = false
        isStopping = false
        state = .inactive
        sessionStartTime = nil
        WatchCueScheduler.shared.hasLiveSession = false
        WatchSessionManager.shared.publishSleepSessionState(isActive: false)
    }

    // MARK: - Helpers

    private static func ambientAudioURL() -> URL? {
        for ext in ambientAudioExtensions {
            if let url = Bundle.main.url(forResource: ambientAudioResource, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private static func preferredAmbientVolume() -> Float {
        let stored = UserDefaults.standard.object(forKey: ambientVolumeDefaultsKey) as? Double
        guard let stored else { return defaultAmbientVolume }
        return max(0.0, min(1.0, Float(stored)))
    }
}

// MARK: - AVAudioPlayerDelegate

extension WatchSleepSession: AVAudioPlayerDelegate {

    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        // We loop forever (numberOfLoops = -1), so reaching here means the
        // session was interrupted or the file ended unexpectedly. Try to
        // restart playback if we still want the session alive.
        let playerID = ObjectIdentifier(player)
        let errorMessage = "Ambient audio stopped"
        DispatchQueue.main.async {
            guard let current = self.audioPlayer,
                  ObjectIdentifier(current) == playerID,
                  self.sleepSessionRequested else { return }
            if !current.play() {
                self.state = .error(errorMessage)
                self.finishStopped()
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: (any Error)?
    ) {
        let playerID = ObjectIdentifier(player)
        let message = error?.localizedDescription ?? "Audio decode error"
        DispatchQueue.main.async {
            guard let current = self.audioPlayer,
                  ObjectIdentifier(current) == playerID else { return }
            self.state = .error(message)
            self.sleepSessionRequested = false
            self.finishStopped()
        }
    }
}
