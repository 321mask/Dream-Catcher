//  PreSleepTrainingView.swift
//  Dream_Catcher
//
//  The screen users see as they fall asleep during TLR conditioning.
//
//  Design philosophy:
//  - AMOLED black background (true black saves battery, minimal light)
//  - Text fades in/out gently -- no jarring transitions
//  - Pulsing ring visualizes the cue rhythm
//  - Minimal chrome -- no nav bars, no buttons after start
//  - Auto-dims further over time (text opacity decreases)
//  - Screen stays on via .persistentSystemOverlays(.hidden) at minimum brightness

import SwiftUI

struct PreSleepTrainingView: View {

    var session: PreSleepTrainingSession
    var onTrainingCompleted: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    // Animation state
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var buttonsDimmed = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {

                Spacer()

                cueRing
                    .frame(height: 200)

                Spacer()
                    .frame(height: 48)

                instructionText

                Spacer()

                progressIndicator
                    .padding(.bottom, 24)

                bottomButtons
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 32)

            // Close button (top-right, always accessible)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        session.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(buttonsDimmed ? 0.1 : 0.3))
                            .frame(width: 44, height: 44)
                    }
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            // Dim buttons after 30s so they don't distract, but remain tappable
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                withAnimation(.easeOut(duration: 2.0)) {
                    buttonsDimmed = true
                }
            }
        }
        .onChange(of: session.state) { oldState, newState in
            if case .completed = newState {
                withAnimation(.easeOut(duration: 3.0)) {
                    textOpacity = 0
                    ringOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    onTrainingCompleted?()
                    dismiss()
                }
            }
        }
        .onChange(of: session.cueDeliveryCount) { _, _ in
            pulseRing()
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        Button {
            session.skipToNextCue()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11))
                Text("Next Cue")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white.opacity(buttonsDimmed ? 0.1 : 0.3))
        }
    }

    // MARK: - Cue Ring

    private var cueRing: some View {
        ZStack {
            Circle()
                .stroke(
                    Color(hex: "6366F1").opacity(ringOpacity * 0.3),
                    lineWidth: 2
                )
                .frame(width: 160, height: 160)
                .scaleEffect(ringScale * 1.2)

            Circle()
                .stroke(
                    Color(hex: "818CF8").opacity(ringOpacity * 0.6),
                    lineWidth: 3
                )
                .frame(width: 120, height: 120)
                .scaleEffect(ringScale)

            Circle()
                .fill(Color(hex: "A5B4FC").opacity(ringOpacity * 0.8))
                .frame(width: 8, height: 8)
                .scaleEffect(ringScale)
        }
    }

    // MARK: - Instruction Text

    private var instructionText: some View {
        Text(session.currentInstruction)
            .font(.system(size: 15, weight: .light, design: .serif))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .foregroundColor(.white.opacity(dimmedTextOpacity))
            .animation(.easeInOut(duration: 1.5), value: session.currentInstruction)
            .frame(minHeight: 80)
    }

    // MARK: - Progress

    private var progressIndicator: some View {
        Group {
            if case .running(let cues, let elapsed) = session.state {
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 2)

                            Rectangle()
                                .fill(Color(hex: "818CF8").opacity(0.4))
                                .frame(
                                    width: geo.size.width * progressFraction(elapsed),
                                    height: 2
                                )
                                .animation(.linear(duration: 1.0), value: elapsed)
                        }
                    }
                    .frame(height: 2)

                    Text(timeRemaining(elapsed))
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(0.15))
                }
            }
        }
    }

    // MARK: - Animation

    private func pulseRing() {
        withAnimation(.easeOut(duration: 0.3)) {
            ringScale = 1.3
            ringOpacity = 1.0
        }
        withAnimation(.easeIn(duration: 0.8).delay(0.3)) {
            ringScale = 1.0
        }
        withAnimation(.easeOut(duration: 2.0).delay(0.5)) {
            ringOpacity = 0.2
        }
    }

    // MARK: - Helpers

    private var dimmedTextOpacity: Double {
        guard case .running(_, let elapsed) = session.state else { return 0.35 }
        let sessionFraction = elapsed / session.sessionDuration
        // Text starts dim (voice is primary) and fades to near-invisible
        return 0.35 - (sessionFraction * 0.25)
    }

    private func progressFraction(_ elapsed: TimeInterval) -> CGFloat {
        CGFloat(elapsed / session.sessionDuration)
    }

    private func timeRemaining(_ elapsed: TimeInterval) -> String {
        let remaining = max(0, Int(session.sessionDuration - elapsed))
        let min = remaining / 60
        let sec = remaining % 60
        return "\(min):\(String(format: "%02d", sec)) remaining"
    }
}


