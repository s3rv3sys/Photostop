//
//  StoreKitService.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import Foundation
import StoreKit
import os.log

/// StoreKit 2 wrapper for subscriptions and consumables
@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    // MARK: - Product IDs
    
    enum ProductID: String, CaseIterable {
        case proMonthly = "com.photostop.pro.monthly"
        case proYearly = "com.photostop.pro.yearly"
        case credits10 = "com.photostop.credits.premium10"
        case credits50 = "com.photostop.credits.premium50"
        
        var displayName: String {
            switch self {
            case .proMonthly: return "PhotoStop Pro Monthly"
            case .proYearly: return "PhotoStop Pro Yearly"
            case .credits10: return "10 Premium Credits"
            case .credits50: return "50 Premium Credits"
            }
        }
        
        var isSubscription: Bool {
            switch self {
            case .proMonthly, .proYearly: return true
            case .credits10, .credits50: return false
            }
        }
        
        var creditAmount: Int? {
            switch self {
            case .credits10: return 10
            case .credits50: return 50
            default: return nil
            }
        }
    }
    
    // MARK: - Published Properties
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var isLoading = false
    @Published var purchaseError: String?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "PhotoStop", category: "StoreKitService")
    private let entitlementStore = EntitlementStore.shared
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Initialization
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Load products from App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
            
            logger.info("Loaded \(products.count) products")
            
            // Refresh subscription status after loading products
            await refreshSubscriptionStatus()
            
        } catch {
            logger.error("Failed to load products: \(error)")
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    /// Get product by ID
    func product(for id: ProductID) -> Product? {
        return products.first { $0.id == id.rawValue }
    }
    
    /// Purchase a product
    func purchase(_ productID: ProductID) async -> Bool {
        guard let product = product(for: productID) else {
            purchaseError = "Product not found"
            return false
        }
        
        logger.info("Starting purchase for \(productID.rawValue)")
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleSuccessfulPurchase(transaction, productID: productID)
                await transaction.finish()
                return true
                
            case .userCancelled:
                logger.info("User cancelled purchase")
                return false
                
            case .pending:
                logger.info("Purchase is pending")
                purchaseError = "Purchase is pending approval"
                return false
                
            @unknown default:
                logger.error("Unknown purchase result")
                purchaseError = "Unknown purchase result"
                return false
            }
            
        } catch {
            logger.error("Purchase failed: \(error)")
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Restore purchases
    func restore() async {
        logger.info("Restoring purchases")
        
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            logger.info("Purchases restored successfully")
        } catch {
            logger.error("Failed to restore purchases: \(error)")
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }
    
    /// Refresh subscription status
    func refreshSubscriptionStatus() async {
        var hasActiveSubscription = false
        var currentSubscriptionProductID: String?
        
        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productType == .autoRenewable {
                    // Check if it's one of our subscription products
                    if ProductID.allCases.contains(where: { $0.rawValue == transaction.productID && $0.isSubscription }) {
                        hasActiveSubscription = true
                        currentSubscriptionProductID = transaction.productID
                        purchasedProductIDs.insert(transaction.productID)
                        logger.info("Found active subscription: \(transaction.productID)")
                    }
                }
                
            } catch {
                logger.error("Failed to verify transaction: \(error)")
            }
        }
        
        // Update subscription status
        if hasActiveSubscription {
            subscriptionStatus = .subscribed(productID: currentSubscriptionProductID)
            entitlementStore.upgradeToPro()
        } else {
            subscriptionStatus = .notSubscribed
            entitlementStore.resetToFree()
        }
        
        // Sync entitlements with usage tracker
        entitlementStore.syncWithUsageTracker()
        
        logger.info("Subscription status updated: \(subscriptionStatus)")
    }
    
    /// Check if user has active subscription
    var hasActiveSubscription: Bool {
        switch subscriptionStatus {
        case .subscribed: return true
        case .notSubscribed, .expired, .inGracePeriod: return false
        }
    }
    
    /// Get current subscription product ID
    var currentSubscriptionProductID: String? {
        switch subscriptionStatus {
        case .subscribed(let productID): return productID
        default: return nil
        }
    }
    
    /// Show manage subscriptions sheet
    func showManageSubscriptions() async throws {
        try await AppStore.showManageSubscriptions()
    }
    
    // MARK: - Private Methods
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    await MainActor.run {
                        self.logger.info("Transaction update received: \(transaction.productID)")
                    }
                    
                    // Handle the transaction
                    if let productID = ProductID(rawValue: transaction.productID) {
                        await self.handleSuccessfulPurchase(transaction, productID: productID)
                    }
                    
                    await transaction.finish()
                    
                } catch {
                    await MainActor.run {
                        self.logger.error("Failed to handle transaction update: \(error)")
                    }
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.unverifiedTransaction
        case .verified(let safe):
            return safe
        }
    }
    
    private func handleSuccessfulPurchase(_ transaction: Transaction, productID: ProductID) async {
        logger.info("Handling successful purchase: \(productID.rawValue)")
        
        switch productID {
        case .proMonthly, .proYearly:
            // Subscription purchase
            await refreshSubscriptionStatus()
            
        case .credits10, .credits50:
            // Consumable purchase
            if let creditAmount = productID.creditAmount {
                entitlementStore.addAddonPremiumCredits(creditAmount)
                logger.info("Added \(creditAmount) premium credits")
            }
        }
        
        // Add to purchased products
        purchasedProductIDs.insert(transaction.productID)
        
        // Clear any purchase errors
        purchaseError = nil
    }
}

