//  CalibrationView.swift
//  Dream_Catcher
//
//  Volume calibration wizard UI.
//  User lies in sleeping position -> taps Play -> taps "Louder" until
//  they can barely hear it -> taps "I can hear it" -> threshold saved.
//
//  Dark UI matching the training screen aesthetic.

import SwiftUI

struct CalibrationView: View {

    @State var wizard: VolumeCalibrationWizard
    @Binding var calibration: VolumeCalibration?
    var onComplete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var hasPlayed = false
    @State private var showSuccess = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showSuccess {
                successView
            } else {
                calibrationContent
            }
        }
        .preferredColorScheme(.dark)
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

            Text("Lie in your sleeping position.\nTap Play to hear your dream signal.\nTap Louder until you can barely hear it.")
                .font(.system(size: 15, weight: .light))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 48)

            volumeBar

            Spacer()
                .frame(height: 48)

            controlButtons

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

    // MARK: - Volume Bar

    private var volumeBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "6366F1").opacity(0.6),
                                    Color(hex: "818CF8").opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * stepFraction,
                            height: 6
                        )
                        .animation(.easeOut(duration: 0.3), value: wizard.currentStep)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 48)

            Text("Step \(wizard.currentStep + 1) of 20")
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.15))
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button {
                _ = wizard.playCurrentStep()
                hasPlayed = true
                pulseAnimation()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: hasPlayed ? "arrow.clockwise" : "play.fill")
                        .font(.system(size: 14))
                    Text(hasPlayed ? "Replay" : "Play")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 100, height: 44)
                .background(Color.white.opacity(0.08))
                .cornerRadius(22)
            }

            Button {
                if wizard.nextStep() {
                    _ = wizard.playCurrentStep()
                    hasPlayed = true
                    pulseAnimation()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.plus")
                        .font(.system(size: 14))
                    Text("Louder")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 100, height: 44)
                .background(Color.white.opacity(0.08))
                .cornerRadius(22)
            }
            .disabled(!hasPlayed)
            .opacity(hasPlayed ? 1 : 0.3)

            Button {
                calibration = wizard.userHeardCue()
                withAnimation(.easeOut(duration: 0.5)) {
                    showSuccess = true
                }
            } label: {
                Text("I hear it")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 44)
                    .background(Color(hex: "6366F1").opacity(hasPlayed ? 0.8 : 0.2))
                    .cornerRadius(22)
            }
            .disabled(!hasPlayed)
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

            Text("Your dream signal is set to the perfect volume --\njust at the edge of hearing.")
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

    // MARK: - Helpers

    private var stepFraction: CGFloat {
        CGFloat(wizard.currentStep) / 19.0
    }

    private func pulseAnimation() {
        withAnimation(.easeOut(duration: 0.15)) { pulseScale = 1.1 }
        withAnimation(.easeIn(duration: 0.3).delay(0.15)) { pulseScale = 1.0 }
    }
}
