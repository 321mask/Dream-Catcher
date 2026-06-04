//
//  RemWindowSelector.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation

struct RemWindowSelector {
    /// Selects top N windows from the curve.
    /// - curve: probability per 30-min bin
    /// - expectedSleepStart: anchor to real clock time for scheduling
    /// - windowBinsRadius: how wide each window is (radius in bins around peak)
    func selectTopWindows(
        curve: [Double],
        expectedSleepStart: Date,
        binMinutes: Int,
        maxWindows: Int
    ) -> [DateInterval] {

        let n = curve.count
        guard n > 0 else { return [] }

        // Ignore first 2 bins (~60 min) to avoid early non-REM region
        let ignorePrefix = min(2, n)

        // Find local maxima
        var peaks: [(idx: Int, value: Double)] = []
        for i in ignorePrefix..<n {
            let left = (i > 0) ? curve[i - 1] : -1
            let right = (i < n - 1) ? curve[i + 1] : -1
            if curve[i] >= left && curve[i] >= right {
                peaks.append((i, curve[i]))
            }
        }

        // Sort by peak height
        peaks.sort { $0.value > $1.value }

        var chosen: [Int] = []
        let minSeparationBins = 3 // ~90 minutes

        for p in peaks {
            if chosen.count >= maxWindows { break }
            if chosen.allSatisfy({ abs($0 - p.idx) >= minSeparationBins }) {
                chosen.append(p.idx)
            }
        }

        // Convert peaks to DateIntervals
        let binSeconds = TimeInterval(binMinutes * 60)
        let windowRadiusBins = 1 // +/- 30 minutes (total 90 min window). Adjust as desired.

        let windows: [DateInterval] = chosen.map { peak in
            let startBin = max(0, peak - windowRadiusBins)
            let endBin = min(n, peak + windowRadiusBins + 1)

            let start = expectedSleepStart.addingTimeInterval(TimeInterval(startBin) * binSeconds)
            let end = expectedSleepStart.addingTimeInterval(TimeInterval(endBin) * binSeconds)
            return DateInterval(start: start, end: end)
        }

        return windows.sorted { $0.start < $1.start }
    }
}
