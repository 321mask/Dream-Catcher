//
//  HapticsControlView.swift
//  Watch_Dream_Catcher Watch App
//
//  Simple tester for Watch haptics using WKInterfaceDevice.
//

import SwiftUI
import WatchKit

struct HapticsControlView: View {
    // 0 = light, 1 = medium, 2 = strong
    @State private var strengthIndex: Int = 1
    @State private var lastPlayedDescription: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Haptics Test")
                .font(.system(size: 16, weight: .semibold))

            VStack(spacing: 8) {
                HStack {
                    Text("Strength")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(currentLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }

                Slider(value: Binding(
                    get: { Double(strengthIndex) },
                    set: { strengthIndex = Int(round($0)) }
                ), in: 0...2, step: 1)
                .tint(.purple)

                HStack {
                    Text("Light")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Medium")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Strong")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Button {
                playSelected()
            } label: {
                Label("Play", systemImage: "hand.tap")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)

            if let desc = lastPlayedDescription {
                Text("Played: \(desc)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
    }

    private var currentLabel: String {
        switch strengthIndex {
        case 0: return "Light"
        case 1: return "Medium"
        default: return "Strong"
        }
    }

    private func playSelected() {
        let device = WKInterfaceDevice.current()
        let type: WKHapticType
        switch strengthIndex {
        case 0:
            type = .click          // light
        case 1:
            type = .directionUp    // medium-ish
        default:
            type = .notification   // strong
        }
        device.play(type)
        lastPlayedDescription = currentLabel
    }
}
