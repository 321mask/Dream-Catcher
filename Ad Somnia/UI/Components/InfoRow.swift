//
//  InfoRow.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
