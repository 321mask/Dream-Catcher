//
//  CurveView.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI

struct CurveView: View {
    let curve: [Double]

    var body: some View {
        List {
            Section("Chart") {
                if curve.isEmpty {
                    Text("No curve yet.")
                        .foregroundStyle(.secondary)
                } else {
                    BarChartView(values: curve, height: 140)
                        .padding(.vertical, 8)

                    Text("Higher bars = higher predicted REM likelihood by time-since-sleep-onset (30 min bins).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Bins") {
                if curve.isEmpty {
                    Text("—")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(curve.enumerated()), id: \.offset) { idx, p in
                        HStack {
                            Text("Bin \(idx)")
                            Spacer()
                            Text(String(format: "%.3f", p))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("REM Curve")
    }
}
