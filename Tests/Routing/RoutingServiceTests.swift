//
//  RoutingServiceTests.swift
//  PhotoStopTests
//
//  Created by Esh on 2025-08-29.
//

import XCTest
@testable import PhotoStop

final class RoutingServiceTests: XCTestCase {
    
    var routingService: RoutingService!
    var mockUsageTracker: MockUsageTracker!
    var mockEntitlementStore: MockEntitlementStore!
    var mockResultCache: MockResultCache!
    
    override func setUp() {
        super.setUp()
        
        // Create mock dependencies
        mockUsageTracker = MockUsageTracker()
        mockEntitlementStore = MockEntitlementStore()
        mockResultCache = MockResultCache()
        
        // Initialize routing service with mocks
        routingService = RoutingService.shared
        
        // Reset to clean state
        mockUsageTracker.reset()
        mockEntitlementStore.reset()
        mockResultCache.reset()
    }
    
    override func tearDown() {
        routingService = nil
        mockUsageTracker = nil
        mockEntitlementStore = nil
        mockResultCache = nil
        super.tearDown()
    }
    
    // MARK: - Edit Classification Tests
    
    func testEditClassification_Enhancement() {
        // Test enhancement keywords
        let enhancePrompts = [
            "enhance this photo",
            "improve the quality",
            "make it brighter",
            "increase contrast",
            "sharpen the image"
        ]
        
        for prompt in enhancePrompts {
            let request = createMockEditRequest(prompt: prompt)
            let result = routingService.classifyEdit(prompt)
            XCTAssertEqual(result, .enhancement, "Failed to classify '\(prompt)' as enhancement")
        }
    }
    
    func testEditClassification_BackgroundRemoval() {
        let bgRemovalPrompts = [
            "remove the background",
            "cutout the subject",
            "isolate the person",
            "background removal"
        ]
        
        for prompt in bgRemovalPrompts {
            let result = routingService.classifyEdit(prompt)
            XCTAssertEqual(result, .backgroundRemoval, "Failed to classify '\(prompt)' as background removal")
        }
    }
    
    func testEditClassification_Creative() {
        let creativePrompts = [
            "make it look like a fantasy scene",
            "transform into surreal art",
            "creative interpretation",
            "artistic transformation"
        ]
        
        for prompt in creativePrompts {
            let result = routingService.classifyEdit(prompt)
            XCTAssertTrue([.creative, .artistic].contains(result), "Failed to classify '\(prompt)' as creative/artistic")
        }
    }
    
    func testEditClassification_Advanced() {
        let advancedPrompts = [
            "complex professional editing",
            "advanced retouching",
            "detailed enhancement"
        ]
        
        for prompt in advancedPrompts {
            let result = routingService.classifyEdit(prompt)
            XCTAssertEqual(result, .advanced, "Failed to classify '\(prompt)' as advanced")
        }
    }
    
    // MARK: - Routing Decision Tests
    
    func testRoutingDecision_FreeUser_EnhancementEdit() async {
        // Setup: Free user with available budget credits
        mockUsageTracker.currentTier = .free
        mockUsageTracker.setBudgetRemaining(for: .free, remaining: 10)
        
        let decision = await routingService.getRoutingPreview(for: "enhance this photo", tier: .free)
        
        switch decision {
        case .route(let providers):
            XCTAssertFalse(providers.isEmpty, "Should have available providers for free user enhancement")
        case .requiresUpgrade:
            XCTFail("Free user with credits should not require upgrade for basic enhancement")
        case .noProvidersAvailable:
            XCTFail("Should have providers available for enhancement")
        }
    }
    
    func testRoutingDecision_FreeUser_InsufficientBudgetCredits() async {
        // Setup: Free user with no budget credits
        mockUsageTracker.currentTier = .free
        mockUsageTracker.setBudgetRemaining(for: .free, remaining: 0)
        
        let decision = await routingService.getRoutingPreview(for: "enhance this photo", tier: .free)
        
        switch decision {
        case .requiresUpgrade(let reason):
            if case .insufficientBudgetCredits(let required, let remaining) = reason {
                XCTAssertEqual(required, 1)
                XCTAssertEqual(remaining, 0)
            } else {
                XCTFail("Should require upgrade due to insufficient budget credits")
            }
        default:
            XCTFail("Should require upgrade when no budget credits available")
        }
    }
    
