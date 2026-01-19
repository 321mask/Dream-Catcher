//
//  BarChartView.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI

struct BarChartView: View {
    let values: [Double]
    var height: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = height
            let n = max(values.count, 1)
            let barWidth = w / CGFloat(n)
            let maxV = max(values.max() ?? 1e-9, 1e-9)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(values.indices, id: \.self) { i in
                    let v = values[i] / maxV
                    Rectangle()
                        .opacity(0.7)
                        .frame(width: barWidth, height: max(1, h * v))
                }
            }
            .frame(width: w, height: h, alignment: .bottomLeading)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(height: height)
    }
}
