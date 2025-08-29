//
//  EntitlementsTests.swift
//  PhotoStopTests
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import XCTest
@testable import PhotoStop

final class EntitlementsTests: XCTestCase {
    
    var entitlementStore: EntitlementStore!
    
    override func setUp() {
        super.setUp()
        entitlementStore = EntitlementStore.shared
        entitlementStore.reset()
    }
    
    override func tearDown() {
        entitlementStore.reset()
        entitlementStore = nil
        super.tearDown()
    }
    
    // MARK: - UserTier Tests
    
    func testUserTierProperties() {
        // Test Free tier
        XCTAssertEqual(UserTier.free.displayName, "Free")
        XCTAssertEqual(UserTier.free.budgetCreditsPerMonth, 50)
        XCTAssertEqual(UserTier.free.premiumCreditsPerMonth, 5)
        XCTAssertFalse(UserTier.free.hasUnlimitedEdits)
        XCTAssertFalse(UserTier.free.hasPriorityProcessing)
        XCTAssertFalse(UserTier.free.hasAdvancedFeatures)
        
        // Test Pro tier
        XCTAssertEqual(UserTier.pro.displayName, "Pro")
        XCTAssertEqual(UserTier.pro.budgetCreditsPerMonth, 500)
        XCTAssertEqual(UserTier.pro.premiumCreditsPerMonth, 300)
        XCTAssertTrue(UserTier.pro.hasUnlimitedEdits)
        XCTAssertTrue(UserTier.pro.hasPriorityProcessing)
        XCTAssertTrue(UserTier.pro.hasAdvancedFeatures)
    }
    
    func testUserTierComparison() {
        XCTAssertTrue(UserTier.pro.budgetCreditsPerMonth > UserTier.free.budgetCreditsPerMonth)
        XCTAssertTrue(UserTier.pro.premiumCreditsPerMonth > UserTier.free.premiumCreditsPerMonth)
    }
    
    // MARK: - Entitlements Tests
    
    func testInitialEntitlements() {
        let entitlements = entitlementStore.currentEntitlements
        
        XCTAssertEqual(entitlements.userTier, .free)
        XCTAssertFalse(entitlements.hasActiveSubscription)
        XCTAssertNil(entitlements.subscriptionExpiryDate)
        XCTAssertEqual(entitlements.addonPremiumCredits, 0)
    }
    
    func testEntitlementFeatures() {
        let freeEntitlements = entitlementStore.currentEntitlements
        
        // Test free tier features
        XCTAssertEqual(freeEntitlements.budgetCreditsPerMonth, 50)
        XCTAssertEqual(freeEntitlements.premiumCreditsPerMonth, 5)
        XCTAssertFalse(freeEntitlements.hasUnlimitedEdits)
        XCTAssertFalse(freeEntitlements.hasPriorityProcessing)
        XCTAssertFalse(freeEntitlements.hasAdvancedFeatures)
        
        // Upgrade to Pro
        entitlementStore.updateSubscription(tier: .pro, expiryDate: Date().addingTimeInterval(86400 * 30))
        
        let proEntitlements = entitlementStore.currentEntitlements
        
        // Test pro tier features
        XCTAssertEqual(proEntitlements.budgetCreditsPerMonth, 500)
        XCTAssertEqual(proEntitlements.premiumCreditsPerMonth, 300)
        XCTAssertTrue(proEntitlements.hasUnlimitedEdits)
        XCTAssertTrue(proEntitlements.hasPriorityProcessing)
        XCTAssertTrue(proEntitlements.hasAdvancedFeatures)
        XCTAssertTrue(proEntitlements.hasActiveSubscription)
    }
    
    // MARK: - Subscription Management Tests
    
    func testSubscriptionUpdate() {
        let expiryDate = Date().addingTimeInterval(86400 * 30) // 30 days from now
        
        // Update to Pro subscription
        entitlementStore.updateSubscription(tier: .pro, expiryDate: expiryDate)
        
        let entitlements = entitlementStore.currentEntitlements
        XCTAssertEqual(entitlements.userTier, .pro)
        XCTAssertTrue(entitlements.hasActiveSubscription)
        XCTAssertEqual(entitlements.subscriptionExpiryDate, expiryDate)
    }
    
