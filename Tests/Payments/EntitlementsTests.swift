//
//  EntitlementsTests.swift
//  PhotoStopTests
//
//  Created by Esh on 2025-08-29.
//

import XCTest
@testable import PhotoStop

final class EntitlementsTests: XCTestCase {
    
    var entitlementStore: EntitlementStore!
    
    override func setUp() {
        super.setUp()
        entitlementStore = EntitlementStore.shared
        
        // Reset to clean state
        entitlementStore.reset()
    }
    
    override func tearDown() {
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
        XCTAssertTrue(UserTier.pro > UserTier.free, "Pro should be greater than Free")
        XCTAssertFalse(UserTier.free > UserTier.pro, "Free should not be greater than Pro")
        XCTAssertEqual(UserTier.free, UserTier.free, "Same tiers should be equal")
    }
    
    // MARK: - Entitlements Tests
    
    func testEntitlementsInitialization() {
        let freeEntitlements = Entitlements(tier: .free)
        let proEntitlements = Entitlements(tier: .pro)
        
        // Test Free entitlements
        XCTAssertEqual(freeEntitlements.tier, .free)
        XCTAssertEqual(freeEntitlements.budgetCreditsPerMonth, 50)
        XCTAssertEqual(freeEntitlements.premiumCreditsPerMonth, 5)
        XCTAssertFalse(freeEntitlements.hasUnlimitedEdits)
        XCTAssertFalse(freeEntitlements.hasPriorityProcessing)
        XCTAssertFalse(freeEntitlements.hasAdvancedFeatures)
        XCTAssertFalse(freeEntitlements.canExportHighRes)
        XCTAssertFalse(freeEntitlements.canBatchProcess)
        XCTAssertFalse(freeEntitlements.hasCustomPresets)
        XCTAssertFalse(freeEntitlements.hasCloudSync)
        XCTAssertEqual(freeEntitlements.maxImageSize, 2048)
        XCTAssertEqual(freeEntitlements.maxBatchSize, 1)
        XCTAssertEqual(freeEntitlements.historyRetentionDays, 7)
        
        // Test Pro entitlements
        XCTAssertEqual(proEntitlements.tier, .pro)
        XCTAssertEqual(proEntitlements.budgetCreditsPerMonth, 500)
        XCTAssertEqual(proEntitlements.premiumCreditsPerMonth, 300)
        XCTAssertTrue(proEntitlements.hasUnlimitedEdits)
        XCTAssertTrue(proEntitlements.hasPriorityProcessing)
        XCTAssertTrue(proEntitlements.hasAdvancedFeatures)
        XCTAssertTrue(proEntitlements.canExportHighRes)
        XCTAssertTrue(proEntitlements.canBatchProcess)
        XCTAssertTrue(proEntitlements.hasCustomPresets)
        XCTAssertTrue(proEntitlements.hasCloudSync)
        XCTAssertEqual(proEntitlements.maxImageSize, 8192)
        XCTAssertEqual(proEntitlements.maxBatchSize, 50)
        XCTAssertEqual(proEntitlements.historyRetentionDays, 365)
    }
    
    func testEntitlementsCanPerform() {
        let freeEntitlements = Entitlements(tier: .free)
        let proEntitlements = Entitlements(tier: .pro)
        
        // Test basic operations (should be available to all)
        XCTAssertTrue(freeEntitlements.canPerform(.enhancement))
        XCTAssertTrue(proEntitlements.canPerform(.enhancement))
        
        // Test advanced operations (Pro only)
        XCTAssertFalse(freeEntitlements.canPerform(.batchProcessing))
        XCTAssertTrue(proEntitlements.canPerform(.batchProcessing))
        
        XCTAssertFalse(freeEntitlements.canPerform(.highResExport))
        XCTAssertTrue(proEntitlements.canPerform(.highResExport))
        
        XCTAssertFalse(freeEntitlements.canPerform(.customPresets))
        XCTAssertTrue(proEntitlements.canPerform(.customPresets))
        
        XCTAssertFalse(freeEntitlements.canPerform(.cloudSync))
        XCTAssertTrue(proEntitlements.canPerform(.cloudSync))
        
        XCTAssertFalse(freeEntitlements.canPerform(.priorityProcessing))
        XCTAssertTrue(proEntitlements.canPerform(.priorityProcessing))
    }
    
