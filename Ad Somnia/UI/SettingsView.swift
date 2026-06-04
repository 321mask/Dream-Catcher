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
                    settingsActionRow(
                        title: "Configure Watch Haptics",
                        systemImage: "applewatch"
                    )
                }
                .buttonStyle(.plain)
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

            /*Section("Testing") {
                NavigationLink("Cue Testing") {
                    CueTestingView(coordinator: coordinator)
                }


            }*/

            Section("Help") {
                Button {
                    showOnboarding = true
                } label: {
                    settingsActionRow(
                        title: "View Onboarding",
                        systemImage: "sparkles"
                    )
                }
                .buttonStyle(.plain)
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

    private func settingsActionRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.primary)
                .frame(width: 20)

            Text(title)
                .foregroundStyle(.primary)
                .font(.body)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
