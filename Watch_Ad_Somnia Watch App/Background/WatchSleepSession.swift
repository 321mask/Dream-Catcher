//
//  WatchSleepSession.swift
//  Watch_Dream_Catcher Watch App
//
//  Keeps the watch app running through the night via the `audio` background
//  mode. A looping low-volume ambient sleep sound is rendered in-process by
//  AVAudioEngine; while the engine is rendering, watchOS keeps the process
//  scheduled, so WatchCueScheduler's poll timer keeps firing and haptic cues
//  can be delivered via WKInterfaceDevice.
//
//  AVAudioPlayer is deliberately NOT used here: under the long-form audio
//  policy the system renders AVAudioPlayer content out of process and may
//  suspend the app — the sound keeps playing but timers and haptics stop.
//  In-process rendering is what actually keeps the app alive overnight.
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

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    /// Invalidates stale scheduleFile completion handlers after a stop or
    /// restart so they can't double-schedule loop passes.
    private var loopGeneration = 0
    /// Number of file passes currently queued on the player node.
    private var pendingLoopPasses = 0
    private var isRecovering = false

    private var manuallyStarted = false
    private var sleepSessionRequested = false
    private var isStarting = false

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        // Fires when the output route changes (e.g. AirPods battery dies and
        // playback falls back to the watch speaker). The engine stops itself
        // when this happens and must be restarted.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEngineConfigurationChange(_:)),
            name: .AVAudioEngineConfigurationChange,
            object: nil
        )
    }

    private func ensureMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }

    // MARK: - Interruption / Route Change Recovery

    /// AVAudioSession interrupts on phone calls, Siri, alarms, etc. The system
    /// stops our engine; restart it when the interruption ends. If recovery
    /// fails here, the WatchCueScheduler poll watchdog keeps retrying.
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

        switch type {
        case .began:
            break
        case .ended:
            ensureMain {
                self.recoverPlaybackIfNeeded()
            }
        @unknown default:
            break
        }
    }

    @objc private func handleEngineConfigurationChange(_ notification: Notification) {
        ensureMain {
            guard let engine = self.audioEngine,
                  (notification.object as? AVAudioEngine) === engine else { return }
            self.recoverPlaybackIfNeeded()
        }
    }

    /// Watchdog entry point, called from WatchCueScheduler's 5s poll while a
    /// session is live. Cheap when healthy; restarts the engine after
    /// interruptions, route changes, or a drained loop queue.
    func ensureAudioAlive() {
        ensureMain {
            self.recoverPlaybackIfNeeded()
        }
    }

    private func recoverPlaybackIfNeeded() {
        guard sleepSessionRequested, !isRecovering, !isStarting else { return }
        guard let engine = audioEngine, let node = playerNode else { return }
        if engine.isRunning && pendingLoopPasses > 0 {
            if state != .active { state = .active }
            return
        }

        isRecovering = true
        AVAudioSession.sharedInstance().activate(options: []) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRecovering = false
                guard self.sleepSessionRequested else { return }
                guard success else {
                    // Keep the session requested — the next poll retries.
                    self.state = .error(error?.localizedDescription ?? "Audio session lost; retrying…")
                    return
                }
                do {
                    if !engine.isRunning {
                        engine.prepare()
                        try engine.start()
                    }
                    self.loopGeneration += 1
                    self.pendingLoopPasses = 0
                    node.stop()
                    self.scheduleLoopPasses(2)
                    node.play()
                    node.volume = Self.preferredAmbientVolume()
                    self.state = .active
                } catch {
                    self.state = .error("Audio restart failed: \(error.localizedDescription)")
                }
            }
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
            self.finishStopped()
        }
    }

    /// Update the ambient volume while a session is live. Called from the
    /// settings UI. Persists the value to UserDefaults for next session.
    func setAmbientVolume(_ value: Float) {
        let clamped = max(0.0, min(1.0, value))
        UserDefaults.standard.set(Double(clamped), forKey: Self.ambientVolumeDefaultsKey)
        playerNode?.volume = clamped
    }

    // MARK: - Audio Session

    private func startAudioSessionIfNeeded() {
        guard audioEngine == nil else { return }

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
            // .longForm route sharing policy is required for background
            // audio on watchOS — the system routes playback to a Bluetooth
            // audio device (AirPods, etc) and keeps the app alive while
            // audio is playing.
            try session.setCategory(
                .playback,
                mode: .default,
                policy: .longFormAudio,
                options: []
            )
        } catch {
            isStarting = false
            state = .error("Audio category failed: \(error.localizedDescription)")
            sleepSessionRequested = false
            WatchSessionManager.shared.publishSleepSessionState(isActive: false)
            return
        }

        // watchOS requires asynchronous activation for long-form playback.
        // If no Bluetooth route is connected, the system presents a route
        // picker; cancelling it (or having no route available) fails the
        // activation.
        session.activate(options: []) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.sleepSessionRequested else {
                    // User stopped the session before activation completed.
                    try? AVAudioSession.sharedInstance().setActive(
                        false,
                        options: [.notifyOthersOnDeactivation]
                    )
                    return
                }
                if success {
                    self.beginAudioPlayback(url: url)
                } else {
                    self.isStarting = false
                    let message = error?.localizedDescription
                        ?? "Connect AirPods or another Bluetooth audio device, then try again."
                    self.state = .error(message)
                    self.sleepSessionRequested = false
                    WatchSessionManager.shared.publishSleepSessionState(isActive: false)
                }
            }
        }
    }

    private func beginAudioPlayback(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            let engine = AVAudioEngine()
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
            engine.prepare()
            try engine.start()

            audioEngine = engine
            playerNode = node
            node.volume = Self.preferredAmbientVolume()

            loopGeneration += 1
            pendingLoopPasses = 0
            scheduleLoopPasses(2)
            node.play()

            isStarting = false
            sessionStartTime = sessionStartTime ?? Date()
            state = .active
            WatchCueScheduler.shared.hasLiveSession = true
        } catch {
            audioEngine?.stop()
            audioEngine = nil
            playerNode = nil
            isStarting = false
            state = .error(error.localizedDescription)
            sleepSessionRequested = false
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
            WatchSessionManager.shared.publishSleepSessionState(isActive: false)
        }
    }

    /// Keeps the ambient loop queued ahead on the player node. Each pass
    /// opens its own AVAudioFile — re-scheduling a single instance corrupts
    /// its read position while a previous pass is still draining. Two passes
    /// stay queued so playback survives a delayed completion callback; if the
    /// queue drains anyway, the ensureAudioAlive watchdog refills it.
    private func scheduleLoopPasses(_ count: Int) {
        guard let node = playerNode, let url = Self.ambientAudioURL() else { return }
        let generation = loopGeneration
        for _ in 0..<count {
            guard let file = try? AVAudioFile(forReading: url) else { continue }
            pendingLoopPasses += 1
            node.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    guard let self, generation == self.loopGeneration else { return }
                    self.pendingLoopPasses -= 1
                    guard self.sleepSessionRequested else { return }
                    self.scheduleLoopPasses(1)
                }
            }
        }
    }

    private func finishStopped() {
        loopGeneration += 1
        pendingLoopPasses = 0
        playerNode?.stop()
        audioEngine?.stop()
        playerNode = nil
        audioEngine = nil

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )

        isStarting = false
        isRecovering = false
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
