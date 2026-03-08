//
//  BarChartView.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI
import Charts

struct RemBarChartView: View {
    
    let sleepStart: Date
    let sleepEnd: Date
    let bins: [Double]   // predicted REM likelihood per bin (0–1)
    
    private struct DataPoint: Identifiable {
        let id = UUID()
        let time: Date
        let percentage: Double
    }
    
    private var data: [DataPoint] {
        guard !bins.isEmpty else { return [] }
        
        let totalDuration = sleepEnd.timeIntervalSince(sleepStart)
        let binDuration = totalDuration / Double(bins.count)
        
        return bins.enumerated().map { index, value in
            let time = sleepStart.addingTimeInterval(Double(index) * binDuration)
            
            // Convert likelihood to percentage
            let percentage = value * 100
            
            return DataPoint(time: time, percentage: percentage)
        }
    }
    
    private var maxValue: Double {
        data.map(\.percentage).max() ?? 0
    }
    
    private var minValue: Double {
        data.map(\.percentage).min() ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Chart {
                ForEach(data) { point in
                    BarMark(
                        x: .value("Time", point.time),
                        y: .value("REM %", point.percentage)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                }
                
                // Max Line
                RuleMark(y: .value("Max", maxValue))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .topTrailing) {
                        Text("Max \(Int(maxValue))%")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                
                // Min Line
                RuleMark(y: .value("Min", minValue))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .bottomTrailing) {
                        Text("Min \(Int(minValue))%")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
            }
            .frame(height: 240)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue))%")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour())
                        .font(.caption2)
                }
            }
            .chartPlotStyle { plot in
                plot
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 4)
                    )
            }
        }
    }
}
