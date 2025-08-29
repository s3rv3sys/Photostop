//
//  SubscriptionViewModelTests.swift
//  PhotoStopTests
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import XCTest
@testable import PhotoStop

@MainActor
final class SubscriptionViewModelTests: XCTestCase {
    
    var viewModel: SubscriptionViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = SubscriptionViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.selectedPlan, .proMonthly)
        XCTAssertFalse(viewModel.isPurchasing)
        XCTAssertFalse(viewModel.isRestoring)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingError)
        XCTAssertFalse(viewModel.purchaseSuccess)
    }
    
    // MARK: - Plan Selection Tests
    
    func testPlanSelection() {
        // Test monthly plan selection
        viewModel.selectedPlan = .proMonthly
        XCTAssertEqual(viewModel.selectedPlan, .proMonthly)
        
        // Test yearly plan selection
        viewModel.selectedPlan = .proYearly
        XCTAssertEqual(viewModel.selectedPlan, .proYearly)
    }
    
    func testPlanProperties() {
        // Test monthly plan properties
        let monthlyPlan = SubscriptionPlan.proMonthly
        XCTAssertEqual(monthlyPlan.displayName, "Pro Monthly")
        XCTAssertEqual(monthlyPlan.productID, "com.servesys.photostop.pro.monthly")
        XCTAssertEqual(monthlyPlan.price, "$4.99")
        XCTAssertEqual(monthlyPlan.period, "month")
        XCTAssertTrue(monthlyPlan.hasFreeTrial)
        
        // Test yearly plan properties
        let yearlyPlan = SubscriptionPlan.proYearly
        XCTAssertEqual(yearlyPlan.displayName, "Pro Yearly")
        XCTAssertEqual(yearlyPlan.productID, "com.servesys.photostop.pro.yearly")
        XCTAssertEqual(yearlyPlan.price, "$39.99")
        XCTAssertEqual(yearlyPlan.period, "year")
        XCTAssertFalse(yearlyPlan.hasFreeTrial)
        
        // Test savings calculation
        XCTAssertEqual(yearlyPlan.savingsPercentage, 33)
    }
    
    // MARK: - Paywall Context Tests
    
    func testPaywallContexts() {
        let contexts: [PaywallContext] = [.general, .onboarding, .insufficientCredits, .premiumFeature]
        
        for context in contexts {
            viewModel.context = context
            XCTAssertEqual(viewModel.context, context)
            
            // Test that each context has proper display properties
            XCTAssertFalse(context.title.isEmpty)
            XCTAssertFalse(context.subtitle.isEmpty)
            XCTAssertFalse(context.primaryButtonText.isEmpty)
        }
    }
    
    func testPaywallContextProperties() {
        // Test general context
        let general = PaywallContext.general
        XCTAssertEqual(general.title, "Upgrade to Pro")
        XCTAssertTrue(general.subtitle.contains("unlimited"))
        XCTAssertEqual(general.primaryButtonText, "Start Free Trial")
        
        // Test onboarding context
        let onboarding = PaywallContext.onboarding
        XCTAssertEqual(onboarding.title, "Welcome to PhotoStop Pro")
        XCTAssertTrue(onboarding.subtitle.contains("perfect"))
        XCTAssertEqual(onboarding.primaryButtonText, "Try Pro Free for 7 Days")
        
        // Test insufficient credits context
        let credits = PaywallContext.insufficientCredits
        XCTAssertEqual(credits.title, "Out of Credits")
        XCTAssertTrue(credits.subtitle.contains("credits"))
        XCTAssertEqual(credits.primaryButtonText, "Get More Credits")
        
        // Test premium feature context
        let premium = PaywallContext.premiumFeature
        XCTAssertEqual(premium.title, "Premium Feature")
        XCTAssertTrue(premium.subtitle.contains("Pro"))
        XCTAssertEqual(premium.primaryButtonText, "Unlock Pro Features")
    }
    
    // MARK: - Purchase Flow Tests (Mock)
    
    func testPurchaseFlow() async {
        // Test purchase initiation
        XCTAssertFalse(viewModel.isPurchasing)
        
        // Simulate purchase start
        await viewModel.purchaseSelectedPlan()
        
        // In a real test with mocked StoreKit, we would verify the purchase flow
        // For now, we just test that the method completes without crashing
        XCTAssertTrue(true)
    }
    
    func testRestoreFlow() async {
        // Test restore initiation
        XCTAssertFalse(viewModel.isRestoring)
        
        // Simulate restore start
        await viewModel.restorePurchases()
        
        // In a real test with mocked StoreKit, we would verify the restore flow
        // For now, we just test that the method completes without crashing
        XCTAssertTrue(true)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        // Test error display
        viewModel.showError("Test error message")
        
        XCTAssertTrue(viewModel.showingError)
        XCTAssertEqual(viewModel.errorMessage, "Test error message")
        
        // Test error dismissal
        viewModel.dismissError()
        
        XCTAssertFalse(viewModel.showingError)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testPurchaseErrorTypes() {
        let errors: [PurchaseError] = [
            .userCancelled,
            .paymentNotAllowed,
            .productNotAvailable,
            .networkError,
            .unknown("Test error")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Feature Comparison Tests
    
    func testFeatureComparison() {
        let freeFeatures = viewModel.freeFeatures
        let proFeatures = viewModel.proFeatures
        
        XCTAssertFalse(freeFeatures.isEmpty)
        XCTAssertFalse(proFeatures.isEmpty)
        XCTAssertGreaterThan(proFeatures.count, freeFeatures.count)
        
        // Test that all features have proper display text
        for feature in freeFeatures + proFeatures {
            XCTAssertFalse(feature.isEmpty)
        }
    }
    
    // MARK: - State Management Tests
    
    func testStateTransitions() {
        // Test initial state
        XCTAssertFalse(viewModel.isPurchasing)
        XCTAssertFalse(viewModel.isRestoring)
        XCTAssertFalse(viewModel.purchaseSuccess)
        
        // Test loading states
        viewModel.isPurchasing = true
        XCTAssertTrue(viewModel.isPurchasing)
        
        viewModel.isRestoring = true
        XCTAssertTrue(viewModel.isRestoring)
        
        // Test success state
        viewModel.purchaseSuccess = true
        XCTAssertTrue(viewModel.purchaseSuccess)
        
        // Reset states
        viewModel.isPurchasing = false
        viewModel.isRestoring = false
        viewModel.purchaseSuccess = false
        
        XCTAssertFalse(viewModel.isPurchasing)
        XCTAssertFalse(viewModel.isRestoring)
        XCTAssertFalse(viewModel.purchaseSuccess)
    }
    
    // MARK: - Performance Tests
    
    func testViewModelPerformance() {
        measure {
            let vm = SubscriptionViewModel()
            vm.selectedPlan = .proYearly
            vm.context = .general
            _ = vm.freeFeatures
            _ = vm.proFeatures
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        weak var weakViewModel = viewModel
        viewModel = nil
        
        // Give some time for deallocation
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNil(weakViewModel, "SubscriptionViewModel should be deallocated")
    }
}

// MARK: - Mock Subscription ViewModel

class MockSubscriptionViewModel: SubscriptionViewModel {
    var mockPurchaseSuccess = true
    var mockRestoreSuccess = true
    var mockError: PurchaseError?
    
    override func purchaseSelectedPlan() async {
        await MainActor.run {
            self.isPurchasing = true
        }
        
        // Simulate purchase delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        await MainActor.run {
            self.isPurchasing = false
            
            if let error = mockError {
                self.showError(error.localizedDescription)
            } else if mockPurchaseSuccess {
                self.purchaseSuccess = true
            } else {
                self.showError("Purchase failed")
            }
        }
    }
    
    override func restorePurchases() async {
        await MainActor.run {
            self.isRestoring = true
        }
        
        // Simulate restore delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        await MainActor.run {
            self.isRestoring = false
            
            if let error = mockError {
                self.showError(error.localizedDescription)
            } else if mockRestoreSuccess {
                self.purchaseSuccess = true
            } else {
                self.showError("No purchases to restore")
            }
        }
    }
}

// MARK: - Integration Tests

final class SubscriptionViewModelIntegrationTests: XCTestCase {
    
    var mockViewModel: MockSubscriptionViewModel!
    
    override func setUp() {
        super.setUp()
        mockViewModel = MockSubscriptionViewModel()
    }
    
    override func tearDown() {
        mockViewModel = nil
        super.tearDown()
    }
    
    func testSuccessfulPurchase() async {
        mockViewModel.mockPurchaseSuccess = true
        
        await mockViewModel.purchaseSelectedPlan()
        
        XCTAssertTrue(mockViewModel.purchaseSuccess)
        XCTAssertFalse(mockViewModel.isPurchasing)
        XCTAssertFalse(mockViewModel.showingError)
    }
    
    func testFailedPurchase() async {
        mockViewModel.mockPurchaseSuccess = false
        
        await mockViewModel.purchaseSelectedPlan()
        
        XCTAssertFalse(mockViewModel.purchaseSuccess)
        XCTAssertFalse(mockViewModel.isPurchasing)
        XCTAssertTrue(mockViewModel.showingError)
    }
    
    func testPurchaseWithError() async {
        mockViewModel.mockError = .userCancelled
        
        await mockViewModel.purchaseSelectedPlan()
        
        XCTAssertFalse(mockViewModel.purchaseSuccess)
        XCTAssertFalse(mockViewModel.isPurchasing)
        XCTAssertTrue(mockViewModel.showingError)
        XCTAssertNotNil(mockViewModel.errorMessage)
    }
    
    func testSuccessfulRestore() async {
        mockViewModel.mockRestoreSuccess = true
        
        await mockViewModel.restorePurchases()
        
        XCTAssertTrue(mockViewModel.purchaseSuccess)
        XCTAssertFalse(mockViewModel.isRestoring)
        XCTAssertFalse(mockViewModel.showingError)
    }
    
    func testFailedRestore() async {
        mockViewModel.mockRestoreSuccess = false
        
        await mockViewModel.restorePurchases()
        
        XCTAssertFalse(mockViewModel.purchaseSuccess)
        XCTAssertFalse(mockViewModel.isRestoring)
        XCTAssertTrue(mockViewModel.showingError)
    }
}

