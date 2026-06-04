//
//  SleepNight.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftData
import Foundation

@Model
final class SleepNight {
    @Attribute(.unique) var id: UUID
    var sleepStart: Date
    var sleepEnd: Date

    var remSeconds: Double
    var remBinSeconds: [Double]   // fixed-size: binCount

    init(sleepStart: Date, sleepEnd: Date, remSeconds: Double, remBinSeconds: [Double]) {
        self.id = UUID()
        self.sleepStart = sleepStart
        self.sleepEnd = sleepEnd
        self.remSeconds = remSeconds
        self.remBinSeconds = remBinSeconds
    }
}
