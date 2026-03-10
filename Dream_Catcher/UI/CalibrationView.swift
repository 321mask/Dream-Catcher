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
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSuccess = false
    @State private var didSetupPlayer = false

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.9) : Color.black.opacity(0.82)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : Color.black.opacity(0.56)
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.2) : Color.black.opacity(0.32)
    }

    private var buttonTextColor: Color {
        colorScheme == .dark ? .white : Color(hex: "FEF7FE")
    }

    private var sliderIconColor: Color {
        colorScheme == .dark ? .white.opacity(0.3) : Color.black.opacity(0.42)
    }

    var body: some View {
        ZStack {
            AppBackground()

            if showSuccess {
                successView
            } else {
                calibrationContent
            }
        }
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
                    .font(.largeTitle)
                    .foregroundColor(Color(hex: "818CF8"))
                    .accessibilityHidden(true)

                Text("Calibrate Volume")
                    .font(.title2)
                    .foregroundColor(primaryTextColor)
            }

            Spacer()
                .frame(height: 40)

            Text("Lie in your sleeping position.\nDrag the slider until you can\nbarely hear the sound.")
                .font(.body)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundColor(secondaryTextColor)
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
                    .font(.headline)
                    .foregroundColor(buttonTextColor)
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
            .accessibilityHint("Closes calibration without saving")
            .foregroundColor(tertiaryTextColor)

            Spacer()
                .frame(height: 40)
        }
    }

    // MARK: - Volume Slider

    private var volumeSlider: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.footnote)
                    .foregroundColor(sliderIconColor)
                    .accessibilityHidden(true)

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
                    .font(.footnote)
                    .foregroundColor(sliderIconColor)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 36)

            Text("\(Int(wizard.volume * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundColor(tertiaryTextColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int(wizard.volume * 100)) percent")
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundColor(Color(hex: "818CF8"))
                .accessibilityHidden(true)

            Text("Calibration saved")
                .font(.title3)
                .foregroundColor(primaryTextColor)

            Text("Your dream signal is set to the perfect volume —\njust at the edge of hearing.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(secondaryTextColor)

            Spacer()

            Button {
                if let onComplete {
                    onComplete()
                } else {
                    dismiss()
                }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(buttonTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "6366F1").opacity(0.7))
                    .cornerRadius(25)
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 48)
            .accessibilityHint("Finishes calibration")
        }
    }
}
