//  GammaEntrainmentGenerator.swift
//  Dream_Catcher (iPhone target only)
//
//  EXPERIMENTAL: 40Hz amplitude-modulated pink noise for gamma entrainment.
//
//  Scientific basis:
//  - Voss et al. (2014, Nature Neuroscience): 40Hz tACS during REM induced
//    lucid dreaming in ~77% of stimulated dreams
//  - Nir et al. (2022, Nature Neuroscience): auditory 40Hz entrainment
//    persists during REM sleep, reaching prefrontal cortex
//  - MIT GENUS research: 40Hz auditory stimulation entrains gamma in
//    hippocampus and medial prefrontal cortex
//
//  IMPORTANT: No study has directly tested auditory 40Hz for lucid dreaming.
//  This is theoretically grounded but experimentally unvalidated.
//  Position as an experimental/optional feature in the app.
//
//  Implementation: pink noise with its amplitude modulated at 40Hz.
//  This works through iPhone speakers (unlike a pure 40Hz sine wave,
//  which is below the speaker's frequency response cutoff of ~200Hz).

import AVFoundation

final class GammaEntrainmentGenerator {

    private let sampleRate: Double = 44100.0
    private let modulationFreq: Double = 40.0  // Hz — the gamma target

    /// Generate a loopable buffer of 40Hz AM pink noise.
    ///
    /// - Parameters:
    ///   - duration: Buffer length in seconds (will be looped during playback)
    ///   - gain: Master gain (0.0–1.0). Default 0.25 is very quiet.
    /// - Returns: PCM buffer ready for AVAudioPlayerNode
    func generateBuffer(
        duration: TimeInterval = 30.0,
        gain: Float = 0.25
    ) -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        let totalSamples = Int(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(totalSamples)
        ) else { return nil }

        buffer.frameLength = AVAudioFrameCount(totalSamples)
        guard let data = buffer.floatChannelData?[0] else { return nil }

        // Pink noise via Voss-McCartney algorithm
        var accumulator: Float = 0
        var rows = [Float](repeating: 0, count: 16)

        for i in 0..<totalSamples {
            // White noise source
            let white = Float.random(in: -1...1)

            // Update one row per sample based on trailing zeros
            // (different rows update at different rates → 1/f spectrum)
            let rowIdx = (i + 1).trailingZeroBitCount
            if rowIdx < rows.count {
                accumulator -= rows[rowIdx]
                rows[rowIdx] = Float.random(in: -1...1)
                accumulator += rows[rowIdx]
            }

            let pink = (accumulator + white) / Float(rows.count + 1)

            // 40Hz amplitude modulation:
            // modulator oscillates between 0 and 1 at 40 Hz
            let t = Double(i) / sampleRate
            let modulator = Float(
                0.5 + 0.5 * sin(2.0 * .pi * modulationFreq * t)
            )

            data[i] = pink * modulator * gain
        }

        return buffer
    }
}
