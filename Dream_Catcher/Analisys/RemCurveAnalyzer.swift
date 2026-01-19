//
//  RemCurveAnalyzer.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation

struct RemCurveAnalyzer {
    static let defaultBinCount = 20 // 10h @ 30min bins

    func computeProbabilityCurve(
        nights: [SleepNight],
        binCount: Int,
        halfLifeDays: Double,
        smoothingRadiusBins: Int
    ) -> [Double] {

        guard !nights.isEmpty else { return Array(repeating: 1.0 / Double(binCount), count: binCount) }

        let now = Date()
        var score = Array(repeating: 0.0, count: binCount)

        for night in nights {
            let daysAgo = abs(now.timeIntervalSince(night.sleepStart)) / (60 * 60 * 24)
            let w = pow(0.5, daysAgo / max(0.1, halfLifeDays))

            // Safety: handle inconsistent bin sizes
            let bins = night.remBinSeconds
            for i in 0..<min(binCount, bins.count) {
                score[i] += w * bins[i]
            }
        }

        // Smooth across adjacent bins
        let smoothed = Smoothing.movingAverage(score, radius: smoothingRadiusBins)

        // Normalize into probability distribution
        let total = smoothed.reduce(0, +)
        if total <= 0 {
            return Array(repeating: 1.0 / Double(binCount), count: binCount)
        }
        return smoothed.map { $0 / total }
    }
}
