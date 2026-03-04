//
//  CurveView.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI
import Charts

struct CurveView: View {
    
    let sleepStart: Date
    let sleepEnd: Date
    let curve: [Double]   // values 0–1
    
    struct DataPoint: Identifiable {
        let id = UUID()
        let time: Date
        let percentage: Double
    }
    
    // MARK: - Data
    
    private var data: [DataPoint] {
        guard !curve.isEmpty else { return [] }
        
        let totalDuration = sleepEnd.timeIntervalSince(sleepStart)
        let binDuration = totalDuration / Double(curve.count)
        
        return curve.enumerated().map { index, value in
            let time = sleepStart.addingTimeInterval(Double(index) * binDuration)
            return DataPoint(
                time: time,
                percentage: value * 100
            )
        }
    }
    
    private var maxValue: Double {
        data.map(\.percentage).max() ?? 0
    }
    
    private var minValue: Double {
        data.map(\.percentage).min() ?? 0
    }
    
    private var dynamicMaxY: Double {
        max(maxValue * 1.25, 5)
    }
    
    // MARK: - Body
    
    var body: some View {
        List {
            chartSection
            binsSection
        }
        .navigationTitle("REM Curve")
    }
}

////////////////////////////////////////////////////////////
// MARK: - Chart Section
////////////////////////////////////////////////////////////

extension CurveView {
    
    private var chartSection: some View {
        Section("Chart") {
            if data.isEmpty {
                Text("No REM data available.")
                    .foregroundStyle(.secondary)
            } else {
                chartView
              
                statsView
            }
        }
    }
    
    private var chartView: some View {
        Chart {

            ForEach(data) { point in
                BarMark(
                    x: .value("Time", point.time),
                    y: .value("REM %", point.percentage)
                )
                .cornerRadius(6)
                .foregroundStyle(
                    point.percentage == maxValue ? Color.green : Color.blue
                )
            }

        }
        .frame(height: 260)

        // Force chart to start exactly at sleep start
        .chartXScale(domain: sleepStart...sleepEnd)

        .chartYScale(domain: 0...dynamicMaxY)

        // Y axis
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(.gray.opacity(0.3))

                AxisValueLabel("\(Int(value.as(Double.self) ?? 0))%")
            }
        }

        // X axis (first label will be sleepStart)
        .chartXAxis {
            AxisMarks(values: [sleepStart]) { value in
                AxisValueLabel(format: .dateTime.hour().minute())
            }

            AxisMarks(values: .stride(by: .minute, count: 30)) { value in
                AxisGridLine()
                    .foregroundStyle(.gray.opacity(0.2))

                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
    }
    // Sleep start / end labels
    
        private var statsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Max REM: \(String(format: "%.1f", maxValue))%")
                .foregroundStyle(.green)
            
            Text("Min REM: \(String(format: "%.1f", minValue))%")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .padding(.top, 8)
    }
}

////////////////////////////////////////////////////////////
// MARK: - Bins Section
////////////////////////////////////////////////////////////

extension CurveView {
    
    private var binsSection: some View {
        Section("Bins") {
            if curve.isEmpty {
                Text("—")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(curve.enumerated()), id: \.offset) { idx, value in
                    HStack {
                        Text("Bin \(idx)")
                        Spacer()
                        Text(String(format: "%.3f", value))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