    func testSubscriptionExpiry() {
        let pastDate = Date().addingTimeInterval(-86400) // 1 day ago
        
        // Set expired subscription
        entitlementStore.updateSubscription(tier: .pro, expiryDate: pastDate)
        
        let entitlements = entitlementStore.currentEntitlements
        XCTAssertEqual(entitlements.userTier, .free) // Should downgrade to free
        XCTAssertFalse(entitlements.hasActiveSubscription)
    }
    
    func testSubscriptionCancellation() {
        // First set active subscription
        entitlementStore.updateSubscription(tier: .pro, expiryDate: Date().addingTimeInterval(86400 * 30))
        XCTAssertTrue(entitlementStore.currentEntitlements.hasActiveSubscription)
        
        // Cancel subscription
        entitlementStore.cancelSubscription()
        
        let entitlements = entitlementStore.currentEntitlements
        XCTAssertEqual(entitlements.userTier, .free)
        XCTAssertFalse(entitlements.hasActiveSubscription)
        XCTAssertNil(entitlements.subscriptionExpiryDate)
    }
    
    // MARK: - Addon Credits Tests
    
    func testAddonCredits() {
        // Initially no addon credits
        XCTAssertEqual(entitlementStore.currentEntitlements.addonPremiumCredits, 0)
        
        // Add addon credits
        entitlementStore.addAddonCredits(10)
        XCTAssertEqual(entitlementStore.currentEntitlements.addonPremiumCredits, 10)
        
        // Add more credits
        entitlementStore.addAddonCredits(5)
        XCTAssertEqual(entitlementStore.currentEntitlements.addonPremiumCredits, 15)
        
        // Consume credits
        let success = entitlementStore.consumeAddonCredits(7)
        XCTAssertTrue(success)
        XCTAssertEqual(entitlementStore.currentEntitlements.addonPremiumCredits, 8)
        
        // Try to consume more than available
        let failure = entitlementStore.consumeAddonCredits(10)
        XCTAssertFalse(failure)
        XCTAssertEqual(entitlementStore.currentEntitlements.addonPremiumCredits, 8) // Should remain unchanged
    }
    
    func testTotalPremiumCredits() {
        // Set Pro subscription
        entitlementStore.updateSubscription(tier: .pro, expiryDate: Date().addingTimeInterval(86400 * 30))
        
        // Add addon credits
        entitlementStore.addAddonCredits(20)
        
        let entitlements = entitlementStore.currentEntitlements
        let totalCredits = entitlements.totalPremiumCreditsAvailable
        
        // Should be subscription credits + addon credits
        XCTAssertEqual(totalCredits, 300 + 20) // Pro tier + addon
    }
    
    // MARK: - Persistence Tests
    
    func testPersistence() {
        let expiryDate = Date().addingTimeInterval(86400 * 30)
        
        // Set subscription and addon credits
        entitlementStore.updateSubscription(tier: .pro, expiryDate: expiryDate)
        entitlementStore.addAddonCredits(15)
        
        // Create new store instance (simulates app restart)
        let newStore = EntitlementStore()
        
        // Should load persisted data
        let entitlements = newStore.currentEntitlements
        XCTAssertEqual(entitlements.userTier, .pro)
        XCTAssertEqual(entitlements.subscriptionExpiryDate, expiryDate)
        XCTAssertEqual(entitlements.addonPremiumCredits, 15)
    }
    
    func testReset() {
        // Set subscription and addon credits
        entitlementStore.updateSubscription(tier: .pro, expiryDate: Date().addingTimeInterval(86400 * 30))
        entitlementStore.addAddonCredits(25)
        
        // Verify they're set
        XCTAssertEqual(entitlementStore.currentEntitlements.userTier, .pro)
        XCTAssertEqual(entitlementStore.currentEntitlements.addonPremiumCredits, 25)
        
        // Reset
        entitlementStore.reset()
        
        // Should be back to defaults
        let entitlements = entitlementStore.currentEntitlements
        XCTAssertEqual(entitlements.userTier, .free)
        XCTAssertFalse(entitlements.hasActiveSubscription)
        XCTAssertEqual(entitlements.addonPremiumCredits, 0)
    }
    
    // MARK: - Feature Access Tests
    
