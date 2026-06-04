//
//  SleepSampleMapper.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation
import HealthKit

enum SleepSampleMapper {

    /// Converts HKCategorySample sleep stages into SleepNight objects.
    /// - Handles naps + fragmented nights by extracting the "main episode" per day bucket.
    static func mapToNights(samples: [HKCategorySample], binCount: Int, binMinutes: Int) -> [SleepNight] {

        // Group by local calendar day of sample start
        let cal = Calendar.current
        let grouped = Dictionary(grouping: samples) { sample -> Date in
            let comps = cal.dateComponents([.year, .month, .day], from: sample.startDate)
            return cal.date(from: comps) ?? sample.startDate
        }

        var nights: [SleepNight] = []
        let binSeconds = Double(binMinutes * 60)

        for (_, group) in grouped {
            guard let main = SleepSessionExtractor.extractMainEpisode(samples: group) else { continue }
            let sleepStart = main.start
            let sleepEnd = main.end
            if sleepEnd <= sleepStart { continue }

            var remBins = Array(repeating: 0.0, count: binCount)
            var remTotal = 0.0

            for s in main.segments {
                guard s.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue else { continue }

                let clippedStart = max(s.startDate, sleepStart)
                let clippedEnd = min(s.endDate, sleepEnd)
                let duration = max(0, clippedEnd.timeIntervalSince(clippedStart))
                if duration <= 0 { continue }

                remTotal += duration

                let offsetStart = clippedStart.timeIntervalSince(sleepStart)
                let offsetEnd = clippedEnd.timeIntervalSince(sleepStart)

                let firstBin = max(0, Int(floor(offsetStart / binSeconds)))
                let lastBin = min(binCount - 1, Int(floor((offsetEnd - 0.0001) / binSeconds)))

                if firstBin <= lastBin {
                    for b in firstBin...lastBin {
                        let binStart = Double(b) * binSeconds
                        let binEnd = Double(b + 1) * binSeconds
                        let overlap = max(0, min(offsetEnd, binEnd) - max(offsetStart, binStart))
                        remBins[b] += overlap
                    }
                }
            }

            // Basic sanity: must be a real sleep episode
            let duration = sleepEnd.timeIntervalSince(sleepStart)
            if duration >= 2 * 60 * 60 {
                nights.append(SleepNight(
                    sleepStart: sleepStart,
                    sleepEnd: sleepEnd,
                    remSeconds: remTotal,
                    remBinSeconds: remBins
                ))
            }
        }

        nights.sort { $0.sleepStart < $1.sleepStart }
        return nights
    }
}
