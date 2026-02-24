import SwiftUI

struct TestHapticsView: View {
    // 0 = light (.click), 1 = medium (.directionUp), 2 = strong (.notification)
    @State private var strength: Double = 1.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Strength") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Light")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Strong")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $strength, in: 0...2, step: 1)
                            .tint(.purple)

                        HStack {
                            Text("Selected:")
                                .foregroundStyle(.secondary)
                            Text(label(for: Int(strength)))
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        sendToWatch(level: Int(strength))
                    } label: {
                        Label("Play on Watch", systemImage: "applewatch")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                } footer: {
                    Text("Watch must be reachable. Open the Watch app to enable live messaging.")
                }
            }
            .navigationTitle("Test Haptics")
        }
    }

    private func label(for level: Int) -> String {
        switch level {
        case 0: return "Light"
        case 2: return "Strong"
        default: return "Medium"
        }
    }

    private func sendToWatch(level: Int) {
        // Persist the chosen strength on the watch, then play it immediately.
        PhoneWatchSync.shared.send(["command": "setHapticStrength", "value": level])
        PhoneWatchSync.shared.send(["command": "playSavedStrength"])
    }
}

