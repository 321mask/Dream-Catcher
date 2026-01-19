//
//  SleepSessionExtractor.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation
import HealthKit

struct SleepEpisode {
    var start: Date
    var end: Date
    var segments: [HKCategorySample]

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Extracts the main sleep session from staged sleep samples, robust to fragmentation and naps.
enum SleepSessionExtractor {

    struct Config {
        var mergeGapSeconds: TimeInterval = 20 * 60      // merge gaps < 20 min
        var minMainSleepSeconds: TimeInterval = 90 * 60  // ignore naps < 90 min
        var nightStartHour: Int = 18                     // 18:00
        var nightEndHour: Int = 12                       // 12:00 (next day window)
    }

    static func extractMainEpisode(samples: [HKCategorySample], config: Config = .init()) -> SleepEpisode? {
        let asleepSamples = samples.filter { isAsleepValue($0.value) }
            .sorted { $0.startDate < $1.startDate }

        guard !asleepSamples.isEmpty else { return nil }

        // Build episodes by merging close segments.
        var episodes: [SleepEpisode] = []
        var currentSegments: [HKCategorySample] = [asleepSamples[0]]
        var currentStart = asleepSamples[0].startDate
        var currentEnd = asleepSamples[0].endDate

        for s in asleepSamples.dropFirst() {
            let gap = s.startDate.timeIntervalSince(currentEnd)
            if gap <= config.mergeGapSeconds {
                currentSegments.append(s)
                currentEnd = max(currentEnd, s.endDate)
            } else {
                episodes.append(SleepEpisode(start: currentStart, end: currentEnd, segments: currentSegments))
                currentSegments = [s]
                currentStart = s.startDate
                currentEnd = s.endDate
            }
        }
        episodes.append(SleepEpisode(start: currentStart, end: currentEnd, segments: currentSegments))

        // Filter out short episodes (likely naps)
        let candidates = episodes.filter { $0.duration >= config.minMainSleepSeconds }
        guard !candidates.isEmpty else {
            // Fallback: if everything is short, still return the longest
            return episodes.max(by: { $0.duration < $1.duration })
        }

        // Score episodes:
        // - primary: duration
        // - bonus if start in "night window" (evening -> next day noon)
        // - mild penalty if start mid-day
        func score(_ e: SleepEpisode) -> Double {
            let durHours = e.duration / 3600.0
            let nightBonus = startsInNightWindow(e.start, nightStartHour: config.nightStartHour, nightEndHour: config.nightEndHour) ? 1.5 : 0.0
            return durHours + nightBonus
        }

        return candidates.max(by: { score($0) < score($1) })
    }

    private static func isAsleepValue(_ value: Int) -> Bool {
        // Accept all asleep stage variants plus generic asleep.
        // Exclude inBed.
        if value == HKCategoryValueSleepAnalysis.inBed.rawValue { return false }
        // .asleep (generic) and .asleepCore/.asleepDeep/.asleepREM appear on newer systems.
        return true
    }

    private static func startsInNightWindow(_ date: Date, nightStartHour: Int, nightEndHour: Int) -> Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)

        // Night window spanning midnight:
        // Example: nightStart=18, nightEnd=12 => [18..23] U [0..12]
        if nightStartHour <= 23 && nightEndHour >= 0 && nightStartHour > nightEndHour {
            return (hour >= nightStartHour) || (hour <= nightEndHour)
        } else {
            // Non-wrapping window (rare)
            return (hour >= nightStartHour) && (hour <= nightEndHour)
        }
    }
}
