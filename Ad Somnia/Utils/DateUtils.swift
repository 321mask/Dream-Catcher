//
//  DateUtils.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation

enum DateUtils {
    // DateFormatter is not Sendable; keep it in a static let and confine usage to the same actor.
    // The simplest approach is to make formatting run on MainActor.
    @MainActor
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    @MainActor
    static func pretty(_ date: Date) -> String {
        formatter.string(from: date)
    }

    static func minutesSinceMidnight(_ date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    static func todayAt(minutesSinceMidnight: Int, now: Date) -> Date {
        let cal = Calendar.current
        let dayComps = cal.dateComponents([.year, .month, .day], from: now)
        let base = cal.date(from: dayComps) ?? now
        return cal.date(byAdding: .minute, value: minutesSinceMidnight, to: base) ?? now
    }
}
