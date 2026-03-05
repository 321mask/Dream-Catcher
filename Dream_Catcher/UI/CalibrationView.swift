//  CalibrationView.swift
//  Dream_Catcher
//
//  Volume calibration UI.
//  User lies in sleeping position, drags the slider until they can barely
//  hear the cue, then taps Save.  Each slider movement plays the cue at
//  the new volume so the user gets immediate feedback.
//
//  Dark UI matching the training screen aesthetic.

import SwiftUI

struct CalibrationView: View {

    @State var wizard: VolumeCalibrationWizard
    @Binding var calibration: VolumeCalibration?
    var onComplete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var showSuccess = false
    @State private var didSetupPlayer = false

    var body: some View {
        ZStack {
            AppBackground()

            if showSuccess {
                successView
            } else {
                calibrationContent
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !wizard.playerIsReady {
                do {
                    try wizard.ensurePlayerReady()
                    didSetupPlayer = true
                } catch {
                    print("CalibrationView: failed to setup audio – \(error)")
                }
            }
        }
        .onDisappear {
            if didSetupPlayer {
                wizard.teardownPlayer()
            }
        }
    }

    // MARK: - Main Content

    private var calibrationContent: some View {
        VStack(spacing: 0) {

            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundColor(Color(hex: "818CF8"))

                Text("Calibrate Volume")
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()
                .frame(height: 40)

            Text("Lie in your sleeping position.\nDrag the slider until you can\nbarely hear the sound.")
                .font(.system(size: 15, weight: .light))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 48)

            volumeSlider

            Spacer()
                .frame(height: 48)

            // Save button
            Button {
                calibration = wizard.saveCalibration()
                withAnimation(.easeOut(duration: 0.5)) {
                    showSuccess = true
                }
            } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 160, height: 50)
                    .background(Color(hex: "6366F1").opacity(0.8))
                    .cornerRadius(25)
            }

            Spacer()
                .frame(height: 16)

            Button("Skip for now") {
                dismiss()
            }
            .font(.system(size: 13, weight: .light))
            .foregroundColor(.white.opacity(0.2))

            Spacer()
                .frame(height: 40)
        }
    }

    // MARK: - Volume Slider

    private var volumeSlider: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.3))

                Slider(
                    value: $wizard.volume,
                    in: VolumeCalibrationWizard.minVolume...VolumeCalibrationWizard.maxVolume
                ) {
                    EmptyView()
                } onEditingChanged: { editing in
                    if !editing {
                        // User released the slider — play the cue once at the chosen volume.
                        wizard.playAtCurrentVolume()
                    }
                }
                .tint(Color(hex: "818CF8"))

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 36)

            Text("\(Int(wizard.volume * 100))%")
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.15))
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(Color(hex: "818CF8"))

            Text("Calibration saved")
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundColor(.white.opacity(0.8))

            Text("Your dream signal is set to the perfect volume —\njust at the edge of hearing.")
                .font(.system(size: 14, weight: .light))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.4))

            Spacer()

            Button {
                if let onComplete {
                    onComplete()
                } else {
                    dismiss()
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "6366F1").opacity(0.7))
                    .cornerRadius(25)
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 48)
        }
    }
}
