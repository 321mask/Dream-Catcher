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
    @State private var testDelayIndex: Int = 2
    @State private var testCueCount: Int = 3

    private let testDelayOptions: [(label: String, seconds: TimeInterval)] = [
        ("10s", 10),
        ("30s", 30),
        ("1m", 60),
        ("2m", 120),
        ("5m", 300),
        ("10m", 600),
    ]

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
                    if let lastNight = nights.first {
                        NavigationLink("View curve") {
                            CurveView(
                                sleepStart: lastNight.sleepStart,
                                sleepEnd: lastNight.sleepEnd,
                                curve: currentCurve
                            )
                        }
                    } else {
                        Text("No sleep data yet.")
                            .foregroundStyle(.secondary)
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

                    Picker("First cue in", selection: $testDelayIndex) {
                        ForEach(0..<testDelayOptions.count, id: \.self) { i in
                            Text(testDelayOptions[i].label).tag(i)
                        }
                    }

                    Stepper("Cues: \(testCueCount)", value: $testCueCount, in: 1...10)

                    Button("Schedule test cues") {
                        Task { await scheduleTest() }
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
                    SettingsView(coordinator: coordinator)
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
            .fullScreenCover(isPresented: $showTraining) {
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

                    HStack {
                        Text("Cues delivered")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(coordinator.watchCuesDeliveredTonight)")
                    }
                    .font(.footnote)
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

    private var currentSleepStart: Date {
        if let firstWindow = coordinator.nextWindows.first {
            return firstWindow.start
        }
        if let lastNight = nights.first {
            return lastNight.sleepStart
        }
        return Date()
    }

    private var currentSleepEnd: Date {
        if let firstWindow = coordinator.nextWindows.first {
            return firstWindow.end
        }
        if let lastNight = nights.first {
            return lastNight.sleepEnd
        }
        return Date()
    }

    private var currentCurve: [Double] {
        if !coordinator.lastCurve.isEmpty { return coordinator.lastCurve }
        return modelStates.first?.probBins ?? []
    }

    private func scheduleTest() async {
        let baseDelay = testDelayOptions[testDelayIndex].seconds
        let spacing: TimeInterval = 30
        let offsets = (0..<testCueCount).map { i in
            baseDelay + TimeInterval(i) * spacing
        }

        // Build a single window that contains all test cues
        let windowStart = Date().addingTimeInterval(baseDelay)
        let windowEnd = Date().addingTimeInterval(offsets.last! + 60)
        let window = DateInterval(start: windowStart, end: windowEnd)
        coordinator.nextWindows = [window]

        // Ensure session is active first, then schedule cues.
        PhoneWatchSync.shared.sendStartSleepSession()
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        do {
            try await CueScheduler().requestAuthorizationIfNeeded()
            CueScheduler().replaceScheduledCues(
                for: [window],
                cuesPerWindow: testCueCount,
                spacingSeconds: spacing
            )

            // Send to Watch after session activation window.
            PhoneWatchSync.shared.sendScheduleTestCues(offsets: offsets)

            let delayLabel = testDelayOptions[testDelayIndex].label
            coordinator.statusText = "\(testCueCount) test cue\(testCueCount == 1 ? "" : "s") scheduled from \(delayLabel)"
        } catch {
            coordinator.statusText = "Notifications denied"
        }
    }
}


#Preview{
    DashboardView(coordinator: AppCoordinator())
}
