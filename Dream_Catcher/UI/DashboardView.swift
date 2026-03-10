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

    var body: some View {
        NavigationStack {
            List {
                sleepSessionSection

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


            }
            .appBackground()
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
                                .foregroundStyle(.primary)
                        } else {
                            Text("OK")
                                .foregroundStyle(.primary)
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
                        .foregroundStyle(.secondary)
                }

            case .calibrating:
                Label("Calibrating...", systemImage: "speaker.wave.2")
                    .foregroundStyle(.secondary)

            case .training:
                Label("Training in progress...", systemImage: "brain.head.profile")
                    .foregroundStyle(.primary)

            case .monitoring:
                VStack(alignment: .leading, spacing: 8) {
                    Label("Monitoring sleep", systemImage: "bed.double.fill")
                        .foregroundStyle(.primary)

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


}


#Preview{
    DashboardView(coordinator: AppCoordinator())
}