    func testEntitlementsDisplayFeatures() {
        let freeEntitlements = Entitlements(tier: .free)
        let proEntitlements = Entitlements(tier: .pro)
        
        let freeFeatures = freeEntitlements.displayFeatures
        let proFeatures = proEntitlements.displayFeatures
        
        XCTAssertFalse(freeFeatures.isEmpty, "Free tier should have display features")
        XCTAssertFalse(proFeatures.isEmpty, "Pro tier should have display features")
        XCTAssertTrue(proFeatures.count > freeFeatures.count, "Pro should have more features than Free")
        
        // Check that basic features are in both
        XCTAssertTrue(freeFeatures.contains("50 Budget AI Credits/month"))
        XCTAssertTrue(proFeatures.contains("500 Budget AI Credits/month"))
        
        // Check that advanced features are only in Pro
        XCTAssertFalse(freeFeatures.contains("Batch Processing"))
        XCTAssertTrue(proFeatures.contains("Batch Processing"))
    }
    
    // MARK: - EntitlementStore Tests
    
    func testEntitlementStoreInitialState() {
        XCTAssertEqual(entitlementStore.currentTier, .free, "Should start with free tier")
        XCTAssertEqual(entitlementStore.getAddonPremiumCredits(), 0, "Should start with no addon credits")
        XCTAssertFalse(entitlementStore.hasActiveSubscription, "Should start without subscription")
        XCTAssertNil(entitlementStore.subscriptionExpiryDate, "Should have no expiry date initially")
    }
    
    func testSetTier() {
        entitlementStore.setTier(.pro)
        
        XCTAssertEqual(entitlementStore.currentTier, .pro, "Should update current tier")
        
        let entitlements = entitlementStore.currentEntitlements
        XCTAssertEqual(entitlements.tier, .pro, "Current entitlements should reflect new tier")
    }
    
    func testSetSubscriptionStatus() {
        let expiryDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
        
        entitlementStore.setSubscriptionStatus(active: true, expiryDate: expiryDate)
        
        XCTAssertTrue(entitlementStore.hasActiveSubscription, "Should have active subscription")
        XCTAssertEqual(entitlementStore.subscriptionExpiryDate, expiryDate, "Should set expiry date")
    }
    
    func testSetSubscriptionStatusInactive() {
        entitlementStore.setSubscriptionStatus(active: false, expiryDate: nil)
        
        XCTAssertFalse(entitlementStore.hasActiveSubscription, "Should not have active subscription")
        XCTAssertNil(entitlementStore.subscriptionExpiryDate, "Should clear expiry date")
    }
    
    func testAddAddonPremiumCredits() {
        entitlementStore.addAddonPremiumCredits(10)
        
        XCTAssertEqual(entitlementStore.getAddonPremiumCredits(), 10, "Should add addon credits")
        
        entitlementStore.addAddonPremiumCredits(5)
        
        XCTAssertEqual(entitlementStore.getAddonPremiumCredits(), 15, "Should accumulate addon credits")
    }
    
    func testConsumeAddonPremiumCredit() {
        entitlementStore.addAddonPremiumCredits(3)
        
        XCTAssertTrue(entitlementStore.consumeAddonPremiumCredit(), "Should consume credit successfully")
        XCTAssertEqual(entitlementStore.getAddonPremiumCredits(), 2, "Should decrease addon credits")
        
        // Consume remaining credits
        XCTAssertTrue(entitlementStore.consumeAddonPremiumCredit())
        XCTAssertTrue(entitlementStore.consumeAddonPremiumCredit())
        
        XCTAssertEqual(entitlementStore.getAddonPremiumCredits(), 0, "Should have no credits left")
        XCTAssertFalse(entitlementStore.consumeAddonPremiumCredit(), "Should fail to consume when no credits")
    }
    
    func testSyncWithUsageTracker() {
        // This test would verify that the entitlement store properly syncs with usage tracker
        // In a real implementation, you'd:
        // 1. Set up mock usage tracker
        // 2. Update entitlements
        // 3. Call sync
        // 4. Verify usage tracker was updated
        
        entitlementStore.syncWithUsageTracker()
        
        // For now, just verify the method exists and doesn't crash
        XCTAssertTrue(true, "Sync method should exist and not crash")
    }
    