    func testRoutingDecision_FreeUser_PremiumFeature() async {
        // Setup: Free user trying to access premium feature
        mockUsageTracker.currentTier = .free
        mockUsageTracker.setPremiumRemaining(for: .free, remaining: 0)
        
        let decision = await routingService.getRoutingPreview(for: "advanced professional editing", tier: .free)
        
        switch decision {
        case .requiresUpgrade(let reason):
            if case .insufficientPremiumCredits = reason {
                // Expected behavior
            } else {
                XCTFail("Should require upgrade due to insufficient premium credits")
            }
        default:
            XCTFail("Should require upgrade for premium features")
        }
    }
    
    func testRoutingDecision_ProUser_HasCredits() async {
        // Setup: Pro user with available credits
        mockUsageTracker.currentTier = .pro
        mockUsageTracker.setBudgetRemaining(for: .pro, remaining: 100)
        mockUsageTracker.setPremiumRemaining(for: .pro, remaining: 50)
        
        let decision = await routingService.getRoutingPreview(for: "advanced professional editing", tier: .pro)
        
        switch decision {
        case .route(let providers):
            XCTAssertFalse(providers.isEmpty, "Pro user should have providers available")
        default:
            XCTFail("Pro user with credits should have providers available")
        }
    }
    
    func testRoutingDecision_AddonCredits() async {
        // Setup: Free user with no subscription credits but addon credits
        mockUsageTracker.currentTier = .free
        mockUsageTracker.setPremiumRemaining(for: .free, remaining: 0)
        mockEntitlementStore.setAddonPremiumCredits(10)
        
        let decision = await routingService.getRoutingPreview(for: "advanced editing", tier: .free)
        
        switch decision {
        case .route(let providers):
            XCTAssertFalse(providers.isEmpty, "Should have providers when addon credits available")
        default:
            XCTFail("Should route successfully with addon credits")
        }
    }
    
    // MARK: - Edit Execution Tests
    
    func testEditExecution_Success() async {
        // Setup: Pro user with credits
        mockUsageTracker.currentTier = .pro
        mockUsageTracker.setBudgetRemaining(for: .pro, remaining: 10)
        
        let request = createMockEditRequest(prompt: "enhance this photo")
        let result = await routingService.routeEdit(request)
        
        switch result {
        case .success(let image, let provider, let processingTime, let metadata):
            XCTAssertNotNil(image)
            XCTAssertFalse(provider.isEmpty)
            XCTAssertGreaterThan(processingTime, 0)
        case .failure(let error):
            XCTFail("Edit should succeed with available credits: \(error)")
        case .requiresUpgrade:
            XCTFail("Should not require upgrade with available credits")
        }
    }
    
    func testEditExecution_CacheHit() async {
        // Setup: Cache a result
        let request = createMockEditRequest(prompt: "enhance this photo")
        let cachedResult = EditResult.success(
            image: UIImage(systemName: "photo")!,
            provider: "TestProvider",
            processingTime: 1.0,
            metadata: [:]
        )
        mockResultCache.store(request: request, result: cachedResult)
        
        let result = await routingService.routeEdit(request)
        
        switch result {
        case .success(_, let provider, _, _):
            XCTAssertEqual(provider, "TestProvider", "Should return cached result")
        default:
            XCTFail("Should return cached result")
        }
    }
    
    func testEditExecution_CreditConsumption() async {
        // Setup: User with limited credits
        mockUsageTracker.currentTier = .free
        mockUsageTracker.setBudgetRemaining(for: .free, remaining: 1)
        
        let request = createMockEditRequest(prompt: "enhance this photo")
        let result = await routingService.routeEdit(request)
        
        // Verify credit was consumed
        let remainingAfter = mockUsageTracker.getBudgetRemaining(for: .free)
        XCTAssertEqual(remainingAfter, 0, "Credit should be consumed after successful edit")
    }
    
