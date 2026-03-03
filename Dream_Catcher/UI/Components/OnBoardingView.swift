//
//  OnBoardingView.swift
//  Dream_Catcher
//
//  Created by Muhammad Usman on 24/02/26.
//

import SwiftUI

struct OnboardingView: View {
    let coordinator: AppCoordinator
    var onFinished: (() -> Void)?

    @State private var currentPage = 0

    @Environment(\.dismiss) private var dismiss
    
    let items = [
        ("moon.stars.fill", "Welcome", "Track and improve your sleep."),
        ("sparkles", "Smart Insights", "Understand your sleep patterns."),
        ("bed.double.fill", "Better Rest", "Wake up refreshed every day.")
    ]
    
    var body: some View {
        NavigationStack{
            ZStack {
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.62, green: 0.66, blue: 0.95),
                        Color(red: 0.98, green: 0.60, blue: 0.65)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    
                    // Skip Button
                    HStack {
                        Spacer()
                        Button {
                            finishOnboarding()
                        } label: {
                            Text("Skip")
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    
                    // Pages
                    TabView(selection: $currentPage) {
                        ForEach(0..<items.count, id: \.self) { index in
                            VStack(spacing: 25) {
                                
                                Spacer()
                                
                                Image(systemName: items[index].0)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 120)
                                    .foregroundColor(.white)
                                
                                Text(items[index].1)
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.white)
                                
                                Text(items[index].2)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 30)
                                
                                Spacer()
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // Dots
                    HStack(spacing: 8) {
                        ForEach(0..<items.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? .white : .white.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    // Next / Get Started
                    if currentPage < items.count - 1 {
                        Button {
                            currentPage += 1
                        } label: {
                            Text("Next")
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .padding(.horizontal, 30)
                        }
                        .padding(.bottom, 30)
                    } else {
                        Button {
                            finishOnboarding()
                        } label: {
                            Text("Get Started")
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .padding(.horizontal, 30)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        }
    }

    private func finishOnboarding() {
        if let onFinished {
            onFinished()
        } else {
            dismiss()
        }
    }
}

#Preview {
    OnboardingView(coordinator: AppCoordinator())
}
