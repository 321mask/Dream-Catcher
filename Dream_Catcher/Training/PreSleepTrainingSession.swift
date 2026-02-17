//  PreSleepTrainingSession.swift
//  Dream_Catcher (iPhone target only)
//
//  The TLR (Targeted Lucidity Reactivation) pre-sleep conditioning session.
//
//  This is the CRITICAL component that makes audio cues work.
//  Without this training, audio cues during REM are no better than control
//  (Carr et al., 2023). The training creates a learned association between
//  the cue and a "lucid mindset" -- metacognitive awareness.
//
//  Protocol:
//  1. User lies in bed, eyes closed, phone on nightstand, Watch on wrist
//  2. Every ~60s: audio cue (iPhone speaker) + haptic (Watch) fire together
//  3. Between cues: guided prompts cultivate CRITICAL AWARENESS (not relaxation)
//  4. After each cue: "That was your dream signal. When you hear/feel this
//     in a dream, you will know you are dreaming."
//  5. Session fades after 12 minutes; user drifts to sleep naturally
//  6. -> Night session begins, playing the SAME cue during detected REM

import Foundation
import Observation
import AVFoundation

@Observable
final class PreSleepTrainingSession {

    // MARK: - State

    enum SessionState: Equatable {
        case idle
        case running(cuesDelivered: Int, elapsed: TimeInterval)
        case completed

        static func == (lhs: SessionState, rhs: SessionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.completed, .completed): return true
            case let (.running(a1, a2), .running(b1, b2)): return a1 == b1 && a2 == b2
            default: return false
            }
        }
    }

    private(set) var state: SessionState = .idle
    private(set) var currentInstruction: String = ""
    /// Incremented each time a cue is delivered; observe with .onChange in views.
    private(set) var cueDeliveryCount: Int = 0

    // MARK: - Configuration

    var cueInterval: TimeInterval = 60.0
    var sessionDuration: TimeInterval = 3 * 60

    // MARK: - Callbacks

    var onTriggerWatchHaptic: (() -> Void)?
    var onCueDelivered: ((Int) -> Void)?

    // MARK: - Dependencies

    private let player: LucidCuePlayer
    private let calibration: VolumeCalibration
    private let speechSynth = AVSpeechSynthesizer()

    private var timer: Timer?
    private var startTime: Date?
    private var cuesDelivered = 0
    private var lastCueTime: Date?
    private var lastSpokenText: String?

    // MARK: - Init

    init(player: LucidCuePlayer, calibration: VolumeCalibration) {
        self.player = player
        self.calibration = calibration
    }

    // MARK: - Lifecycle

    func start() {
        guard case .idle = state else { return }

        startTime = Date()
        cuesDelivered = 0
        lastCueTime = nil
        state = .running(cuesDelivered: 0, elapsed: 0)

        deliverCue()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        speechSynth.stopSpeaking(at: .immediate)
        state = .completed
    }

    /// Skip the wait and deliver the next cue immediately.
    func skipToNextCue() {
        guard case .running = state else { return }
        deliverCue()
    }

    // MARK: - Tick

    private func tick() {
        guard let startTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)

        if elapsed >= sessionDuration {
            setInstruction(TrainingPrompts.sessionComplete)
            stop()
            return
        }

        state = .running(cuesDelivered: cuesDelivered, elapsed: elapsed)

        let sinceLast = lastCueTime.map { Date().timeIntervalSince($0) } ?? .infinity
        if sinceLast >= cueInterval {
            deliverCue()
        }

        updateInstruction(secondsSinceLastCue: sinceLast)
    }

    // MARK: - Cue Delivery

    private func deliverCue() {
        cuesDelivered += 1
        lastCueTime = Date()

        player.playCueWithFadeIn(
            targetVolume: calibration.volume(atRatio: 1.2)
        )

        onTriggerWatchHaptic?()
        onCueDelivered?(cuesDelivered)
        cueDeliveryCount += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.setInstruction(TrainingPrompts.postCueReinforcement)
        }
    }

    // MARK: - Guided Instructions

    private func updateInstruction(secondsSinceLastCue: TimeInterval) {
        let secs = Int(secondsSinceLastCue)
        guard secs % 10 == 0, secs > 3 else { return }

        let promptIndex = (secs / 10) % TrainingPrompts.awareness.count
        setInstruction(TrainingPrompts.awareness[promptIndex])
    }

    // MARK: - Speech

    private func setInstruction(_ text: String) {
        currentInstruction = text
        speak(text)
    }

    private func speak(_ text: String) {
        guard text != lastSpokenText else { return }
        lastSpokenText = text

        speechSynth.stopSpeaking(at: .word)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
        utterance.pitchMultiplier = 0.9
        utterance.volume = 0.6
        utterance.preUtteranceDelay = 0.3
        utterance.postUtteranceDelay = 0.2

        // Prefer a calm, natural-sounding voice
        if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Zoe") {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }

        speechSynth.speak(utterance)
    }
}

// MARK: - Training Prompts

private enum TrainingPrompts {

    static let postCueReinforcement =
        "That was your dream signal. Whenever you hear or feel this, ask yourself: am I dreaming?"

    static let sessionComplete =
        "Your training is complete. Let yourself drift into sleep. The signal will find you in your dreams..."

    static let awareness: [String] = [
        "Notice the weight of your body against the bed. Feel the texture of the sheets. Take note of every sensation.",
        "Ask yourself: how do I know this is real? Look for anything unusual. In a dream, something is always slightly off.",
        "Watch your thoughts as if sitting beside a river, watching them float by. Don't follow them. Just observe.",
        "Listen to the sounds around you. Notice the quality of the air. In a dream, these details feel subtly different.",
        "Tell yourself: tonight, when I hear my signal, I will realize I am dreaming. Hold this intention clearly.",
        "Notice that you are noticing. This ability to observe your own experience is exactly what lucid dreaming feels like.",
        "You can let yourself begin to drift. Your awareness will carry forward. The signal will reach you.",
        "Imagine you are already in a dream. What does it look like? Now imagine hearing your signal. You realize: this is a dream.",
    ]
}
