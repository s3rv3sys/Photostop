//
//  SubscriptionViewModel.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import Foundation
import StoreKit
import Combine
import os.log

/// ViewModel for subscription management and paywall presentation
@MainActor
final class SubscriptionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedPlan: StoreKitService.ProductID = .proMonthly
    @Published var isPurchasing = false
    @Published var isRestoring = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var purchaseSuccess = false
    
    // Paywall presentation context
    @Published var presentationContext: PaywallContext = .general
    @Published var blockedOperation: String?
    
    // MARK: - Services
    
    private let storeKit = StoreKitService.shared
    private let entitlementStore = EntitlementStore.shared
    private let usageTracker = UsageTracker.shared
    private let logger = Logger(subsystem: "PhotoStop", category: "SubscriptionViewModel")
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Purchase the selected subscription plan
    func purchaseSelectedPlan() async {
        guard !isPurchasing else { return }
        
        isPurchasing = true
        errorMessage = nil
        
        logger.info("Starting purchase for \(selectedPlan.rawValue)")
        
        let success = await storeKit.purchase(selectedPlan)
        
        await MainActor.run {
            isPurchasing = false
            
            if success {
                purchaseSuccess = true
                logger.info("Purchase successful")
            } else {
                errorMessage = storeKit.purchaseError
                showingError = true
                logger.error("Purchase failed: \(storeKit.purchaseError ?? "Unknown error")")
            }
        }
    }
    
    /// Purchase consumable credits
    func purchaseCredits(_ productID: StoreKitService.ProductID) async {
        guard !isPurchasing else { return }
        guard productID == .credits10 || productID == .credits50 else { return }
        
        isPurchasing = true
        errorMessage = nil
        
        logger.info("Starting credits purchase for \(productID.rawValue)")
        
        let success = await storeKit.purchase(productID)
        
        await MainActor.run {
            isPurchasing = false
            
            if success {
                purchaseSuccess = true
                logger.info("Credits purchase successful")
            } else {
                errorMessage = storeKit.purchaseError
                showingError = true
                logger.error("Credits purchase failed: \(storeKit.purchaseError ?? "Unknown error")")
            }
        }
    }
    
    /// Restore previous purchases
    func restorePurchases() async {
        guard !isRestoring else { return }
        
        isRestoring = true
        errorMessage = nil
        
        logger.info("Restoring purchases")
        
        await storeKit.restore()
        
        await MainActor.run {
            isRestoring = false
            
            if let error = storeKit.purchaseError {
                errorMessage = error
                showingError = true
                logger.error("Restore failed: \(error)")
            } else {
                logger.info("Restore completed")
            }
        }
    }
    
    /// Set paywall presentation context
    func setPresentationContext(_ context: PaywallContext, blockedOperation: String? = nil) {
        presentationContext = context
        self.blockedOperation = blockedOperation
        
        // Auto-select appropriate plan based on context
        switch context {
        case .insufficientCredits, .premiumFeature:
            // For immediate needs, suggest monthly
            selectedPlan = .proMonthly
        case .general, .onboarding:
            // For general upgrade, suggest yearly for better value
            selectedPlan = .proYearly
        }
    }
    
    /// Clear error state
    func clearError() {
        errorMessage = nil
        showingError = false
    }
    
    /// Reset purchase success state
    func resetPurchaseSuccess() {
        purchaseSuccess = false
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Listen for StoreKit errors
        storeKit.$purchaseError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = error
                self?.showingError = true
            }
            .store(in: &cancellables)
        
        // Listen for subscription status changes
        storeKit.$subscriptionStatus
            .sink { [weak self] status in
                self?.logger.info("Subscription status changed: \(status)")
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

extension SubscriptionViewModel {
    
    enum PaywallContext {
        case general
        case onboarding
        case insufficientCredits(required: CostClass, remaining: Int)
        case premiumFeature(feature: String)
        
        var title: String {
            switch self {
            case .general:
                return "Upgrade to PhotoStop Pro"
            case .onboarding:
                return "Welcome to PhotoStop Pro"
            case .insufficientCredits:
                return "Out of Credits"
            case .premiumFeature:
                return "Premium Feature"
            }
        }
        
        var subtitle: String {
            switch self {
            case .general:
                return "Unlock unlimited AI editing power"
            case .onboarding:
                return "Get the most out of your photos"
            case .insufficientCredits(let required, let remaining):
                return "You need \(required.description) credits but only have \(remaining) remaining"
            case .premiumFeature(let feature):
                return "\(feature) requires PhotoStop Pro"
            }
        }
        
        var primaryAction: String {
            switch self {
            case .general, .onboarding:
                return "Start Free Trial"
            case .insufficientCredits, .premiumFeature:
                return "Upgrade Now"
            }
        }
        
        var showCreditsOption: Bool {
            switch self {
            case .insufficientCredits:
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Computed Properties

extension SubscriptionViewModel {
    
    /// Current subscription status
    var subscriptionStatus: StoreKitService.SubscriptionStatus {
        storeKit.subscriptionStatus
    }
    
    /// Whether user has active subscription
    var hasActiveSubscription: Bool {
        storeKit.hasActiveSubscription
    }
    
    /// Current user tier
    var currentTier: UserTier {
        entitlementStore.current().tier
    }
    
    /// Current entitlements
    var currentEntitlements: Entitlements {
        entitlementStore.current()
    }
    
    /// Usage statistics
    var usageStats: (budget: Int, premium: Int, budgetRemaining: Int, premiumRemaining: Int) {
        let tier = currentTier
        let budgetRemaining = usageTracker.remaining(for: tier, cost: .budget)
        let premiumRemaining = usageTracker.remaining(for: tier, cost: .premium)
        let budgetCapacity = usageTracker.capacity(for: tier, cost: .budget)
        let premiumCapacity = usageTracker.capacity(for: tier, cost: .premium)
        
        return (
            budget: budgetCapacity - budgetRemaining,
            premium: premiumCapacity - premiumRemaining,
            budgetRemaining: budgetRemaining,
            premiumRemaining: premiumRemaining
        )
    }
    
    /// Addon premium credits
    var addonPremiumCredits: Int {
        entitlementStore.getAddonPremiumCredits()
    }
    
    /// Total effective premium credits
    var totalPremiumCredits: Int {
        let stats = usageStats
        return stats.premiumRemaining + addonPremiumCredits
    }
    
    /// Monthly subscription product
    var monthlyProduct: Product? {
        storeKit.monthlyProduct
    }
    
    /// Yearly subscription product
    var yearlyProduct: Product? {
        storeKit.yearlyProduct
    }
    
    /// 10 credits product
    var credits10Product: Product? {
        storeKit.credits10Product
    }
    
    /// 50 credits product
    var credits50Product: Product? {
        storeKit.credits50Product
    }
    
    /// Yearly savings percentage
    var yearlySavingsPercentage: Int {
        storeKit.yearlySavingsPercentage
    }
    
    /// Whether any purchase operation is in progress
    var isAnyOperationInProgress: Bool {
        isPurchasing || isRestoring
    }
    
    /// Feature comparison data for UI
    var featureComparison: [(feature: String, free: String, pro: String)] {
        Entitlements.featureComparison()
    }
}

// MARK: - Paywall Presentation Helpers

extension SubscriptionViewModel {
    
    /// Create paywall context for insufficient credits
    static func insufficientCreditsContext(required: CostClass, remaining: Int) -> PaywallContext {
        return .insufficientCredits(required: required, remaining: remaining)
    }
    
    /// Create paywall context for premium feature
    static func premiumFeatureContext(feature: String) -> PaywallContext {
        return .premiumFeature(feature: feature)
    }
    
    /// Get appropriate call-to-action text based on context and selected plan
    func getCallToActionText() -> String {
        let product = selectedPlan == .proMonthly ? monthlyProduct : yearlyProduct
        let price = product?.displayPrice ?? "$9.99"
        let period = selectedPlan == .proMonthly ? "month" : "year"
        
        switch presentationContext {
        case .general, .onboarding:
            return "Start Free Trial - \(price)/\(period)"
        case .insufficientCredits, .premiumFeature:
            return "Upgrade for \(price)/\(period)"
        }
    }
    
    /// Get secondary action text (for credits option)
    func getSecondaryActionText() -> String? {
        guard presentationContext.showCreditsOption else { return nil }
        
        if let credits10 = credits10Product {
            return "Just buy \(credits10.displayPrice) credits"
        }
        return "Buy credits instead"
    }
}

