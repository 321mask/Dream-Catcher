//
//  NightsListView.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI

struct NightsListView: View {
    let nights: [SleepNight]

    var body: some View {
        List {
            if nights.isEmpty {
                Text("No nights stored yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(nights, id: \.id) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(DateUtils.pretty(n.sleepStart))")
                            .font(.headline)
                        Text("\(DateUtils.pretty(n.sleepStart)) → \(DateUtils.pretty(n.sleepEnd))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("REM: \(Int(n.remSeconds / 60)) min")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Sleep Nights")
    }
}
