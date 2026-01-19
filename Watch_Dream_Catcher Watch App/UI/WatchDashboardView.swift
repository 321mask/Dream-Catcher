//
//  WatchDashboardView.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 15/01/2026.
//

import SwiftUI

struct WatchDashboardView: View {
    @State private var session = WatchSessionManager()

    var body: some View {
        List {
            Section("Status") {
                Text(session.status)
            }

            Section("Windows") {
                if session.lastReceivedWindows.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(session.lastReceivedWindows.enumerated()), id: \.offset) { i, w in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Window \(i + 1)")
                                .font(.headline)
                            Text("\(w.start.formatted(date: .omitted, time: .shortened)) → \(w.end.formatted(date: .omitted, time: .shortened))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
