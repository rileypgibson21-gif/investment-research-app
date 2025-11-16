//
//  SubscriptionPaywallView.swift
//  Ekonix
//
//  Created by Claude Code
//

import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasAttemptedLoad = false

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
                    if !subscriptionManager.subscriptions.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(subscriptionManager.subscriptions, id: \.id) { product in
                                SubscriptionOptionView(
                                    product: product,
                                    isSelected: selectedProduct?.id == product.id
                                ) {
                                    selectedProduct = product
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    } else if hasAttemptedLoad {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundStyle(.yellow)

                            Text("Unable to Load Subscriptions")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("Please check your internet connection and try again.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button("Retry") {
                                Task {
                                    await subscriptionManager.loadProducts()
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }

                    // Subscribe Button
                    Button(action: {
                        if let product = selectedProduct {
                            purchaseSubscription(product)
                        }
                    }) {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Start Free Trial")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedProduct != nil ? Color.blue : Color.gray)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                    .disabled(selectedProduct == nil || isPurchasing)

                    // Trial info
                    Text("7-day free trial, then \(selectedProduct?.localizedPrice ?? "$9.99")/\(getPeriodText()). Cancel anytime.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Restore Purchases
                    Button(action: {
                        Task {
                            await subscriptionManager.restorePurchases()
                            if subscriptionManager.isSubscribed {
                                dismiss()
                            }
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }

                    // Terms and Privacy
                    HStack(spacing: 20) {
                        Button("Terms of Service") {
                            // TODO: Open Terms URL
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                        Button("Privacy Policy") {
                            // TODO: Open Privacy URL
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            print("💳 Paywall appeared")
            print("   Available products: \(subscriptionManager.subscriptions.count)")
            // Select the first product by default
            if selectedProduct == nil {
                selectedProduct = subscriptionManager.subscriptions.first
                if let product = selectedProduct {
                    print("   ✅ Auto-selected product: \(product.displayName)")
                } else {
                    print("   ⚠️ No products available to select")
                }
            }

            // Set timeout to show error if products don't load
            Task {
                try? await Task.sleep(for: .seconds(5))
                if subscriptionManager.subscriptions.isEmpty {
                    hasAttemptedLoad = true
                    print("   ❌ Products failed to load within timeout")
                }
            }
        }
    }

    private func purchaseSubscription(_ product: Product) {
        isPurchasing = true

        Task {
            do {
                let transaction = try await subscriptionManager.purchase(product)
                if transaction != nil {
                    dismiss()
                }
            } catch {
                errorMessage = "Purchase failed. Please try again."
                showError = true
            }
            isPurchasing = false
        }
    }

    private func getPeriodText() -> String {
        guard let product = selectedProduct else { return "month" }

        if product.id.contains("annual") || product.id.contains("year") {
            return "year"
        } else {
            return "month"
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()
        }
    }
}

// MARK: - Subscription Option View
struct SubscriptionOptionView: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)

                    if isAnnual {
                        Text("Save 33%")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .fontWeight(.semibold)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.localizedPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("per \(isAnnual ? "year" : "month")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )
            )
        }
    }

    private var isAnnual: Bool {
        product.id.contains("annual") || product.id.contains("year")
    }
}

#Preview {
    SubscriptionPaywallView()
        .environmentObject(SubscriptionManager())
}
