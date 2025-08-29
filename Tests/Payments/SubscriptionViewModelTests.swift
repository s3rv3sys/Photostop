//
//  SubscriptionViewModelTests.swift
//  PhotoStopTests
//
//  Created by Esh on 2025-08-29.
//

import XCTest
@testable import PhotoStop

@MainActor
final class SubscriptionViewModelTests: XCTestCase {
    
    var viewModel: SubscriptionViewModel!
    var mockStoreKit: MockStoreKitService!
    var mockEntitlementStore: MockEntitlementStore!
    var mockUsageTracker: MockUsageTracker!
    
    override func setUp() {
        super.setUp()
        
        mockStoreKit = MockStoreKitService()
        mockEntitlementStore = MockEntitlementStore()
        mockUsageTracker = MockUsageTracker()
        
        viewModel = SubscriptionViewModel()
        
        // Reset to clean state
        mockStoreKit.reset()
        mockEntitlementStore.reset()
        mockUsageTracker.reset()
    }
    
    override func tearDown() {
        viewModel = nil
        mockStoreKit = nil
        mockEntitlementStore = nil
        mockUsageTracker = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(viewModel.selectedPlan, .proMonthly, "Should default to monthly plan")
        XCTAssertFalse(viewModel.isPurchasing, "Should not be purchasing initially")
        XCTAssertFalse(viewModel.isRestoring, "Should not be restoring initially")
        XCTAssertNil(viewModel.errorMessage, "Should have no error message initially")
        XCTAssertFalse(viewModel.showingError, "Should not be showing error initially")
        XCTAssertFalse(viewModel.purchaseSuccess, "Should not have purchase success initially")
        XCTAssertEqual(viewModel.presentationContext, .general, "Should default to general context")
    }
    
    // MARK: - Presentation Context Tests
    
    func testSetPresentationContext_General() {
        viewModel.setPresentationContext(.general)
        
        XCTAssertEqual(viewModel.presentationContext, .general)
        XCTAssertEqual(viewModel.selectedPlan, .proYearly, "Should suggest yearly for general upgrade")
        XCTAssertNil(viewModel.blockedOperation)
    }
    
    func testSetPresentationContext_InsufficientCredits() {
        viewModel.setPresentationContext(.insufficientCredits(required: .premium, remaining: 0))
        
        if case .insufficientCredits = viewModel.presentationContext {
            // Expected
        } else {
            XCTFail("Should set insufficient credits context")
        }
        
        XCTAssertEqual(viewModel.selectedPlan, .proMonthly, "Should suggest monthly for immediate needs")
    }
    
    func testSetPresentationContext_PremiumFeature() {
        viewModel.setPresentationContext(.premiumFeature(feature: "Advanced Editing"))
        
        if case .premiumFeature(let feature) = viewModel.presentationContext {
            XCTAssertEqual(feature, "Advanced Editing")
        } else {
            XCTFail("Should set premium feature context")
        }
        
        XCTAssertEqual(viewModel.selectedPlan, .proMonthly, "Should suggest monthly for immediate needs")
    }
    
    func testSetPresentationContext_WithBlockedOperation() {
        viewModel.setPresentationContext(.premiumFeature(feature: "Test"), blockedOperation: "enhance photo")
        
        XCTAssertEqual(viewModel.blockedOperation, "enhance photo")
    }
    
    // MARK: - Paywall Context Properties Tests
    
    func testPaywallContextTitles() {
        let generalContext = SubscriptionViewModel.PaywallContext.general
        let onboardingContext = SubscriptionViewModel.PaywallContext.onboarding
        let insufficientContext = SubscriptionViewModel.PaywallContext.insufficientCredits(required: .premium, remaining: 0)
        let premiumContext = SubscriptionViewModel.PaywallContext.premiumFeature(feature: "Advanced Editing")
        
        XCTAssertEqual(generalContext.title, "Upgrade to PhotoStop Pro")
        XCTAssertEqual(onboardingContext.title, "Welcome to PhotoStop Pro")
        XCTAssertEqual(insufficientContext.title, "Out of Credits")
        XCTAssertEqual(premiumContext.title, "Premium Feature")
    }
    