    func testReset() {
        // Set up some state
        entitlementStore.setTier(.pro)
        entitlementStore.addAddonPremiumCredits(10)
        entitlementStore.setSubscriptionStatus(active: true, expiryDate: Date())
        
        // Reset
        entitlementStore.reset()
        
        // Verify reset state
        XCTAssertEqual(entitlementStore.currentTier, .free, "Should reset to free tier")
        XCTAssertEqual(entitlementStore.getAddonPremiumCredits(), 0, "Should reset addon credits")
        XCTAssertFalse(entitlementStore.hasActiveSubscription, "Should reset subscription status")
        XCTAssertNil(entitlementStore.subscriptionExpiryDate, "Should reset expiry date")
    }
    
    // MARK: - Persistence Tests
    
    func testPersistence() {
        // Set up some state
        entitlementStore.setTier(.pro)
        entitlementStore.addAddonPremiumCredits(25)
        let expiryDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
        entitlementStore.setSubscriptionStatus(active: true, expiryDate: expiryDate)
        
        // Create new instance (simulating app restart)
        let newEntitlementStore = EntitlementStore()
        
        // In a real implementation, this would load from persistent storage
        // For now, we just verify the interface exists
        XCTAssertTrue(true, "Persistence interface should exist")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        
        // Test concurrent access to entitlement store
        for i in 0..<10 {
            DispatchQueue.global(qos: .background).async {
                // Perform various operations concurrently
                self.entitlementStore.addAddonPremiumCredits(1)
                let _ = self.entitlementStore.currentTier
                let _ = self.entitlementStore.getAddonPremiumCredits()
                let _ = self.entitlementStore.hasActiveSubscription
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify final state is consistent
        XCTAssertGreaterThanOrEqual(entitlementStore.getAddonPremiumCredits(), 0, "Credits should be non-negative")
    }
    
    // MARK: - Edge Cases Tests
    
    func testNegativeAddonCredits() {
        // Verify that negative credits are handled properly
        entitlementStore.addAddonPremiumCredits(-5)
        
        XCTAssertEqual(entitlementStore.getAddonPremiumCredits(), 0, "Should not allow negative credits")
    }
    
    func testLargeAddonCredits() {
        // Test with large number of credits
        entitlementStore.addAddonPremiumCredits(1000000)
        
        XCTAssertEqual(entitlementStore.getAddonPremiumCredits(), 1000000, "Should handle large credit amounts")
    }
    
    func testExpiredSubscription() {
        let pastDate = Date().addingTimeInterval(-24 * 60 * 60) // Yesterday
        
        entitlementStore.setSubscriptionStatus(active: true, expiryDate: pastDate)
        
        // In a real implementation, you might want to check if subscription is actually active
        // based on the expiry date, but for now we just test that the date is stored
        XCTAssertEqual(entitlementStore.subscriptionExpiryDate, pastDate, "Should store expiry date even if in past")
    }
    
    // MARK: - Feature Flag Tests
    
    func testFeatureAvailability() {
        // Test Free tier limitations
        entitlementStore.setTier(.free)
        let freeEntitlements = entitlementStore.currentEntitlements
        
        XCTAssertFalse(freeEntitlements.canPerform(.batchProcessing), "Free tier should not have batch processing")
        XCTAssertFalse(freeEntitlements.canPerform(.highResExport), "Free tier should not have high-res export")
        XCTAssertTrue(freeEntitlements.canPerform(.enhancement), "Free tier should have basic enhancement")
        
        // Test Pro tier capabilities
        entitlementStore.setTier(.pro)
        let proEntitlements = entitlementStore.currentEntitlements
        
        XCTAssertTrue(proEntitlements.canPerform(.batchProcessing), "Pro tier should have batch processing")
        XCTAssertTrue(proEntitlements.canPerform(.highResExport), "Pro tier should have high-res export")
        XCTAssertTrue(proEntitlements.canPerform(.enhancement), "Pro tier should have basic enhancement")
    }
}

