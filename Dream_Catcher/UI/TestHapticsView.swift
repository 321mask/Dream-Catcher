import SwiftUI

struct TestHapticsView: View {
    // 0 = 1× pattern, 1 = 2× pattern, 2 = 3× pattern
    @AppStorage("hapticStrength") private var strength: Double = 1.0
    @Environment(\.dismiss) private var dismiss

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
                            .onChange(of: strength) { _, newValue in
                                PhoneWatchSync.shared.send(["command": "setHapticStrength", "value": Int(newValue)])
                            }

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
            .appBackground()
            .navigationTitle("Test Haptics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func label(for level: Int) -> String {
        switch level {
        case 0: return "Light (1× pattern)"
        case 2: return "Strong (3× pattern)"
        default: return "Medium (2× pattern)"
        }
    }

    private func sendToWatch(level: Int) {
        PhoneWatchSync.shared.send(["command": "setHapticStrength", "value": level])
        PhoneWatchSync.shared.send(["command": "playSavedStrength"])
    }
}

