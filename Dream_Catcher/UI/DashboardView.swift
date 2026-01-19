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
    
    @MainActor
    private var lastUpdatedString: String {
        guard let d = coordinator.lastUpdatedAt else { return "—" }
        return DateUtils.pretty(d)
    }

    var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            List {
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
                }
            }
            .navigationTitle("LucidREM")
            .toolbar {
                NavigationLink("Settings") {
                    SettingsView()
                }
            }
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
