//
//  DailyUpdatePolicy.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation
import SwiftData

enum DailyUpdatePolicy {

    /// The “deadline” time (local) by which we want the update done.
    static let deadlineHour = 10
    static let deadlineMinute = 0

    /// Returns the deadline Date for "today" in local time.
    static func todayDeadline(now: Date = .now) -> Date {
        let cal = Calendar.current
        let day = cal.dateComponents([.year, .month, .day], from: now)
        let base = cal.date(from: day) ?? now
        return cal.date(byAdding: .minute, value: deadlineHour * 60 + deadlineMinute, to: base) ?? now
    }

    /// Should we run today’s update now?
    /// - Runs if now >= todayDeadline and lastUpdatedAt < todayDeadline
    static func shouldRunNow(lastUpdatedAt: Date?, now: Date = .now) -> Bool {
        let deadline = todayDeadline(now: now)
        guard now >= deadline else { return false }
        guard let lastUpdatedAt else { return true }
        return lastUpdatedAt < deadline
    }

    /// Reads last update time from SwiftData model state.
    static func readLastUpdatedAt(modelContext: ModelContext) -> Date? {
        let fetch = FetchDescriptor<RemModelState>()
        let states = try? modelContext.fetch(fetch)
        return states?.first?.updatedAt
    }
}
