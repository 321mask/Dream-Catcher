//  LucidCuePlayer.swift
//  Dream_Catcher (iPhone target only)
//
//  AVAudioEngine-based player with:
//  - Precise software volume control (0.0–1.0)
//  - Smooth fade-in to prevent awakening
//  - Silent-loop background keepalive for overnight operation

import AVFoundation

final class LucidCuePlayer {

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var cueBuffer: AVAudioPCMBuffer?
    private(set) var isReady = false
    private var silencePlayer: AVAudioPlayer?

    // MARK: - Setup

    /// Configure AVAudioSession for background playback that works with Sleep Focus.
    /// Call once when entering sleep mode.
    func setup() throws {
        let session = AVAudioSession.sharedInstance()

        // .playback = background audio allowed
        // .duckOthers = lower other apps instead of stopping them
        try session.setCategory(
            .playback,
            mode: .default,
            options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
        )
        try session.setActive(true)

        guard let buffer = LucidCueAudioGenerator().generateCueBuffer() else {
            throw PlayerError.bufferGenerationFailed
        }
        self.cueBuffer = buffer

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)
        try engine.start()
        isReady = true
    }

    // MARK: - Playback

    /// Play the cue at exact volume. Used during calibration.
    /// Stops any currently playing cue first so buffers don't pile up.
    func playCue(atVolume volume: Float) {
        guard isReady, let buffer = cueBuffer else { return }
        playerNode.stop()
        playerNode.volume = clamp(volume)
        playerNode.scheduleBuffer(buffer, at: nil, options: [])
        playerNode.play()
    }

    /// Play with a smooth ramp from silence to target volume.
    /// This prevents the jarring onset that wakes sleepers.
    /// Research: gradual onset significantly reduces arousal probability.
    func playCueWithFadeIn(
        targetVolume: Float,
        fadeDuration: TimeInterval = 0.15
    ) {
        guard isReady, let buffer = cueBuffer else { return }

        let target = clamp(targetVolume)
        playerNode.volume = 0.0

        playerNode.scheduleBuffer(buffer, at: nil, options: [])
        if !playerNode.isPlaying { playerNode.play() }

        // Ramp volume in 15 steps over fadeDuration
        let steps = 15
        let stepInterval = fadeDuration / Double(steps)
        let volumeStep = target / Float(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepInterval * Double(i)) {
                [weak self] in
                self?.playerNode.volume = volumeStep * Float(i)
            }
        }
    }

    func stopCue() {
        playerNode.stop()
    }

    // MARK: - Background Keepalive

    /// Play a silent loop to prevent iOS from suspending the app overnight.
    /// This is the standard pattern for sleep/alarm apps.
    /// Requires "Audio, AirPlay and Picture in Picture" background mode in Info.plist.
    func startBackgroundKeepalive() throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100, channels: 1, interleaved: false
        )!
        let silenceBuf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        silenceBuf.frameLength = 44100 // 1 second of silence

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("_silence.caf")
        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try file.write(from: silenceBuf)

        silencePlayer = try AVAudioPlayer(contentsOf: url)
        silencePlayer?.numberOfLoops = -1  // infinite loop
        silencePlayer?.volume = 0.0
        silencePlayer?.play()
    }

    func stopBackgroundKeepalive() {
        silencePlayer?.stop()
        silencePlayer = nil
    }

    // MARK: - Cleanup

    func teardown() {
        playerNode.stop()
        engine.stop()
        stopBackgroundKeepalive()
        isReady = false
    }

    // MARK: - Private

    private func clamp(_ v: Float) -> Float { max(0.0, min(1.0, v)) }

    enum PlayerError: LocalizedError {
        case bufferGenerationFailed
        var errorDescription: String? { "Failed to generate audio cue buffer" }
    }
}
