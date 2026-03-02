//
//  Dream_CatcherApp.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import SwiftUI
import SwiftData

@main
struct Dream_CatcherApp: App {

    @State private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
             
                OnboardingView(coordinator: coordinator)
            }
            .modelContainer(AppContainer.makeModelContainer())
        }
    }


