//
//  SettingsView.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Notes") {
                Text("This prototype infers expected sleep start from recent nights (median). For production, add a user setting for usual bedtime / alarm time, and optionally detect bedtime from last phone activity.")
                    .foregroundStyle(.secondary)
            }

            Section("Tuning") {
                Text("Half-life: 14 days\nSmoothing radius: 1 bin\nIgnore prefix: first 60 minutes\nMin separation: 90 minutes\nCues/window: 5, spacing 120s")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
