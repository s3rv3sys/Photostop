//
//  AIServiceTests.swift
//  PhotoStopTests
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import XCTest
@testable import PhotoStop

@MainActor
final class AIServiceTests: XCTestCase {
    
    var aiService: AIService!
    var testImage: UIImage!
    
    override func setUp() {
        super.setUp()
        aiService = AIService()
        testImage = UIImage(systemName: "photo")!
    }
    
    override func tearDown() {
        // Clean up keychain
        let keychain = KeychainService.shared
        _ = keychain.delete("gemini_api_key")
        
        aiService = nil
        testImage = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testAIServiceInitialization() {
        XCTAssertNotNil(aiService)
        XCTAssertFalse(aiService.isProcessing)
        XCTAssertNil(aiService.processingError)
        XCTAssertEqual(aiService.remainingFreeUses, 20)
    }
    
    // MARK: - API Key Management Tests
    
    func testAPIKeyStorage() {
        let testAPIKey = "test-api-key-12345"
        
        // Initially no API key
        XCTAssertFalse(aiService.isAPIKeyConfigured())
        XCTAssertNil(aiService.getAPIKey())
        
        // Set API key
        let success = aiService.setAPIKey(testAPIKey)
        XCTAssertTrue(success)
        
        // Verify API key is stored and configured
        XCTAssertTrue(aiService.isAPIKeyConfigured())
        XCTAssertEqual(aiService.getAPIKey(), testAPIKey)
    }
    
    func testAPIKeyRemoval() {
        let testAPIKey = "test-api-key-12345"
        
        // Set API key
        _ = aiService.setAPIKey(testAPIKey)
        XCTAssertTrue(aiService.isAPIKeyConfigured())
        
        // Remove API key
        aiService.removeAPIKey()
        XCTAssertFalse(aiService.isAPIKeyConfigured())
        XCTAssertNil(aiService.getAPIKey())
    }
    
    // MARK: - Usage Tracking Tests
    
    func testUsageTracking() {
        let initialUsage = aiService.usageCount
        let initialRemaining = aiService.remainingFreeUses
        
        // Increment usage
        aiService.incrementUsage()
        
        XCTAssertEqual(aiService.usageCount, initialUsage + 1)
        XCTAssertEqual(aiService.remainingFreeUses, initialRemaining - 1)
    }
    
    func testUsageLimitReached() {
        // Set usage to limit
        for _ in 0..<20 {
            aiService.incrementUsage()
        }
        
        XCTAssertEqual(aiService.remainingFreeUses, 0)
        XCTAssertTrue(aiService.hasReachedFreeLimit())
    }
    
    func testUsageReset() {
        // Use some free uses
        for _ in 0..<5 {
            aiService.incrementUsage()
        }
        
        XCTAssertEqual(aiService.usageCount, 5)
        XCTAssertEqual(aiService.remainingFreeUses, 15)
        
        // Reset usage
        aiService.resetUsage()
        
        XCTAssertEqual(aiService.usageCount, 0)
        XCTAssertEqual(aiService.remainingFreeUses, 20)
    }
    
    // MARK: - Image Processing Tests
    
    func testImageResizing() {
        // Create a large test image
        let largeImage = createTestImage(size: CGSize(width: 2000, height: 2000))
        
        let resizedImage = aiService.resizeImageForProcessing(largeImage)
        
        // Should be resized to max dimension of 1024
        let maxDimension = max(resizedImage.size.width, resizedImage.size.height)
        XCTAssertLessThanOrEqual(maxDimension, 1024)
    }
    
    func testImageToBase64() {
        let base64String = aiService.imageToBase64(testImage)
        
        XCTAssertNotNil(base64String)
        XCTAssertFalse(base64String!.isEmpty)
        
        // Should be valid base64
        let data = Data(base64Encoded: base64String!)
        XCTAssertNotNil(data)
    }
    
    // MARK: - Enhancement Tests (Mock)
    
    func testEnhanceImageWithoutAPIKey() async {
        // Ensure no API key is set
        aiService.removeAPIKey()
        
        do {
            _ = try await aiService.enhanceImage(testImage, prompt: "Make it better")
            XCTFail("Should have thrown an error without API key")
        } catch {
            XCTAssertTrue(error is AIError)
            if let aiError = error as? AIError {
                XCTAssertEqual(aiError, .apiKeyNotSet)
            }
        }
    }
    
    func testEnhanceImageWithFreeUsesExhausted() async {
        // Set API key
        _ = aiService.setAPIKey("test-key")
        
        // Exhaust free uses
        for _ in 0..<20 {
            aiService.incrementUsage()
        }
        
        do {
            _ = try await aiService.enhanceImage(testImage, prompt: "Make it better")
            XCTFail("Should have thrown an error when free uses exhausted")
        } catch {
            XCTAssertTrue(error is AIError)
            if let aiError = error as? AIError {
                XCTAssertEqual(aiError, .freeUsesExhausted)
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testAIErrorTypes() {
        let apiKeyError = AIError.apiKeyNotSet
        let networkError = AIError.networkError
        let processingError = AIError.processingError("Test error")
        let freeUsesError = AIError.freeUsesExhausted
        
        XCTAssertEqual(apiKeyError.errorDescription, "Gemini API key not configured")
        XCTAssertEqual(networkError.errorDescription, "Network connection failed")
        XCTAssertEqual(processingError.errorDescription, "Processing error: Test error")
        XCTAssertEqual(freeUsesError.errorDescription, "Free usage limit reached")
    }
    
    // MARK: - Performance Tests
    
    func testImageResizingPerformance() {
        let largeImage = createTestImage(size: CGSize(width: 4000, height: 4000))
        
        measure {
            _ = aiService.resizeImageForProcessing(largeImage)
        }
    }
    
    func testBase64ConversionPerformance() {
        measure {
            _ = aiService.imageToBase64(testImage)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Mock AIService for Testing

class MockAIService: AIService {
    var mockEnhancedImage: UIImage?
    var mockError: AIError?
    var shouldSucceed = true
    
    override func enhanceImage(_ image: UIImage, prompt: String) async throws -> UIImage {
        // Simulate processing time
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        if let error = mockError {
            throw error
        }
        
        if !shouldSucceed {
            throw AIError.processingError("Mock processing failed")
        }
        
        return mockEnhancedImage ?? image
    }
    
    override func isAPIKeyConfigured() -> Bool {
        return shouldSucceed // Mock API key configuration
    }
}

// MARK: - Integration Tests

final class AIServiceIntegrationTests: XCTestCase {
    
    var mockAIService: MockAIService!
    var testImage: UIImage!
    
    override func setUp() {
        super.setUp()
        mockAIService = MockAIService()
        testImage = UIImage(systemName: "photo")!
    }
    
    override func tearDown() {
        mockAIService = nil
        testImage = nil
        super.tearDown()
    }
    
    func testSuccessfulEnhancement() async {
        let enhancedImage = UIImage(systemName: "photo.fill")!
        mockAIService.mockEnhancedImage = enhancedImage
        mockAIService.shouldSucceed = true
        
        do {
            let result = try await mockAIService.enhanceImage(testImage, prompt: "Make it better")
            XCTAssertEqual(result, enhancedImage)
        } catch {
            XCTFail("Mock enhancement should succeed: \(error)")
        }
    }
    
    func testEnhancementFailure() async {
        mockAIService.mockError = .processingError("Mock error")
        
        do {
            _ = try await mockAIService.enhanceImage(testImage, prompt: "Make it better")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }
    
    func testEnhancementWithoutAPIKey() async {
        mockAIService.shouldSucceed = false
        
        do {
            _ = try await mockAIService.enhanceImage(testImage, prompt: "Make it better")
            XCTFail("Should have thrown an error without API key")
        } catch {
            XCTAssertTrue(error is AIError)
        }
    }
}