    func testEditExecution_CreditRefundOnFailure() async {
        // Setup: Mock provider that will fail
        mockUsageTracker.currentTier = .free
        mockUsageTracker.setBudgetRemaining(for: .free, remaining: 1)
        
        // Create request that will cause provider failure
        let request = createMockEditRequest(prompt: "invalid request that will fail")
        
        // Force provider failure by using invalid image data
        let invalidRequest = EditRequest(
            image: Data(),
            prompt: "enhance this photo"
        )
        
        let result = await routingService.routeEdit(invalidRequest)
        
        // Verify credit was refunded on failure
        let remainingAfter = mockUsageTracker.getBudgetRemaining(for: .free)
        XCTAssertEqual(remainingAfter, 1, "Credit should be refunded on failure")
    }
    
    // MARK: - Usage Statistics Tests
    
    func testUsageStatistics_FreeUser() {
        mockUsageTracker.currentTier = .free
        mockUsageTracker.setBudgetRemaining(for: .free, remaining: 30)
        mockUsageTracker.setPremiumRemaining(for: .free, remaining: 2)
        mockEntitlementStore.setAddonPremiumCredits(5)
        
        let stats = routingService.getUsageStatistics(for: .free)
        
        XCTAssertEqual(stats.tier, .free)
        XCTAssertEqual(stats.budgetUsed, 20) // 50 - 30
        XCTAssertEqual(stats.budgetRemaining, 30)
        XCTAssertEqual(stats.budgetCapacity, 50)
        XCTAssertEqual(stats.premiumUsed, 3) // 5 - 2
        XCTAssertEqual(stats.premiumRemaining, 2)
        XCTAssertEqual(stats.premiumCapacity, 5)
        XCTAssertEqual(stats.addonPremiumCredits, 5)
        XCTAssertEqual(stats.totalPremiumCredits, 7) // 2 + 5
    }
    
    func testUsageStatistics_ProUser() {
        mockUsageTracker.currentTier = .pro
        mockUsageTracker.setBudgetRemaining(for: .pro, remaining: 400)
        mockUsageTracker.setPremiumRemaining(for: .pro, remaining: 250)
        mockEntitlementStore.setAddonPremiumCredits(0)
        
        let stats = routingService.getUsageStatistics(for: .pro)
        
        XCTAssertEqual(stats.tier, .pro)
        XCTAssertEqual(stats.budgetUsed, 100) // 500 - 400
        XCTAssertEqual(stats.budgetRemaining, 400)
        XCTAssertEqual(stats.budgetCapacity, 500)
        XCTAssertEqual(stats.premiumUsed, 50) // 300 - 250
        XCTAssertEqual(stats.premiumRemaining, 250)
        XCTAssertEqual(stats.premiumCapacity, 300)
        XCTAssertEqual(stats.addonPremiumCredits, 0)
        XCTAssertEqual(stats.totalPremiumCredits, 250)
    }
    
    // MARK: - Can Perform Edit Tests
    
    func testCanPerformEdit_FreeUser_Enhancement() {
        mockUsageTracker.currentTier = .free
        mockUsageTracker.setBudgetRemaining(for: .free, remaining: 10)
        
        let canPerform = routingService.canPerformEdit(.enhancement, tier: .free)
        XCTAssertTrue(canPerform, "Free user should be able to perform enhancement with budget credits")
    }
    
    func testCanPerformEdit_FreeUser_Advanced_NoCredits() {
        mockUsageTracker.currentTier = .free
        mockUsageTracker.setPremiumRemaining(for: .free, remaining: 0)
        mockEntitlementStore.setAddonPremiumCredits(0)
        
        let canPerform = routingService.canPerformEdit(.advanced, tier: .free)
        XCTAssertFalse(canPerform, "Free user should not be able to perform advanced edits without premium credits")
    }
    
