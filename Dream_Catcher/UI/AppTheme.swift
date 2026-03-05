//  AppTheme.swift
//  Dream_Catcher
//
//  Shared color palette and background used across all screens.

import SwiftUI

// MARK: - Theme Constants

enum AppTheme {
    /// The app-wide gradient background (top to bottom).
    static let backgroundGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: "0F0D31"), location: 0.0),
            .init(color: Color(hex: "2E1567"), location: 0.50),
            .init(color: Color(hex: "81336E"), location: 0.89),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Power button fill color.
    static let powerButtonColor = Color(hex: "C3A7FF").opacity(0.40)

    /// App-wide accent color.
    static let accent = Color(hex: "FEF7FE")
}

// MARK: - Background View

/// Full-screen gradient background. Apply with `.background { AppBackground() }` or
/// wrap content in a ZStack.
struct AppBackground: View {
    var body: some View {
        AppTheme.backgroundGradient
            .ignoresSafeArea()
    }
}

// MARK: - View Modifier

extension View {
    /// Applies the app gradient background, transparent List/Form rows, and dark color scheme.
    func appBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .preferredColorScheme(.dark)
            .tint(AppTheme.accent)
    }
}

// MARK: - Hex Color Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
