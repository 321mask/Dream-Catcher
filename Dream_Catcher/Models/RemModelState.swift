//
//  RemModelState.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftData
import Foundation

@Model
final class RemModelState {
    @Attribute(.unique) var id: UUID
    var updatedAt: Date
    var probBins: [Double]
    var halfLifeDays: Double
    var smoothingRadiusBins: Int

    init(probBins: [Double], halfLifeDays: Double, smoothingRadiusBins: Int) {
        self.id = UUID()
        self.updatedAt = .now
        self.probBins = probBins
        self.halfLifeDays = halfLifeDays
        self.smoothingRadiusBins = smoothingRadiusBins
    }
}