    func testFeatureAccess() {
        // Test free tier access
        var entitlements = entitlementStore.currentEntitlements
        
        XCTAssertFalse(entitlements.canAccessFeature(.unlimitedEdits))
        XCTAssertFalse(entitlements.canAccessFeature(.priorityProcessing))
        XCTAssertFalse(entitlements.canAccessFeature(.advancedFilters))
        XCTAssertTrue(entitlements.canAccessFeature(.basicEditing)) // Should be available to all
        
        // Upgrade to Pro
        entitlementStore.updateSubscription(tier: .pro, expiryDate: Date().addingTimeInterval(86400 * 30))
        entitlements = entitlementStore.currentEntitlements
        
        XCTAssertTrue(entitlements.canAccessFeature(.unlimitedEdits))
        XCTAssertTrue(entitlements.canAccessFeature(.priorityProcessing))
        XCTAssertTrue(entitlements.canAccessFeature(.advancedFilters))
        XCTAssertTrue(entitlements.canAccessFeature(.basicEditing))
    }
    
    // MARK: - Credit Calculations Tests
    
    func testCreditCalculations() {
        // Free tier
        var entitlements = entitlementStore.currentEntitlements
        XCTAssertEqual(entitlements.budgetCreditsPerMonth, 50)
        XCTAssertEqual(entitlements.premiumCreditsPerMonth, 5)
        
        // Add addon credits
        entitlementStore.addAddonCredits(10)
        entitlements = entitlementStore.currentEntitlements
        XCTAssertEqual(entitlements.totalPremiumCreditsAvailable, 5 + 10) // Base + addon
        
        // Upgrade to Pro
        entitlementStore.updateSubscription(tier: .pro, expiryDate: Date().addingTimeInterval(86400 * 30))
        entitlements = entitlementStore.currentEntitlements
        XCTAssertEqual(entitlements.budgetCreditsPerMonth, 500)
        XCTAssertEqual(entitlements.premiumCreditsPerMonth, 300)
        XCTAssertEqual(entitlements.totalPremiumCreditsAvailable, 300 + 10) // Pro base + addon
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() {
        measure {
            for _ in 0..<100 {
                _ = entitlementStore.currentEntitlements
                entitlementStore.addAddonCredits(1)
                _ = entitlementStore.consumeAddonCredits(1)
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        
        // Perform concurrent operations
        for i in 0..<10 {
            DispatchQueue.global().async {
                self.entitlementStore.addAddonCredits(i)
                _ = self.entitlementStore.currentEntitlements
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should complete without crashing
        XCTAssertTrue(true)
    }
}

// MARK: - Mock Entitlement Store

class MockEntitlementStore: EntitlementStore {
    private var mockEntitlements = Entitlements(
        userTier: .free,
        hasActiveSubscription: false,
        subscriptionExpiryDate: nil,
        addonPremiumCredits: 0
    )
    
    override var currentEntitlements: Entitlements {
        return mockEntitlements
    }
    
    override func updateSubscription(tier: UserTier, expiryDate: Date?) {
        mockEntitlements = Entitlements(
            userTier: tier,
            hasActiveSubscription: expiryDate != nil && expiryDate! > Date(),
            subscriptionExpiryDate: expiryDate,
            addonPremiumCredits: mockEntitlements.addonPremiumCredits
        )
    }
    
    override func addAddonCredits(_ credits: Int) {
        mockEntitlements = Entitlements(
            userTier: mockEntitlements.userTier,
            hasActiveSubscription: mockEntitlements.hasActiveSubscription,
            subscriptionExpiryDate: mockEntitlements.subscriptionExpiryDate,
            addonPremiumCredits: mockEntitlements.addonPremiumCredits + credits
        )
    }
    
    override func consumeAddonCredits(_ credits: Int) -> Bool {
        if mockEntitlements.addonPremiumCredits >= credits {
            mockEntitlements = Entitlements(
                userTier: mockEntitlements.userTier,
                hasActiveSubscription: mockEntitlements.hasActiveSubscription,
                subscriptionExpiryDate: mockEntitlements.subscriptionExpiryDate,
                addonPremiumCredits: mockEntitlements.addonPremiumCredits - credits
            )
            return true
        }
        return false
    }
    
    override func reset() {
        mockEntitlements = Entitlements(
            userTier: .free,
            hasActiveSubscription: false,
            subscriptionExpiryDate: nil,
            addonPremiumCredits: 0
        )
    }
}

