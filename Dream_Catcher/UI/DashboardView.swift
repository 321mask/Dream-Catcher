//
//  DashboardView.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepNight.sleepStart, order: .reverse) private var nights: [SleepNight]
    @Query private var modelStates: [RemModelState]

    @Bindable var coordinator: AppCoordinator

    @State private var showCalibration = false
    @State private var showTraining = false
    @State private var sessionError: String?
    @State private var showHapticTester = false

    @MainActor
    private var lastUpdatedString: String {
        guard let d = coordinator.lastUpdatedAt else { return "—" }
        return DateUtils.pretty(d)
    }

    var body: some View {
        NavigationStack {
            List {
                sleepSessionSection

                Section("Status") {
                    InfoRow(title: "Status", value: coordinator.statusText)
                    InfoRow(
                        title: "Last updated",
                        value: lastUpdatedString
                    )
                    InfoRow(title: "Stored nights", value: "\(nights.count)")
                }

                Section("Next REM windows") {
                    if coordinator.nextWindows.isEmpty {
                        Text("No windows yet. Run update.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(coordinator.nextWindows.enumerated()), id: \.offset) { i, w in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Window \(i + 1)")
                                    .font(.headline)
                                Text("\(DateUtils.pretty(w.start)) → \(DateUtils.pretty(w.end))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Curve") {
                    NavigationLink("View curve") {
                        CurveView(curve: currentCurve)
                    }
                }

                Section("Data") {
                    NavigationLink("Nights") {
                        NightsListView(nights: nights)
                    }
                }

                Section {
                    Button("Run nightly update now") {
                        let container = modelContext.container
                        Task { await coordinator.runNightlyUpdate(modelContainer: container) }
                    }

                    Button("Schedule test cues (5 minutes from now)") {
                        Task {
                            await scheduleTest()
                        }
                    }

                    Button {
                        showHapticTester = true
                    } label: {
                        Label("Test Haptics", systemImage: "applewatch")
                    }
                }
            }
            .navigationTitle("LucidREM")
            .toolbar {
                NavigationLink("Settings") {
                    SettingsView()
                }
            }
            .fullScreenCover(isPresented: $showCalibration, onDismiss: {
                // If still in calibrating phase, user skipped/cancelled
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
            .fullScreenCover(isPresented: $showTraining, onDismiss: {
                // If still in training phase, user cancelled early
                if coordinator.sleepPhase == .training {
                    coordinator.endSleepSession()
                }
            }) {
                if let session = coordinator.trainingSession {
                    PreSleepTrainingView(session: session) {
                        coordinator.trainingCompleted()
                    }
                }
            }
            .sheet(isPresented: $showHapticTester) {
                TestHapticsView()
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

    // MARK: - Sleep Session Section

    private var sleepSessionSection: some View {
        Section {
            switch coordinator.sleepPhase {
            case .idle:
                Button {
                    do {
                        try coordinator.beginSleepFlow()
                    } catch {
                        sessionError = error.localizedDescription
                    }
                } label: {
                    Label("Start Sleep Session", systemImage: "moon.fill")
                }

                if let calibration = coordinator.calibration {
                    HStack {
                        Text("Calibration")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if calibration.needsRecalibration {
                            Text("Stale")
                                .foregroundStyle(.orange)
                        } else {
                            Text("OK")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.footnote)
                } else {
                    Text("Not calibrated yet")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let err = sessionError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

            case .calibrating:
                Label("Calibrating...", systemImage: "speaker.wave.2")
                    .foregroundStyle(.secondary)

            case .training:
                Label("Training in progress...", systemImage: "brain.head.profile")
                    .foregroundStyle(.indigo)

            case .monitoring:
                VStack(alignment: .leading, spacing: 8) {
                    Label("Monitoring sleep", systemImage: "bed.double.fill")
                        .foregroundStyle(.green)

                    if let scheduler = coordinator.remScheduler {
                        HStack {
                            Text("Cues delivered")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(scheduler.cuesDeliveredTonight)")
                        }
                        .font(.footnote)
                    }
                }

                Button(role: .destructive) {
                    coordinator.endSleepSession()
                } label: {
                    Label("End Sleep Session", systemImage: "sun.max.fill")
                }
            }
        } header: {
            Text("Sleep Session")
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

    private var currentCurve: [Double] {
        if !coordinator.lastCurve.isEmpty { return coordinator.lastCurve }
        return modelStates.first?.probBins ?? []
    }

    private func scheduleTest() async {
        // Create two fake windows for quick device testing
        let start = Date().addingTimeInterval(5 * 60)
        let w1 = DateInterval(start: start, end: start.addingTimeInterval(20 * 60))
        let w2 = DateInterval(start: start.addingTimeInterval(90 * 60), end: start.addingTimeInterval(110 * 60))
        coordinator.nextWindows = [w1, w2]

        do {
            try await CueScheduler().requestAuthorizationIfNeeded()
            CueScheduler().replaceScheduledCues(for: [w1, w2], cuesPerWindow: 5, spacingSeconds: 120)
            coordinator.statusText = "Test cues scheduled"
        } catch {
            coordinator.statusText = "Notifications denied"
        }
    }
}

<<<<<<< Updated upstream
=======
#Preview{
    DashboardView(coordinator: AppCoordinator())
}
>>>>>>> Stashed changes
