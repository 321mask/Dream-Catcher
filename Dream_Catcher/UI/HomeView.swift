import SwiftUI

struct HomeView: View {
    @Bindable var coordinator: AppCoordinator

    @State private var showCalibration = false
    @State private var showTraining = false
    @State private var sessionError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.62, green: 0.66, blue: 0.95),
                        Color(red: 0.98, green: 0.60, blue: 0.65)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()
                        .frame(height: 70)

                    Text(nextCueText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.bottom, 28)

                    Button {
                        handleMainButtonTap()
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.24))
                            .frame(width: 220, height: 220)
                            .overlay {
                                Group {
                                    if isSessionActive {
                                        Image("playOn")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 188, height: 188)
                                            .transition(.opacity)
                                    } else {
                                        Image("play")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 188, height: 188)
                                            .transition(.opacity)
                                    }
                                }
                                .clipShape(Circle())
                                .animation(.easeInOut(duration: 0.35), value: isSessionActive)
                            }
                    }

                    Text("Cues delivered: \(coordinator.watchCuesDeliveredTonight)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.top, 22)

                    if let sessionError {
                        Text(sessionError)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .padding(.top, 8)
                    }

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(coordinator: coordinator)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCalibration, onDismiss: {
                if coordinator.sleepPhase == .calibrating {
                    coordinator.sleepPhase = .idle
                }
            }) {
                CalibrationView(
                    wizard: VolumeCalibrationWizard(player: coordinator.cuePlayer),
                    calibration: $coordinator.calibration,
                    onComplete: {
                        showCalibration = false
                        startTrainingAfterCalibration()
                    }
                )
            }
            .fullScreenCover(isPresented: $showTraining) {
                if let session = coordinator.trainingSession {
                    PreSleepTrainingView(session: session) {
                        coordinator.trainingCompleted()
                    }
                }
            }
            .onChange(of: coordinator.sleepPhase) { _, newPhase in
                switch newPhase {
                case .calibrating:
                    showCalibration = true
                case .training:
                    showTraining = true
                case .monitoring:
                    showTraining = false
                    showCalibration = false
                case .idle:
                    showTraining = false
                    showCalibration = false
                }
            }
        }
    }

    private var isSessionActive: Bool {
        coordinator.sleepPhase != .idle
    }

    private var nextCueText: String {
        let now = Date()
        if let nextCue = coordinator.nextWindows
            .flatMap({ [$0.start, $0.end] })
            .filter({ $0 > now })
            .min() {
            return "Next cue: \(nextCue.formatted(date: .omitted, time: .shortened))"
        }
        return "Next cue: --"
    }

    private func handleMainButtonTap() {
        switch coordinator.sleepPhase {
        case .idle:
            do {
                try coordinator.beginSleepFlow()
            } catch {
                sessionError = error.localizedDescription
            }
        default:
            coordinator.endSleepSession()
        }
    }

    private func startTrainingAfterCalibration() {
        do {
            try coordinator.calibrationCompleted()
        } catch {
            sessionError = error.localizedDescription
            coordinator.sleepPhase = .idle
        }
    }
}

#Preview {
    HomeView(coordinator: AppCoordinator())
}