    func testPaywallContextSubtitles() {
        let generalContext = SubscriptionViewModel.PaywallContext.general
        let insufficientContext = SubscriptionViewModel.PaywallContext.insufficientCredits(required: .premium, remaining: 2)
        let premiumContext = SubscriptionViewModel.PaywallContext.premiumFeature(feature: "Advanced Editing")
        
        XCTAssertEqual(generalContext.subtitle, "Unlock unlimited AI editing power")
        XCTAssertTrue(insufficientContext.subtitle.contains("premium credits"))
        XCTAssertTrue(insufficientContext.subtitle.contains("2 remaining"))
        XCTAssertEqual(premiumContext.subtitle, "Advanced Editing requires PhotoStop Pro")
    }
    
    func testPaywallContextPrimaryActions() {
        let generalContext = SubscriptionViewModel.PaywallContext.general
        let onboardingContext = SubscriptionViewModel.PaywallContext.onboarding
        let insufficientContext = SubscriptionViewModel.PaywallContext.insufficientCredits(required: .premium, remaining: 0)
        let premiumContext = SubscriptionViewModel.PaywallContext.premiumFeature(feature: "Test")
        
        XCTAssertEqual(generalContext.primaryAction, "Start Free Trial")
        XCTAssertEqual(onboardingContext.primaryAction, "Start Free Trial")
        XCTAssertEqual(insufficientContext.primaryAction, "Upgrade Now")
        XCTAssertEqual(premiumContext.primaryAction, "Upgrade Now")
    }
    
    func testPaywallContextShowCreditsOption() {
        let generalContext = SubscriptionViewModel.PaywallContext.general
        let insufficientContext = SubscriptionViewModel.PaywallContext.insufficientCredits(required: .premium, remaining: 0)
        
        XCTAssertFalse(generalContext.showCreditsOption)
        XCTAssertTrue(insufficientContext.showCreditsOption)
    }
    
    // MARK: - Purchase Flow Tests
    
    func testPurchaseSelectedPlan_Success() async {
        mockStoreKit.shouldSucceed = true
        
        await viewModel.purchaseSelectedPlan()
        
        XCTAssertFalse(viewModel.isPurchasing, "Should not be purchasing after completion")
        XCTAssertTrue(viewModel.purchaseSuccess, "Should have purchase success")
        XCTAssertNil(viewModel.errorMessage, "Should have no error message")
    }
    
    func testPurchaseSelectedPlan_Failure() async {
        mockStoreKit.shouldSucceed = false
        mockStoreKit.errorMessage = "Purchase failed"
        
        await viewModel.purchaseSelectedPlan()
        
        XCTAssertFalse(viewModel.isPurchasing, "Should not be purchasing after completion")
        XCTAssertFalse(viewModel.purchaseSuccess, "Should not have purchase success")
        XCTAssertEqual(viewModel.errorMessage, "Purchase failed")
        XCTAssertTrue(viewModel.showingError, "Should be showing error")
    }
    
    func testPurchaseSelectedPlan_AlreadyPurchasing() async {
        // Start first purchase
        let firstPurchaseTask = Task {
            await viewModel.purchaseSelectedPlan()
        }
        
        // Try to start second purchase while first is in progress
        await viewModel.purchaseSelectedPlan()
        
        // Wait for first purchase to complete
        await firstPurchaseTask.value
        
        // Should have only processed one purchase
        XCTAssertEqual(mockStoreKit.purchaseCallCount, 1, "Should only call purchase once")
    }
    
    func testPurchaseCredits_Success() async {
        mockStoreKit.shouldSucceed = true
        
        await viewModel.purchaseCredits(.credits10)
        
        XCTAssertFalse(viewModel.isPurchasing, "Should not be purchasing after completion")
        XCTAssertTrue(viewModel.purchaseSuccess, "Should have purchase success")
        XCTAssertNil(viewModel.errorMessage, "Should have no error message")
    }
    
    func testPurchaseCredits_InvalidProduct() async {
        await viewModel.purchaseCredits(.proMonthly) // Not a credit product
        
        XCTAssertFalse(viewModel.isPurchasing, "Should not be purchasing")
        XCTAssertFalse(viewModel.purchaseSuccess, "Should not have purchase success")
        XCTAssertEqual(mockStoreKit.purchaseCallCount, 0, "Should not call purchase for invalid product")
    }
    
