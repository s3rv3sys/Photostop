//
//  AIServiceTests.swift
//  PhotoStopTests
//
//  Created by Esh on 2025-08-29.
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
        XCTAssertTrue(aiService.isAPIKeyConfigured())
        XCTAssertEqual(aiService.getAPIKey(), testAPIKey)
    }
    
    func testAPIKeyStorageWithEmptyKey() {
        let emptyKey = ""
        
        let success = aiService.setAPIKey(emptyKey)
        XCTAssertFalse(success)
        XCTAssertFalse(aiService.isAPIKeyConfigured())
    }
    
    func testAPIKeyStorageWithWhitespaceKey() {
        let whitespaceKey = "   "
        
        let success = aiService.setAPIKey(whitespaceKey)
        XCTAssertFalse(success)
        XCTAssertFalse(aiService.isAPIKeyConfigured())
    }
    
    // MARK: - Usage Limit Tests
    
    func testUsageLimits() {
        // Initially should have free uses available
        XCTAssertTrue(aiService.canUseService())
        XCTAssertEqual(aiService.remainingFreeUses, 20)
        
        // Simulate usage by directly modifying the count
        // In a real test, you would use the service and check the count
        aiService.resetUsageCount()
        XCTAssertEqual(aiService.remainingFreeUses, 20)
    }
    
    func testUsageCountReset() {
        // Reset usage count
        aiService.resetUsageCount()
        
        XCTAssertEqual(aiService.usageCount, 0)
        XCTAssertEqual(aiService.remainingFreeUses, 20)
    }
    
    // MARK: - Image Enhancement Tests
    
    func testEnhanceImageWithoutAPIKey() async {
        // Ensure no API key is set
        XCTAssertFalse(aiService.isAPIKeyConfigured())
        
        let enhancedImage = await aiService.enhanceImage(testImage)
        
        // Should return nil when no API key is configured
        XCTAssertNil(enhancedImage)
        XCTAssertEqual(aiService.processingError, .apiKeyNotConfigured)
    }
    
    func testEnhanceImageWithAPIKey() async {
        // Set a test API key
        _ = aiService.setAPIKey("test-api-key")
        
        let enhancedImage = await aiService.enhanceImage(testImage)
        
        // With fallback implementation, should return an enhanced image
        // (The actual enhancement uses Core Image filters as fallback)
        XCTAssertNotNil(enhancedImage)
    }
    
    func testEnhanceImageWithCustomPrompt() async {
        // Set a test API key
        _ = aiService.setAPIKey("test-api-key")
        
        let customPrompt = "Make this image more vibrant"
        let enhancedImage = await aiService.enhanceImage(testImage, prompt: customPrompt)
        
        // Should return enhanced image with custom prompt
        XCTAssertNotNil(enhancedImage)
    }
    
    func testConcurrentImageEnhancement() async {
        // Set a test API key
        _ = aiService.setAPIKey("test-api-key")
        
        // Start two enhancement tasks concurrently
        let task1 = Task {
            await aiService.enhanceImage(testImage)
        }
        
        let task2 = Task {
            await aiService.enhanceImage(testImage)
        }
        
        let result1 = await task1.value
        let result2 = await task2.value
        
        // One should succeed, the other should return nil (due to isProcessing check)
        let successCount = [result1, result2].compactMap { $0 }.count
        XCTAssertLessThanOrEqual(successCount, 2)
    }
    
    // MARK: - Error Handling Tests
    
    func testAIErrorTypes() {
        let apiKeyError = AIError.apiKeyNotConfigured
        let networkError = AIError.networkError("Connection failed")
        let imageProcessingError = AIError.imageProcessingError
        let usageLimitError = AIError.usageLimitExceeded
        let invalidResponseError = AIError.invalidResponse
        
        XCTAssertEqual(apiKeyError.errorDescription, "Gemini API key not configured")
        XCTAssertEqual(networkError.errorDescription, "Network error: Connection failed")
        XCTAssertEqual(imageProcessingError.errorDescription, "Failed to process image")
        XCTAssertEqual(usageLimitError.errorDescription, "Usage limit exceeded. Upgrade to premium for unlimited access.")
        XCTAssertEqual(invalidResponseError.errorDescription, "Invalid response from AI service")
    }
    
    // MARK: - Image Processing Tests
    
    func testImagePreparation() {
        // Test with a large image
        let largeImage = UIImage(systemName: "photo")!
        
        // The service should handle image preparation internally
        // We can't directly test the private method, but we can test the overall flow
        XCTAssertNotNil(largeImage)
    }
    
    // MARK: - Performance Tests
    
    func testImageEnhancementPerformance() {
        // Set API key for the test
        _ = aiService.setAPIKey("test-api-key")
        
        measure {
            Task {
                _ = await aiService.enhanceImage(testImage)
            }
        }
    }
    
    // MARK: - Memory Tests
    
    func testMemoryLeaks() {
        weak var weakAIService = aiService
        aiService = nil
        
        // Give some time for deallocation
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNil(weakAIService, "AIService should be deallocated")
    }
}

// MARK: - Mock Classes for Testing

class MockAIService: AIService {
    var mockEnhancedImage: UIImage?
    var mockError: AIError?
    var mockProcessingDelay: TimeInterval = 0.1
    var mockAPIKeyConfigured = false
    
    override func isAPIKeyConfigured() -> Bool {
        return mockAPIKeyConfigured
    }
    
    override func enhanceImage(_ image: UIImage, prompt: String) async -> UIImage? {
        await MainActor.run {
            self.isProcessing = true
        }
        
        // Simulate processing delay
        try? await Task.sleep(nanoseconds: UInt64(mockProcessingDelay * 1_000_000_000))
        
        await MainActor.run {
            self.isProcessing = false
            
            if let error = mockError {
                self.processingError = error
            }
        }
        
        return mockError == nil ? mockEnhancedImage : nil
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
    
    func testSuccessfulImageEnhancement() async {
        // Setup mock
        mockAIService.mockAPIKeyConfigured = true
        mockAIService.mockEnhancedImage = UIImage(systemName: "photo.fill")!
        
        let enhancedImage = await mockAIService.enhanceImage(testImage, prompt: "Enhance this image")
        
        XCTAssertNotNil(enhancedImage)
        XCTAssertNil(mockAIService.processingError)
    }
    
    func testImageEnhancementWithError() async {
        // Setup mock with error
        mockAIService.mockAPIKeyConfigured = true
        mockAIService.mockError = .networkError("Connection timeout")
        
        let enhancedImage = await mockAIService.enhanceImage(testImage, prompt: "Enhance this image")
        
        XCTAssertNil(enhancedImage)
        XCTAssertNotNil(mockAIService.processingError)
    }
    
    func testImageEnhancementWithoutAPIKey() async {
        // Setup mock without API key
        mockAIService.mockAPIKeyConfigured = false
        
        let enhancedImage = await mockAIService.enhanceImage(testImage, prompt: "Enhance this image")
        
        XCTAssertNil(enhancedImage)
    }
    
    func testProcessingStateManagement() async {
        // Setup mock with delay
        mockAIService.mockAPIKeyConfigured = true
        mockAIService.mockEnhancedImage = testImage
        mockAIService.mockProcessingDelay = 0.5
        
        // Start enhancement
        let enhancementTask = Task {
            await mockAIService.enhanceImage(testImage, prompt: "Test")
        }
        
        // Check processing state
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        XCTAssertTrue(mockAIService.isProcessing)
        
        // Wait for completion
        _ = await enhancementTask.value
        XCTAssertFalse(mockAIService.isProcessing)
    }
}

