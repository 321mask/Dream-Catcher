//
//  SettingsView.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    let coordinator: AppCoordinator

    @Query(sort: \SleepNight.sleepStart, order: .reverse) private var nights: [SleepNight]

    @State private var showOnboarding = false
    @State private var showHapticTester = false

    var body: some View {
        Form {
            Section("Haptic Strength") {
                Button {
                    showHapticTester = true
                } label: {
                    Label("Configure Watch Haptics", systemImage: "applewatch")
                }
            }

            Section("Next REM Windows") {
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

            Section("Data") {
                NavigationLink("Nights (\(nights.count))") {
                    NightsListView(nights: nights)
                }
            }

            Section("Testing") {
                NavigationLink("Cue Testing") {
                    CueTestingView(coordinator: coordinator)
                }


            }

            Section("Help") {
                Button("View Onboarding") {
                    showOnboarding = true
                }
            }

            Section("Tuning") {
                Text("Half-life: 14 days\nSmoothing radius: 1 bin\nIgnore prefix: first 60 minutes\nMin separation: 90 minutes\nCues/window: 5, spacing 120s")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .appBackground()
        .navigationTitle("Settings")
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(coordinator: coordinator) {
                showOnboarding = false
            }
        }
        .sheet(isPresented: $showHapticTester) {
            TestHapticsView()
        }
    }
}
