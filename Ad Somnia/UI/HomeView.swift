import SwiftData
import SwiftUI

struct HomeView: View {

    @Bindable var coordinator: AppCoordinator

    @Query(sort: \SleepNight.sleepStart, order: .reverse)
    private var nights: [SleepNight]

    @State private var showCalibration = false
    @State private var showTraining = false
    @State private var sessionError: String?
    @State private var showGraph = false
    @Environment(\.colorScheme) private var colorScheme

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.82)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color.black.opacity(0.58)
    }

    private var chipBackgroundColor: Color {
        colorScheme == .dark ? .white.opacity(0.25) : .white.opacity(0.72)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack {

                    Spacer()
                        .frame(height: 70)

                    Text(nextCueText)
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                        .padding(.bottom, 28)

                    // POWER BUTTON
                    Button {
                        handleMainButtonTap()
                    } label: {
                        Circle()
                            .fill(AppTheme.powerButtonColor)
                            .frame(width: 220, height: 220)
                            .overlay {
                                Group {
                                    Image(powerButtonImageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 188, height: 188)
                                }
                                .clipShape(Circle())
                            }
                    }
                    .accessibilityLabel(isSessionActive ? "End sleep session" : "Start sleep session")
                    .accessibilityHint(isSessionActive ? "Stops the current sleep session" : "Begins the sleep flow")

                    // VIEW GRAPH BUTTON
                    Button {
                        showGraph = true
                    } label: {
                        Label("View Graph", systemImage: "chart.bar")
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(chipBackgroundColor)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 20)
                    .accessibilityHint("Shows your latest REM graph")

                    // Status info
                    VStack(spacing: 6) {
                        Text(coordinator.statusText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(primaryTextColor)

                        Text("Updated: \(lastUpdatedString)")
                            .font(.footnote)
                            .foregroundStyle(secondaryTextColor)

                        Text(
                            "Cues delivered: \(coordinator.watchCuesDeliveredTonight)"
                        )
                        .font(.footnote)
                        .foregroundStyle(secondaryTextColor)
                    }
                    .padding(.top, 18)

                    if let sessionError {
                        Text(sessionError)
                            .font(.footnote)
                            .foregroundStyle(secondaryTextColor)
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
                            .foregroundStyle(primaryTextColor)
                    }
                    .accessibilityLabel("Settings")
                }
            }

            // GRAPH MODAL
            .sheet(isPresented: $showGraph) {
                NavigationStack {
                    if let lastNight = nights.first {
                        CurveView(
                            sleepStart: lastNight.sleepStart,
                            sleepEnd: lastNight.sleepEnd,
                            curve: coordinator.lastCurve
                        )
                    } else {
                        Text("No sleep data yet.")
                    }
                }
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
            }
            // CALIBRATION
            .fullScreenCover(
                isPresented: $showCalibration,
                onDismiss: {
                    if coordinator.sleepPhase == .calibrating {
                        coordinator.sleepPhase = .idle
                    }
                }
            ) {
                CalibrationView(
                    wizard: VolumeCalibrationWizard(
                        player: coordinator.cuePlayer
                    ),
                    calibration: $coordinator.calibration,
                    onComplete: {
                        showCalibration = false
                        startTrainingAfterCalibration()
                    }
                )
            }

            // TRAINING
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
        .tint(AppTheme.accent)
    }

    @MainActor
    private var lastUpdatedString: String {
        guard let d = coordinator.lastUpdatedAt else { return "—" }
        return DateUtils.pretty(d)
    }

    private var isSessionActive: Bool {
        coordinator.sleepPhase != .idle
    }

    private var powerButtonImageName: String {
        let prefix = colorScheme == .dark ? "button_dark" : "button_light"
        return isSessionActive ? "\(prefix)_on" : "\(prefix)_off"
    }

    private var nextCueText: String {
        let now = Date()

        let upcomingDates = coordinator.nextWindows.flatMap { window in
            [window.start, window.end]
        }

        if let nextCue =
            upcomingDates
            .filter({ $0 > now })
            .min()
        {
            return
                "Next cue: \(nextCue.formatted(date: .omitted, time: .shortened))"
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