    func testCanPerformEdit_ProUser_AllTypes() {
        mockUsageTracker.currentTier = .pro
        mockUsageTracker.setBudgetRemaining(for: .pro, remaining: 100)
        mockUsageTracker.setPremiumRemaining(for: .pro, remaining: 50)
        
        for editType in EditType.allCases {
            let canPerform = routingService.canPerformEdit(editType, tier: .pro)
            XCTAssertTrue(canPerform, "Pro user should be able to perform \(editType) with available credits")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockEditRequest(prompt: String) -> EditRequest {
        let image = UIImage(systemName: "photo")!
        let imageData = image.jpegData(compressionQuality: 0.8)!
        
        return EditRequest(
            image: imageData,
            prompt: prompt,
            strength: 0.8
        )
    }
}

// MARK: - Mock Classes

class MockUsageTracker {
    var currentTier: UserTier = .free
    private var budgetRemaining: [UserTier: Int] = [.free: 50, .pro: 500]
    private var premiumRemaining: [UserTier: Int] = [.free: 5, .pro: 300]
    
    func reset() {
        currentTier = .free
        budgetRemaining = [.free: 50, .pro: 500]
        premiumRemaining = [.free: 5, .pro: 300]
    }
    
    func setBudgetRemaining(for tier: UserTier, remaining: Int) {
        budgetRemaining[tier] = remaining
    }
    
    func setPremiumRemaining(for tier: UserTier, remaining: Int) {
        premiumRemaining[tier] = remaining
    }
    
    func getBudgetRemaining(for tier: UserTier) -> Int {
        return budgetRemaining[tier] ?? 0
    }
    
    func getPremiumRemaining(for tier: UserTier) -> Int {
        return premiumRemaining[tier] ?? 0
    }
    
    func remaining(for tier: UserTier, cost: CostClass) -> Int {
        switch cost {
        case .free: return Int.max
        case .budget: return getBudgetRemaining(for: tier)
        case .premium: return getPremiumRemaining(for: tier)
        }
    }
    
    func capacity(for tier: UserTier, cost: CostClass) -> Int {
        switch cost {
        case .free: return Int.max
        case .budget: return tier == .free ? 50 : 500
        case .premium: return tier == .free ? 5 : 300
        }
    }
    
    func consumeCredit(for tier: UserTier, cost: CostClass) -> Bool {
        let remaining = self.remaining(for: tier, cost: cost)
        guard remaining > 0 else { return false }
        
        switch cost {
        case .free: return true
        case .budget: 
            budgetRemaining[tier] = remaining - 1
            return true
        case .premium:
            premiumRemaining[tier] = remaining - 1
            return true
        }
    }
    
    func refundCredit(for tier: UserTier, cost: CostClass) {
        switch cost {
        case .free: break
        case .budget:
            budgetRemaining[tier] = (budgetRemaining[tier] ?? 0) + 1
        case .premium:
            premiumRemaining[tier] = (premiumRemaining[tier] ?? 0) + 1
        }
    }
    
    func recordUsage(provider: String, cost: CostClass, success: Bool) {
        // Mock implementation
    }
}

class MockEntitlementStore {
    private var addonPremiumCredits: Int = 0
    
    func reset() {
        addonPremiumCredits = 0
    }
    
    func setAddonPremiumCredits(_ credits: Int) {
        addonPremiumCredits = credits
    }
    
    func getAddonPremiumCredits() -> Int {
        return addonPremiumCredits
    }
    
    func consumeAddonPremiumCredit() -> Bool {
        guard addonPremiumCredits > 0 else { return false }
        addonPremiumCredits -= 1
        return true
    }
}

class MockResultCache {
    private var cache: [String: EditResult] = [:]
    
    func reset() {
        cache.removeAll()
    }
    
    func get(request: EditRequest) -> EditResult? {
        return cache[request.cacheKey]
    }
    
    func store(request: EditRequest, result: EditResult) {
        cache[request.cacheKey] = result
    }
}

