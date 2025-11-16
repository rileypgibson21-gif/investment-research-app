//
//  SubscriptionManager.swift
//  Ekonix
//
//  Created by Claude Code
//

import SwiftUI
import StoreKit
import Combine

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {

    // MARK: - Published Properties
    @Published var subscriptions: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed

    // MARK: - Product IDs
    // These MUST match exactly with the product IDs you create in App Store Connect
    private let productIDs: [String] = [
        "com.ekonixlab.ekonix.premium.monthly",   // Monthly subscription product ID
        "com.ekonixlab.ekonix.premium.yearly"     // Yearly subscription product ID
    ]

    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Initialization
    init() {
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products
    func loadProducts() async {
        do {
            print("📦 Loading products for IDs: \(productIDs)")
            let products = try await Product.products(for: productIDs)
            print("✅ Successfully loaded \(products.count) products:")
            for product in products {
                print("  - \(product.displayName) (\(product.id)): \(product.localizedPrice)")
            }

            if products.isEmpty {
                print("⚠️ WARNING: No products returned from StoreKit")
                print("   This usually means:")
                print("   1. Products not configured in App Store Connect")
                print("   2. Bundle ID mismatch between app and App Store Connect")
                print("   3. App needs to be submitted for review before subscriptions work in TestFlight")
            }

            self.subscriptions = products.sorted { $0.price < $1.price }
        } catch {
            print("❌ Failed to load products: \(error)")
            print("   Error details: \(error.localizedDescription)")
            print("   Error type: \(type(of: error))")
            if let storeError = error as? StoreKitError {
                print("   StoreKit error: \(storeError)")
            }
        }
    }

    // MARK: - Purchase Subscription
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()

            // Register device and get API key for authenticated API access
            do {
                try await AuthenticationService.shared.registerDevice()
                print("✅ Device registered and API key obtained")
            } catch {
                print("⚠️ Failed to register device: \(error.localizedDescription)")
                // Don't fail the purchase, user can retry later
            }

            await transaction.finish()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }

    // MARK: - Check Subscription Status
    func updateSubscriptionStatus() async {
        var validSubscription: Product?

        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if transaction is for one of our subscription products
                if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                    validSubscription = subscription
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        if let subscription = validSubscription {
            subscriptionStatus = .subscribed(subscription)
            if !purchasedSubscriptions.contains(where: { $0.id == subscription.id }) {
                purchasedSubscriptions.append(subscription)
            }
        } else {
            subscriptionStatus = .notSubscribed
            purchasedSubscriptions.removeAll()
        }
    }

    // MARK: - Listen for Transactions
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            guard let self = self else { return }

            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await MainActor.run {
                        try self.checkVerified(result)
                    }
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verify Transaction
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Subscription Status Helper
    var isSubscribed: Bool {
        switch subscriptionStatus {
        case .subscribed:
            return true
        case .notSubscribed:
            return false
        }
    }
}

// MARK: - Subscription Status Enum
enum SubscriptionStatus {
    case subscribed(Product)
    case notSubscribed
}

// MARK: - Store Errors
enum StoreError: Error {
    case failedVerification
}

// MARK: - Product Extensions for Display
extension Product {
    var localizedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = self.priceFormatStyle.locale
        return formatter.string(from: self.price as NSDecimalNumber) ?? "\(self.price)"
    }
}
