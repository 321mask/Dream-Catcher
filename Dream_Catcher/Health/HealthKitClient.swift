//
//  HealthKitClient.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation
import HealthKit

enum HealthKitClientError: Error {
    case healthDataUnavailable
    case authorizationDenied
}

final class HealthKitClient {
    private let store = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitClientError.healthDataUnavailable
        }

        let toRead: Set<HKObjectType> = [sleepType]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: [], read: toRead) { success, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard success else {
                    cont.resume(throwing: HealthKitClientError.authorizationDenied)
                    return
                }
                cont.resume(returning: ())
            }
        }
    }

    func fetchSleepNights(lastNDays: Int, now: Date) async throws -> [SleepNight] {
        let start = Calendar.current.date(byAdding: .day, value: -lastNDays, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)

        let samples = try await queryCategorySamples(type: sleepType, predicate: predicate)

        // Map raw samples -> nights (choose main sleep interval per day)
        return SleepSampleMapper.mapToNights(samples: samples, binCount: RemCurveAnalyzer.defaultBinCount, binMinutes: 30)
    }

    private func queryCategorySamples(type: HKCategoryType, predicate: NSPredicate) async throws -> [HKCategorySample] {
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKCategorySample], Error>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }

            store.execute(query)
        }
    }
}
