//
//  MockSubscriptionPaywallView.swift
//  Ekonix
//
//  Mock paywall for taking App Store screenshots
//

import SwiftUI

struct MockSubscriptionPaywallView: View {
    @State private var selectedPlan: String = "monthly"

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 70))
                            .foregroundStyle(.white)
                            .padding(.top, 40)

                        Text("Unlock Full Access")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Research stocks with professional-grade financial data")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "chart.bar.fill", title: "Quarterly Revenue Charts", description: "Track revenue trends over time")
                        FeatureRow(icon: "arrow.up.right.circle.fill", title: "TTM Analysis", description: "View trailing twelve month metrics")
                        FeatureRow(icon: "percent", title: "YoY Growth Tracking", description: "Monitor year-over-year performance")
                        FeatureRow(icon: "doc.text.fill", title: "Real SEC Data", description: "Official filings, updated regularly")
                        FeatureRow(icon: "star.fill", title: "Save & Organize", description: "Create your research watchlist")
                    }
                    .padding(.horizontal, 24)

                    // Subscription Options
                    VStack(spacing: 12) {
                        // Monthly
                        Button(action: {
                            selectedPlan = "monthly"
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Monthly")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("$9.99")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)

                                    Text("per month")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedPlan == "monthly" ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selectedPlan == "monthly" ? Color.white : Color.clear, lineWidth: 2)
                                    )
                            )
                        }

                        // Annual
                        Button(action: {
                            selectedPlan = "annual"
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Annual")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Text("Save 17%")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                        .fontWeight(.semibold)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("$99.99")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)

                                    Text("per year")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedPlan == "annual" ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selectedPlan == "annual" ? Color.white : Color.clear, lineWidth: 2)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    // Subscribe Button
                    Button(action: {
                        // Mock action
                    }) {
                        Text("Start Free Trial")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)

                    // Trial info
                    Text("7-day free trial, then \(selectedPlan == "monthly" ? "$9.99" : "$99.99")/\(selectedPlan == "monthly" ? "month" : "year"). Cancel anytime.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Restore Purchases
                    Button(action: {
                        // Mock action
                    }) {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }

                    // Terms and Privacy
                    HStack(spacing: 20) {
                        Button("Terms of Service") {
                            // Mock action
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                        Button("Privacy Policy") {
                            // Mock action
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

#Preview {
    MockSubscriptionPaywallView()
}
