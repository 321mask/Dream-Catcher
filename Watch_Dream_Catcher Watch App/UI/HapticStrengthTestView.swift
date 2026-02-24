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
        .navigationTitle("Watch Haptic Test")
    }

    private func label(for value: Int) -> String {
        switch value {
        case 0: return "Light"
        case 2: return "Strong"
        default: return "Medium"
        }
    }

    private func playLocally() {
        isPlaying = true
        let type: WKHapticType
        switch strength {
        case 0: type = .click           // light
        case 2: type = .notification    // strong
        default: type = .directionUp    // medium
        }

        WKInterfaceDevice.current().play(type)
        lastPlayedAt = Date()

        // Brief UI busy state for feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPlaying = false
        }
    }
}
