//  LucidCueAudioGenerator.swift
//  Dream_Catcher (iPhone target only)
//
//  Synthesizes the TLR three-tone audio cue as a PCM buffer.
//  No audio files needed — tones are generated mathematically.

import AVFoundation

final class LucidCueAudioGenerator {

    private let sampleRate: Double = 44100.0

    // MARK: - Buffer Generation

    /// Generate the three-tone cue as an AVAudioPCMBuffer.
    /// Each tone is a sine wave with quadratic fade-in/out to prevent clicks.
    func generateCueBuffer() -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        let totalSamples = Int(LucidCue.totalDuration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(totalSamples)
        ) else { return nil }

        buffer.frameLength = AVAudioFrameCount(totalSamples)
        guard let data = buffer.floatChannelData?[0] else { return nil }

        // Zero-fill
        for i in 0..<totalSamples { data[i] = 0.0 }

        // Write each tone
        var offset = 0
        for (index, freq) in LucidCue.frequencies.enumerated() {
            let toneSamples = Int(LucidCue.toneDuration * sampleRate)
            let fadeSamples = Int(LucidCue.fadeDuration * sampleRate)

            for i in 0..<toneSamples {
                let t = Double(i) / sampleRate
                var sample = Float(sin(2.0 * .pi * freq * t))

                // Quadratic fade-in
                if i < fadeSamples {
                    let fade = Float(i) / Float(fadeSamples)
                    sample *= fade * fade
                }

                // Quadratic fade-out
                let distFromEnd = toneSamples - 1 - i
                if distFromEnd < fadeSamples {
                    let fade = Float(distFromEnd) / Float(fadeSamples)
                    sample *= fade * fade
                }

                data[offset + i] = sample
            }

            offset += toneSamples
            if index < LucidCue.frequencies.count - 1 {
                offset += Int(LucidCue.gapDuration * sampleRate)
            }
        }

        return buffer
    }

    // MARK: - File Export

    /// Write the cue to a .caf file (useful for notification custom sounds).
    func writeCueToFile(filename: String = "lucid_cue.caf") -> URL? {
        guard let buffer = generateCueBuffer() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)

        guard let file = try? AVAudioFile(
            forWriting: url,
            settings: buffer.format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        ) else { return nil }

        do {
            try file.write(from: buffer)
            return url
        } catch {
            print("[LucidCueAudioGenerator] Write failed: \(error)")
            return nil
        }
    }
}
