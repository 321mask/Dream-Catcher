//
//  OnBoardingView.swift
//  Dream_Catcher
//

import SwiftUI

struct OnboardingItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
}

struct OnboardingPageView: View {
    let item: OnboardingItem
    @Environment(\.colorScheme) private var colorScheme

    private var titleColor: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.82)
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? .white.opacity(0.82) : Color.black.opacity(0.62)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 22) {
                Text(item.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(titleColor)
                    .frame(maxWidth: 320)

                Text(item.subtitle)
                    .font(.system(.title3, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(subtitleColor)
                    .lineSpacing(5)
                    .frame(maxWidth: 320)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

struct OnboardingView: View {
    let coordinator: AppCoordinator
    let onGetStarted: () -> Void

    @State private var currentPage = 0
    @Environment(\.colorScheme) private var colorScheme

    private let items: [OnboardingItem] = [
        OnboardingItem(
            title: "Lucid Dreaming",
            subtitle: "Learn to become aware inside your dreams."
        ),
        OnboardingItem(
            title: "Relax before sleep",
            subtitle: "Tap the center button and listen to a short audio session that helps your mind relax."
        ),
        OnboardingItem(
            title: "Sleep data required",
            subtitle: "This app needs 7 days of sleep data from Apple Health to work."
        ),
        OnboardingItem(
            title: "Perfect timing",
            subtitle: "We analyze your sleep data to estimate when you enter REM sleep."
        ),
        OnboardingItem(
            title: "Apple Watch cues",
            subtitle: "Your Apple Watch sends gentle vibrations to help you notice that you are dreaming."
        )
    ]

    private var isLastPage: Bool {
        currentPage == items.count - 1
    }

    private var ctaTitle: String {
        isLastPage ? "Get Started" : "Continue"
    }

    private var skipColor: Color {
        if colorScheme == .dark {
            return isLastPage ? .white.opacity(0.35) : .white.opacity(0.78)
        }
        return isLastPage ? Color.black.opacity(0.2) : Color.black.opacity(0.55)
    }

    private var indicatorActiveColor: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.8)
    }

    private var indicatorInactiveColor: Color {
        colorScheme == .dark ? .white.opacity(0.24) : Color.black.opacity(0.16)
    }

    private var ctaTextColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.82) : Color(hex: "2E1567")
    }

    init(coordinator: AppCoordinator, onGetStarted: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onGetStarted = onGetStarted
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        OnboardingPageView(item: item)
                            .tag(index)
                            .padding(.bottom, 18)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                VStack(spacing: 26) {
                    pageIndicators
                    bottomCTA
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()

            Button {
                jumpToFinalPage()
            } label: {
                Text("Skip")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(skipColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .opacity(isLastPage ? 0 : 1)
            .allowsHitTesting(!isLastPage)
            .accessibilityHint("Jumps to the final onboarding page")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var pageIndicators: some View {
        HStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                Capsule()
                    .fill(index == currentPage ? indicatorActiveColor : indicatorInactiveColor)
                    .frame(width: index == currentPage ? 28 : 8, height: 8)
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: currentPage)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Page \(currentPage + 1) of \(items.count)")
    }

    private var bottomCTA: some View {
        Button {
            handleCTA()
        } label: {
            Text(ctaTitle)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(ctaTextColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(isLastPage ? "Completes onboarding" : "Moves to the next page")
    }

    private func handleCTA() {
        if isLastPage {
            onGetStarted()
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                currentPage += 1
            }
        }
    }

    private func jumpToFinalPage() {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentPage = items.count - 1
        }
    }
}

#Preview {
    OnboardingView(coordinator: AppCoordinator()) {}
}
