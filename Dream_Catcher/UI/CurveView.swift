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
    
    /// The threshold at or above which a bar is considered "top 2".
    private var top2Threshold: Double {
        let sorted = data.map(\.percentage).sorted(by: >)
        guard sorted.count >= 2 else { return maxValue }
        return sorted[1]
    }
    
    private var dynamicMaxY: Double {
        max(maxValue * 1.25, 5)
    }
    
    // MARK: - Body
    
    var body: some View {
        List {
            chartSection
                    }
        .appBackground()
        .navigationTitle("REM Curve")
    }
}

////////////////////////////////////////////////////////////
// MARK: - Chart Section
////////////////////////////////////////////////////////////

extension CurveView {
    
    private var chartSection: some View {
        Section() {
            if data.isEmpty {
                Text("No REM data available.")
                    .foregroundStyle(.secondary)
            } else {
                chartView
                
                
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
                    point.percentage >= top2Threshold ? Color.green : Color.blue
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
    
    
    ////////////////////////////////////////////////////////////
    // MARK: - Bins Section
    ////////////////////////////////////////////////////////////
}
