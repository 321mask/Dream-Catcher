//
//  Smoothing.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation

enum Smoothing {
    static func movingAverage(_ values: [Double], radius: Int) -> [Double] {
        guard radius > 0, !values.isEmpty else { return values }
        let n = values.count
        var out = Array(repeating: 0.0, count: n)

        for i in 0..<n {
            var sum = 0.0
            var count = 0.0
            let lo = max(0, i - radius)
            let hi = min(n - 1, i + radius)
            for j in lo...hi {
                sum += values[j]
                count += 1
            }
            out[i] = sum / max(1, count)
        }
        return out
    }
}
