//
//  DataStore.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftData
import Foundation

@ModelActor
actor DataStore {
    func replaceOverlappingNights(_ nights: [SleepNight]) throws {
        for night in nights {
            let start = night.sleepStart
            let end = night.sleepEnd

            let predicate = #Predicate<SleepNight> { stored in
                stored.sleepStart < end && stored.sleepEnd > start
            }
            let matches = try modelContext.fetch(FetchDescriptor(predicate: predicate))
            for m in matches { modelContext.delete(m) }

            modelContext.insert(night)
        }
        try modelContext.save()
    }

    func fetchRecentNights(limit: Int = 60) throws -> [SleepNight] {
        try modelContext.fetch(
            FetchDescriptor<SleepNight>(
                sortBy: [SortDescriptor(\.sleepStart, order: .reverse)]
            )
        ).prefix(limit).map { $0 }
    }

    func upsertModelState(probBins: [Double], halfLifeDays: Double, smoothingRadiusBins: Int) throws -> RemModelState {
        let states = try modelContext.fetch(FetchDescriptor<RemModelState>())
        if let s = states.first {
            s.probBins = probBins
            s.updatedAt = .now
            s.halfLifeDays = halfLifeDays
            s.smoothingRadiusBins = smoothingRadiusBins
            try modelContext.save()
            return s
        } else {
            let s = RemModelState(probBins: probBins, halfLifeDays: halfLifeDays, smoothingRadiusBins: smoothingRadiusBins)
            modelContext.insert(s)
            try modelContext.save()
            return s
        }
    }

    func lastUpdatedAt() throws -> Date? {
        try modelContext.fetch(FetchDescriptor<RemModelState>()).first?.updatedAt
    }
}