// MARK: - Supporting Types

extension StoreKitService {
    
    enum SubscriptionStatus: Equatable {
        case notSubscribed
        case subscribed(productID: String?)
        case expired(productID: String?)
        case inGracePeriod(productID: String?)
        
        var displayName: String {
            switch self {
            case .notSubscribed:
                return "Free"
            case .subscribed(let productID):
                if productID == ProductID.proYearly.rawValue {
                    return "Pro (Yearly)"
                } else {
                    return "Pro (Monthly)"
                }
            case .expired:
                return "Expired"
            case .inGracePeriod:
                return "Grace Period"
            }
        }
        
        var isActive: Bool {
            switch self {
            case .subscribed, .inGracePeriod:
                return true
            case .notSubscribed, .expired:
                return false
            }
        }
    }
    
    enum StoreKitError: LocalizedError {
        case unverifiedTransaction
        case productNotFound
        case purchaseFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .unverifiedTransaction:
                return "Transaction could not be verified"
            case .productNotFound:
                return "Product not found"
            case .purchaseFailed(let error):
                return "Purchase failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Convenience Methods

extension StoreKitService {
    
    /// Get monthly subscription product
    var monthlyProduct: Product? {
        return product(for: .proMonthly)
    }
    
    /// Get yearly subscription product
    var yearlyProduct: Product? {
        return product(for: .proYearly)
    }
    
    /// Get 10 credits product
    var credits10Product: Product? {
        return product(for: .credits10)
    }
    
    /// Get 50 credits product
    var credits50Product: Product? {
        return product(for: .credits50)
    }
    
    /// Calculate yearly savings percentage
    var yearlySavingsPercentage: Int {
        guard let monthly = monthlyProduct,
              let yearly = yearlyProduct else { return 0 }
        
        let monthlyAnnualPrice = monthly.price * 12
        let yearlyPrice = yearly.price
        let savings = monthlyAnnualPrice - yearlyPrice
        let percentage = (savings / monthlyAnnualPrice) * 100
        
        return Int(percentage.rounded())
    }
    
    /// Get subscription products for display
    var subscriptionProducts: [Product] {
        return products.filter { product in
            ProductID.allCases.contains { productID in
                productID.rawValue == product.id && productID.isSubscription
            }
        }
    }
    
    /// Get consumable products for display
    var consumableProducts: [Product] {
        return products.filter { product in
            ProductID.allCases.contains { productID in
                productID.rawValue == product.id && !productID.isSubscription
            }
        }
    }
}