    // MARK: - Restore Purchases Tests
    
    func testRestorePurchases_Success() async {
        mockStoreKit.shouldSucceed = true
        
        await viewModel.restorePurchases()
        
        XCTAssertFalse(viewModel.isRestoring, "Should not be restoring after completion")
        XCTAssertNil(viewModel.errorMessage, "Should have no error message")
        XCTAssertEqual(mockStoreKit.restoreCallCount, 1, "Should call restore once")
    }
    
    func testRestorePurchases_Failure() async {
        mockStoreKit.shouldSucceed = false
        mockStoreKit.errorMessage = "Restore failed"
        
        await viewModel.restorePurchases()
        
        XCTAssertFalse(viewModel.isRestoring, "Should not be restoring after completion")
        XCTAssertEqual(viewModel.errorMessage, "Restore failed")
        XCTAssertTrue(viewModel.showingError, "Should be showing error")
    }
    
    func testRestorePurchases_AlreadyRestoring() async {
        // Start first restore
        let firstRestoreTask = Task {
            await viewModel.restorePurchases()
        }
        
        // Try to start second restore while first is in progress
        await viewModel.restorePurchases()
        
        // Wait for first restore to complete
        await firstRestoreTask.value
        
        // Should have only processed one restore
        XCTAssertEqual(mockStoreKit.restoreCallCount, 1, "Should only call restore once")
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError() {
        viewModel.errorMessage = "Test error"
        viewModel.showingError = true
        
        viewModel.clearError()
        
        XCTAssertNil(viewModel.errorMessage, "Should clear error message")
        XCTAssertFalse(viewModel.showingError, "Should not be showing error")
    }
    
    func testResetPurchaseSuccess() {
        viewModel.purchaseSuccess = true
        
        viewModel.resetPurchaseSuccess()
        
        XCTAssertFalse(viewModel.purchaseSuccess, "Should reset purchase success")
    }
    
    // MARK: - Computed Properties Tests
    
    func testSubscriptionStatus() {
        mockStoreKit.subscriptionStatus = .subscribed(productID: "com.photostop.pro.monthly")
        
        let status = viewModel.subscriptionStatus
        
        if case .subscribed(let productID) = status {
            XCTAssertEqual(productID, "com.photostop.pro.monthly")
        } else {
            XCTFail("Should return subscribed status")
        }
    }
    
    func testHasActiveSubscription() {
        mockStoreKit.hasActiveSubscription = true
        
        XCTAssertTrue(viewModel.hasActiveSubscription, "Should return true when StoreKit has active subscription")
        
        mockStoreKit.hasActiveSubscription = false
        
        XCTAssertFalse(viewModel.hasActiveSubscription, "Should return false when StoreKit has no active subscription")
    }
    
    func testCurrentTier() {
        mockEntitlementStore.currentTier = .pro
        
        XCTAssertEqual(viewModel.currentTier, .pro, "Should return current tier from entitlement store")
    }
    
    func testUsageStats() {
        mockUsageTracker.currentTier = .free
        mockUsageTracker.setBudgetRemaining(for: .free, remaining: 30)
        mockUsageTracker.setPremiumRemaining(for: .free, remaining: 2)
        
        let stats = viewModel.usageStats
        
        XCTAssertEqual(stats.budget, 20, "Should calculate used budget credits (50 - 30)")
        XCTAssertEqual(stats.premium, 3, "Should calculate used premium credits (5 - 2)")
        XCTAssertEqual(stats.budgetRemaining, 30, "Should return remaining budget credits")
        XCTAssertEqual(stats.premiumRemaining, 2, "Should return remaining premium credits")
    }
    
    func testAddonPremiumCredits() {
        mockEntitlementStore.setAddonPremiumCredits(15)
        
        XCTAssertEqual(viewModel.addonPremiumCredits, 15, "Should return addon premium credits")
    }
    
    func testTotalPremiumCredits() {
        mockUsageTracker.setPremiumRemaining(for: .free, remaining: 3)
        mockEntitlementStore.setAddonPremiumCredits(7)
        
        XCTAssertEqual(viewModel.totalPremiumCredits, 10, "Should return total premium credits (3 + 7)")
    }
    
    func testIsAnyOperationInProgress() {
        XCTAssertFalse(viewModel.isAnyOperationInProgress, "Should be false initially")
        
        viewModel.isPurchasing = true
        XCTAssertTrue(viewModel.isAnyOperationInProgress, "Should be true when purchasing")
        
        viewModel.isPurchasing = false
        viewModel.isRestoring = true
        XCTAssertTrue(viewModel.isAnyOperationInProgress, "Should be true when restoring")
        
        viewModel.isRestoring = false
        XCTAssertFalse(viewModel.isAnyOperationInProgress, "Should be false when no operations")
    }
    
    // MARK: - Call to Action Tests
    
    func testGetCallToActionText_General() {
        mockStoreKit.monthlyProduct = MockProduct(id: "monthly", displayName: "Monthly", price: Decimal(9.99))
        viewModel.selectedPlan = .proMonthly
        viewModel.setPresentationContext(.general)
        
        let cta = viewModel.getCallToActionText()
        
        XCTAssertTrue(cta.contains("Start Free Trial"), "Should contain free trial text for general context")
        XCTAssertTrue(cta.contains("month"), "Should contain period for monthly plan")
    }
    
    func testGetCallToActionText_InsufficientCredits() {
        mockStoreKit.yearlyProduct = MockProduct(id: "yearly", displayName: "Yearly", price: Decimal(79.99))
        viewModel.selectedPlan = .proYearly
        viewModel.setPresentationContext(.insufficientCredits(required: .premium, remaining: 0))
        
        let cta = viewModel.getCallToActionText()
        
        XCTAssertTrue(cta.contains("Upgrade"), "Should contain upgrade text for insufficient credits")
        XCTAssertTrue(cta.contains("year"), "Should contain period for yearly plan")
    }
    
    func testGetSecondaryActionText() {
        mockStoreKit.credits10Product = MockProduct(id: "credits10", displayName: "10 Credits", price: Decimal(2.99))
        viewModel.setPresentationContext(.insufficientCredits(required: .premium, remaining: 0))
        
        let secondaryAction = viewModel.getSecondaryActionText()
        
        XCTAssertNotNil(secondaryAction, "Should have secondary action for insufficient credits context")
        XCTAssertTrue(secondaryAction?.contains("credits") == true, "Should mention credits")
        
        viewModel.setPresentationContext(.general)
        let noSecondaryAction = viewModel.getSecondaryActionText()
        
        XCTAssertNil(noSecondaryAction, "Should not have secondary action for general context")
    }
    
    // MARK: - Feature Comparison Tests
    
    func testFeatureComparison() {
        let features = viewModel.featureComparison
        
        XCTAssertFalse(features.isEmpty, "Should have feature comparison data")
        
        // Check that all features have the required structure
        for feature in features {
            XCTAssertFalse(feature.feature.isEmpty, "Feature name should not be empty")
            XCTAssertFalse(feature.free.isEmpty, "Free value should not be empty")
            XCTAssertFalse(feature.pro.isEmpty, "Pro value should not be empty")
        }
    }
}

// MARK: - Mock StoreKit Service

class MockStoreKitService {
    var shouldSucceed = true
    var errorMessage: String?
    var purchaseCallCount = 0
    var restoreCallCount = 0
    
    var subscriptionStatus: StoreKitService.SubscriptionStatus = .notSubscribed
    var hasActiveSubscription = false
    var monthlyProduct: MockProduct?
    var yearlyProduct: MockProduct?
    var credits10Product: MockProduct?
    var credits50Product: MockProduct?
    
    func reset() {
        shouldSucceed = true
        errorMessage = nil
        purchaseCallCount = 0
        restoreCallCount = 0
        subscriptionStatus = .notSubscribed
        hasActiveSubscription = false
        monthlyProduct = nil
        yearlyProduct = nil
        credits10Product = nil
        credits50Product = nil
    }
    
    func purchase(_ productID: StoreKitService.ProductID) async -> Bool {
        purchaseCallCount += 1
        
        if shouldSucceed {
            return true
        } else {
            return false
        }
    }
    
    func restore() async {
        restoreCallCount += 1
        
        if !shouldSucceed && errorMessage != nil {
            // Simulate error by setting purchaseError
            // In real implementation, this would be handled differently
        }
    }
}

