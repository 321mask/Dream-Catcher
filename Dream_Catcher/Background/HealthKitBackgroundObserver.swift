//
//  HealthKitBackgroundObserver.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation
import HealthKit

/// Optional: If you want true "nightly update" triggered by new sleep data:
/// - Use HKObserverQuery + enableBackgroundDelivery
/// This file is a starter, but wiring it perfectly requires app lifecycle handling.
/// You can integrate it once basic pipeline works.
final class HealthKitBackgroundObserver {
    private let store = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

    func startObserving(onNewData: @escaping () -> Void) {
        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { _, completionHandler, error in
            if let error {
                log("HKObserverQuery error: \(error)")
                completionHandler()
                return
            }
            onNewData()
            completionHandler()
        }
        store.execute(query)

        store.enableBackgroundDelivery(for: sleepType, frequency: .daily) { success, error in
            if let error { log("enableBackgroundDelivery error: \(error)") }
            log("Background delivery enabled: \(success)")
        }
    }
}
