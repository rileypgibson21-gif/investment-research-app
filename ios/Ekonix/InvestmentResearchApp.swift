//
//  InvestmentResearchApp.swift
//  Ekonix
//
//  Created by Riley Gibson on 10/19/25.
//


import SwiftUI
import SwiftData
import Combine

@main
struct InvestmentResearchApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionManager = SubscriptionManager()

    // MARK: - Development Bypass
    // Set this to true to skip subscription requirement during development
    #if DEBUG
    private let bypassSubscription = false  // Change to false to test subscription flow
    #else
    private let bypassSubscription = false
    #endif

    var body: some Scene {
        WindowGroup {
            if !appState.hasAcceptedDisclaimer {
                DisclaimerView(hasAcceptedDisclaimer: $appState.hasAcceptedDisclaimer)
            } else if !bypassSubscription && !subscriptionManager.isSubscribed {
                SubscriptionPaywallView()
                    .environmentObject(subscriptionManager)
            } else {
                ContentView()
                    .environmentObject(subscriptionManager)
            }
        }
        .modelContainer(for: ResearchItem.self, inMemory: false)
    }
}

// MARK: - App State Management
class AppState: ObservableObject {
    @Published var hasAcceptedDisclaimer: Bool {
        didSet {
            UserDefaults.standard.set(hasAcceptedDisclaimer, forKey: "hasAcceptedDisclaimer")
        }
    }

    init() {
        self.hasAcceptedDisclaimer = UserDefaults.standard.bool(forKey: "hasAcceptedDisclaimer")
    }
}
