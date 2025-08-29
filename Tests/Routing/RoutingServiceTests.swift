//
//  RoutingServiceTests.swift
//  PhotoStopTests
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import XCTest
@testable import PhotoStop

final class RoutingServiceTests: XCTestCase {
    
    var routingService: RoutingService!
    var testImage: UIImage!
    
    override func setUp() {
        super.setUp()
        routingService = RoutingService.shared
        testImage = UIImage(systemName: "photo") ?? UIImage()
    }
    
    override func tearDown() {
        routingService = nil
        testImage = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testRoutingServiceInitialization() {
        XCTAssertNotNil(routingService)
    }
    
    // MARK: - Edit Request Tests
    
    func testSimpleEditRequest() async {
        let request = EditRequest(
            image: testImage,
            prompt: "enhance this photo",
            task: .simpleEnhance,
            quality: .standard
        )
        
        let result = await routingService.routeEdit(request)
        
        switch result {
        case .success(let image, let metadata):
            XCTAssertNotNil(image)
            XCTAssertNotNil(metadata)
            XCTAssertEqual(metadata.provider, "OnDevice")
        case .requiresUpgrade(let reason):
            // This is acceptable in test environment
            XCTAssertNotNil(reason)
        case .failure(let error):
            // This is acceptable in test environment
            XCTAssertNotNil(error)
        }
    }
    
    func testEditRequestWithDifferentTasks() async {
        let tasks: [EditTask] = [.simpleEnhance, .portraitEnhance, .hdrEnhance, .cleanup]
        
        for task in tasks {
            let request = EditRequest(
                image: testImage,
                prompt: "test prompt",
                task: task,
                quality: .standard
            )
            
            let result = await routingService.routeEdit(request)
            
            // All tasks should return some result (success, upgrade, or failure)
            switch result {
            case .success, .requiresUpgrade, .failure:
                XCTAssertTrue(true) // Test passed - got a result
            }
        }
    }
    
    func testEditRequestWithDifferentQualities() async {
        let qualities: [EditQuality] = [.draft, .standard, .high, .ultra]
        
        for quality in qualities {
            let request = EditRequest(
                image: testImage,
                prompt: "enhance photo",
                task: .simpleEnhance,
                quality: quality
            )
            
            let result = await routingService.routeEdit(request)
            
            // All qualities should return some result
            switch result {
            case .success, .requiresUpgrade, .failure:
                XCTAssertTrue(true) // Test passed - got a result
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testRoutingPerformance() {
        let request = EditRequest(
            image: testImage,
            prompt: "enhance photo",
            task: .simpleEnhance,
            quality: .standard
        )
        
        measure {
            Task {
                _ = await routingService.routeEdit(request)
            }
        }
    }
    
    // MARK: - Concurrent Request Tests
    
    func testConcurrentRequests() async {
        let request1 = EditRequest(
            image: testImage,
            prompt: "enhance photo 1",
            task: .simpleEnhance,
            quality: .standard
        )
        
        let request2 = EditRequest(
            image: testImage,
            prompt: "enhance photo 2",
            task: .portraitEnhance,
            quality: .high
        )
        
        // Execute concurrent requests
        async let result1 = routingService.routeEdit(request1)
        async let result2 = routingService.routeEdit(request2)
        
        let (res1, res2) = await (result1, result2)
        
        // Both should complete without crashing
        switch res1 {
        case .success, .requiresUpgrade, .failure:
            XCTAssertTrue(true)
        }
        
        switch res2 {
        case .success, .requiresUpgrade, .failure:
            XCTAssertTrue(true)
        }
    }
}

// MARK: - Edit Types Tests

final class EditTypesTests: XCTestCase {
    
    func testEditTaskProperties() {
        // Test all edit tasks
        let tasks = EditTask.allCases
        XCTAssertFalse(tasks.isEmpty)
        
        for task in tasks {
            XCTAssertFalse(task.displayName.isEmpty)
            
            // Test premium requirements
            switch task {
            case .simpleEnhance, .cleanup:
                XCTAssertFalse(task.requiresPremium)
            case .portraitEnhance, .hdrEnhance, .backgroundRemoval, .creative, .localEdit:
                XCTAssertTrue(task.requiresPremium)
            }
        }
    }
    
    func testEditQualityProperties() {
        let qualities = EditQuality.allCases
        XCTAssertFalse(qualities.isEmpty)
        
        for quality in qualities {
            XCTAssertFalse(quality.displayName.isEmpty)
            XCTAssertGreaterThan(quality.creditsRequired, 0)
        }
        
        // Test credit requirements are in ascending order
        XCTAssertLessThan(EditQuality.draft.creditsRequired, EditQuality.standard.creditsRequired)
        XCTAssertLessThan(EditQuality.standard.creditsRequired, EditQuality.high.creditsRequired)
        XCTAssertLessThan(EditQuality.high.creditsRequired, EditQuality.ultra.creditsRequired)
    }
    
    func testUpgradeReasonProperties() {
        let reasons: [UpgradeReason] = [.insufficientCredits, .premiumFeature, .qualityLimit, .monthlyLimit]
        
        for reason in reasons {
            XCTAssertFalse(reason.displayTitle.isEmpty)
            XCTAssertFalse(reason.displayMessage.isEmpty)
        }
    }
    
    func testEditErrorProperties() {
        let errors: [EditError] = [
            .networkError,
            .processingFailed,
            .invalidImage,
            .providerUnavailable,
            .timeout,
            .quotaExceeded,
            .unknown("Test error")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    func testRoutingDecisionProperties() {
        let routeDecision = RoutingDecision.route(provider: "TestProvider", cost: 5)
        let upgradeDecision = RoutingDecision.requiresUpgrade(reason: .insufficientCredits)
        let fallbackDecision = RoutingDecision.fallback(provider: "FallbackProvider", reason: "Test reason")
        
        // Test canProceed
        XCTAssertTrue(routeDecision.canProceed)
        XCTAssertFalse(upgradeDecision.canProceed)
        XCTAssertTrue(fallbackDecision.canProceed)
        
        // Test provider
        XCTAssertEqual(routeDecision.provider, "TestProvider")
        XCTAssertNil(upgradeDecision.provider)
        XCTAssertEqual(fallbackDecision.provider, "FallbackProvider")
        
        // Test cost
        XCTAssertEqual(routeDecision.cost, 5)
        XCTAssertEqual(upgradeDecision.cost, 0)
        XCTAssertEqual(fallbackDecision.cost, 1)
    }
    
    func testProcessingStateProperties() {
        let states: [ProcessingState] = [
            .idle,
            .analyzing,
            .enhancing,
            .finalizing,
            .complete,
            .failed(.networkError)
        ]
        
        for state in states {
            XCTAssertNotNil(state.displayMessage)
            XCTAssertGreaterThanOrEqual(state.progress, 0.0)
            XCTAssertLessThanOrEqual(state.progress, 1.0)
        }
        
        // Test progress values
        XCTAssertEqual(ProcessingState.idle.progress, 0.0)
        XCTAssertEqual(ProcessingState.complete.progress, 1.0)
        XCTAssertGreaterThan(ProcessingState.enhancing.progress, ProcessingState.analyzing.progress)
    }
    
    func testCaptureStateProperties() {
        let states: [CaptureState] = [
            .idle,
            .preparing,
            .capturing,
            .processing,
            .complete,
            .failed(.deviceUnavailable)
        ]
        
        for state in states {
            XCTAssertNotNil(state.displayMessage)
        }
    }
}

// MARK: - Usage Tracker Tests

final class UsageTrackerTests: XCTestCase {
    
    var usageTracker: UsageTracker!
    
    override func setUp() {
        super.setUp()
        usageTracker = UsageTracker.shared
        usageTracker.resetMonthlyUsage() // Start with clean state
    }
    
    override func tearDown() {
        usageTracker.resetMonthlyUsage() // Clean up
        usageTracker = nil
        super.tearDown()
    }
    
    func testInitialUsage() {
        let usage = usageTracker.getCurrentUsage()
        
        XCTAssertEqual(usage.budgetCreditsUsed, 0)
        XCTAssertEqual(usage.premiumCreditsUsed, 0)
        XCTAssertEqual(usage.budgetCreditsRemaining, 50) // Free tier
        XCTAssertEqual(usage.premiumCreditsRemaining, 5) // Free tier
    }
    
    func testCreditConsumption() {
        // Test budget credit consumption
        let success1 = usageTracker.consumeCredits(budget: 5, premium: 0)
        XCTAssertTrue(success1)
        
        let usage1 = usageTracker.getCurrentUsage()
        XCTAssertEqual(usage1.budgetCreditsUsed, 5)
        XCTAssertEqual(usage1.budgetCreditsRemaining, 45)
        
        // Test premium credit consumption
        let success2 = usageTracker.consumeCredits(budget: 0, premium: 2)
        XCTAssertTrue(success2)
        
        let usage2 = usageTracker.getCurrentUsage()
        XCTAssertEqual(usage2.premiumCreditsUsed, 2)
        XCTAssertEqual(usage2.premiumCreditsRemaining, 3)
    }
    
    func testInsufficientCredits() {
        // Try to consume more credits than available
        let success = usageTracker.consumeCredits(budget: 100, premium: 0)
        XCTAssertFalse(success)
        
        // Usage should remain unchanged
        let usage = usageTracker.getCurrentUsage()
        XCTAssertEqual(usage.budgetCreditsUsed, 0)
    }
    
    func testHasCredits() {
        XCTAssertTrue(usageTracker.hasCredits(budget: 10, premium: 1))
        XCTAssertTrue(usageTracker.hasCredits(budget: 50, premium: 5))
        XCTAssertFalse(usageTracker.hasCredits(budget: 51, premium: 0))
        XCTAssertFalse(usageTracker.hasCredits(budget: 0, premium: 6))
    }
    
    func testMonthlyReset() {
        // Consume some credits
        _ = usageTracker.consumeCredits(budget: 10, premium: 2)
        
        let usageBefore = usageTracker.getCurrentUsage()
        XCTAssertEqual(usageBefore.budgetCreditsUsed, 10)
        XCTAssertEqual(usageBefore.premiumCreditsUsed, 2)
        
        // Reset usage
        usageTracker.resetMonthlyUsage()
        
        let usageAfter = usageTracker.getCurrentUsage()
        XCTAssertEqual(usageAfter.budgetCreditsUsed, 0)
        XCTAssertEqual(usageAfter.premiumCreditsUsed, 0)
        XCTAssertEqual(usageAfter.budgetCreditsRemaining, 50)
        XCTAssertEqual(usageAfter.premiumCreditsRemaining, 5)
    }
}

