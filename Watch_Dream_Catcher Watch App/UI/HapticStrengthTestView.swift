import SwiftUI
import WatchKit

struct HapticStrengthTestView: View {

    @State private var strength: Int = 1   // 0=Light, 1=Medium, 2=Strong
    @State private var lastPlayedAt: Date?
    @State private var isPlaying = false

    var body: some View {
        Form {
            Section("Haptic Strength") {
                // Use a Slider with stepped values (0,1,2) — works on watchOS
                VStack(spacing: 8) {
                    HStack {
                        Text("Light")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Medium")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Strong")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(strength) },
                            set: { strength = Int(round($0)) }
                        ),
                        in: 0...2,
                        step: 1
                    )
                    .tint(.purple)
                    .accessibilityLabel("Haptic strength")

                    HStack {
                        Text("Selected:")
                            .foregroundStyle(.secondary)
                        Text(label(for: strength))
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    playLocally()
                } label: {
                    HStack {
                        if isPlaying { ProgressView().padding(.trailing, 6) }
                        Text("Play on Watch")
                    }
                }
                .disabled(isPlaying)
                .accessibilityHint("Plays the selected strength on Apple Watch")
            } footer: {
                if let ts = lastPlayedAt {
                    Text("Last played: \(ts.formatted(date: .omitted, time: .standard))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Plays one tap on the watch at the selected strength.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func label(for value: Int) -> String {
        switch value {
        case 0: return "Light (1×)"
        case 2: return "Strong (3×)"
        default: return "Medium (2×)"
        }
    }

    private func playLocally() {
        isPlaying = true

        let repetitions = strength + 1  // 0→1, 1→2, 2→3
        let device = WKInterfaceDevice.current()
        let patternDuration: TimeInterval = 0.650

        for rep in 0..<repetitions {
            let base = Double(rep) * patternDuration
            let tap1 = base
            let tap2 = base + 0.225
            let tap3 = base + 0.450

            if tap1 == 0 {
                device.play(.click)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + tap1) {
                    device.play(.click)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + tap2) {
                device.play(.directionUp)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + tap3) {
                device.play(.notification)
            }
        }

        lastPlayedAt = Date()

        let totalDuration = Double(repetitions) * patternDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            isPlaying = false
        }
    }
}
