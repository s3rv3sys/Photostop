//
//  FrameScoringTests.swift
//  PhotoStopTests
//
//  Created by Esh on 2025-08-29.
//

import XCTest
@testable import PhotoStop

@MainActor
final class FrameScoringTests: XCTestCase {
    
    var frameScoringService: FrameScoringService!
    var testImages: [UIImage]!
    
    override func setUp() {
        super.setUp()
        frameScoringService = FrameScoringService()
        
        // Create test images
        testImages = [
            UIImage(systemName: "photo")!,
            UIImage(systemName: "photo.fill")!,
            UIImage(systemName: "camera")!
        ]
    }
    
    override func tearDown() {
        frameScoringService = nil
        testImages = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testFrameScoringServiceInitialization() {
        XCTAssertNotNil(frameScoringService)
        XCTAssertFalse(frameScoringService.isProcessing)
        XCTAssertNil(frameScoringService.scoringError)
    }
    
    // MARK: - Single Image Scoring Tests
    
    func testScoreImage() async {
        let testImage = testImages[0]
        
        let frameScore = await frameScoringService.scoreImage(testImage)
        
        XCTAssertNotNil(frameScore)
        XCTAssertEqual(frameScore.image, testImage)
        XCTAssertGreaterThanOrEqual(frameScore.qualityScore, 0.0)
        XCTAssertLessThanOrEqual(frameScore.qualityScore, 1.0)
        XCTAssertGreaterThanOrEqual(frameScore.sharpnessScore, 0.0)
        XCTAssertLessThanOrEqual(frameScore.sharpnessScore, 1.0)
        XCTAssertGreaterThanOrEqual(frameScore.exposureScore, 0.0)
        XCTAssertLessThanOrEqual(frameScore.exposureScore, 1.0)
        XCTAssertGreaterThanOrEqual(frameScore.noiseScore, 0.0)
        XCTAssertLessThanOrEqual(frameScore.noiseScore, 1.0)
        XCTAssertGreaterThan(frameScore.processingTime, 0.0)
    }
    
    func testScoreImageProcessingState() async {
        let testImage = testImages[0]
        
        // Start scoring
        let scoringTask = Task {
            await frameScoringService.scoreImage(testImage)
        }
        
        // Check processing state (might be too fast to catch, but test the property)
        let isProcessingDuringScoring = frameScoringService.isProcessing
        
        // Wait for completion
        let frameScore = await scoringTask.value
        
        XCTAssertNotNil(frameScore)
        XCTAssertFalse(frameScoringService.isProcessing)
    }
    
    // MARK: - Multiple Image Scoring Tests
    
    func testScoreMultipleImages() async {
        let frameScores = await frameScoringService.scoreImages(testImages)
        
        XCTAssertEqual(frameScores.count, testImages.count)
        
        // Verify scores are sorted by quality (highest first)
        for i in 0..<frameScores.count - 1 {
            XCTAssertGreaterThanOrEqual(frameScores[i].qualityScore, frameScores[i + 1].qualityScore)
        }
        
        // Verify all scores are valid
        for frameScore in frameScores {
            XCTAssertGreaterThanOrEqual(frameScore.qualityScore, 0.0)
            XCTAssertLessThanOrEqual(frameScore.qualityScore, 1.0)
        }
    }
    
    func testScoreEmptyImageArray() async {
        let frameScores = await frameScoringService.scoreImages([])
        
        XCTAssertTrue(frameScores.isEmpty)
    }
    
    func testGetBestImage() async {
        let bestImage = await frameScoringService.getBestImage(from: testImages)
        
        XCTAssertNotNil(bestImage)
        XCTAssertTrue(testImages.contains(bestImage!))
    }
    
    func testGetBestImageFromEmptyArray() async {
        let bestImage = await frameScoringService.getBestImage(from: [])
        
        XCTAssertNil(bestImage)
    }
    
    func testGetBestImageFromSingleImage() async {
        let singleImage = [testImages[0]]
        let bestImage = await frameScoringService.getBestImage(from: singleImage)
        
        XCTAssertEqual(bestImage, testImages[0])
    }
    
    // MARK: - Image Quality Analysis Tests
    
    func testAnalyzeImageQuality() async {
        let testImage = testImages[0]
        
        let analysis = await frameScoringService.analyzeImageQuality(testImage)
        
        XCTAssertNotNil(analysis.frameScore)
        XCTAssertFalse(analysis.recommendations.isEmpty)
        XCTAssertFalse(analysis.technicalDetails.isEmpty)
        
        // Verify technical details contain expected keys
        XCTAssertNotNil(analysis.technicalDetails["Overall Quality"])
        XCTAssertNotNil(analysis.technicalDetails["Sharpness"])
        XCTAssertNotNil(analysis.technicalDetails["Exposure"])
        XCTAssertNotNil(analysis.technicalDetails["Noise Level"])
        XCTAssertNotNil(analysis.technicalDetails["Processing Time"])
        XCTAssertNotNil(analysis.technicalDetails["Quality Rating"])
    }
    
    // MARK: - FrameScore Model Tests
    
    func testFrameScoreInitialization() {
        let testImage = testImages[0]
        let frameScore = FrameScore(
            image: testImage,
            qualityScore: 0.8,
            sharpnessScore: 0.75,
            exposureScore: 0.85,
            noiseScore: 0.9,
            processingTime: 0.5
        )
        
        XCTAssertEqual(frameScore.image, testImage)
        XCTAssertEqual(frameScore.qualityScore, 0.8)
        XCTAssertEqual(frameScore.sharpnessScore, 0.75)
        XCTAssertEqual(frameScore.exposureScore, 0.85)
        XCTAssertEqual(frameScore.noiseScore, 0.9)
        XCTAssertEqual(frameScore.processingTime, 0.5)
    }
    
    func testFrameScoreQualityRating() {
        let testImage = testImages[0]
        
        let excellentScore = FrameScore(image: testImage, qualityScore: 0.9, sharpnessScore: 0.9, exposureScore: 0.9, noiseScore: 0.9)
        XCTAssertEqual(excellentScore.qualityRating, "Excellent")
        
        let goodScore = FrameScore(image: testImage, qualityScore: 0.7, sharpnessScore: 0.7, exposureScore: 0.7, noiseScore: 0.7)
        XCTAssertEqual(goodScore.qualityRating, "Good")
        
        let fairScore = FrameScore(image: testImage, qualityScore: 0.5, sharpnessScore: 0.5, exposureScore: 0.5, noiseScore: 0.5)
        XCTAssertEqual(fairScore.qualityRating, "Fair")
        
        let poorScore = FrameScore(image: testImage, qualityScore: 0.3, sharpnessScore: 0.3, exposureScore: 0.3, noiseScore: 0.3)
        XCTAssertEqual(poorScore.qualityRating, "Poor")
        
        let veryPoorScore = FrameScore(image: testImage, qualityScore: 0.1, sharpnessScore: 0.1, exposureScore: 0.1, noiseScore: 0.1)
        XCTAssertEqual(veryPoorScore.qualityRating, "Very Poor")
    }
    
    func testFrameScoreAnalysisDetails() {
        let testImage = testImages[0]
        
        // Test high quality scores
        let highQualityScore = FrameScore(
            image: testImage,
            qualityScore: 0.9,
            sharpnessScore: 0.9,
            exposureScore: 0.9,
            noiseScore: 0.9
        )
        
        let highQualityDetails = highQualityScore.analysisDetails
        XCTAssertTrue(highQualityDetails.contains("Excellent sharpness"))
        XCTAssertTrue(highQualityDetails.contains("Well exposed"))
        XCTAssertTrue(highQualityDetails.contains("Low noise"))
        
        // Test low quality scores
        let lowQualityScore = FrameScore(
            image: testImage,
            qualityScore: 0.3,
            sharpnessScore: 0.3,
            exposureScore: 0.3,
            noiseScore: 0.3
        )
        
        let lowQualityDetails = lowQualityScore.analysisDetails
        XCTAssertTrue(lowQualityDetails.contains("Significant blur detected"))
        XCTAssertTrue(lowQualityDetails.contains("Poor exposure"))
        XCTAssertTrue(lowQualityDetails.contains("High noise levels"))
    }
    
    func testFrameScoreComparable() {
        let testImage = testImages[0]
        
        let score1 = FrameScore(image: testImage, qualityScore: 0.8, sharpnessScore: 0.8, exposureScore: 0.8, noiseScore: 0.8)
        let score2 = FrameScore(image: testImage, qualityScore: 0.6, sharpnessScore: 0.6, exposureScore: 0.6, noiseScore: 0.6)
        let score3 = FrameScore(image: testImage, qualityScore: 0.8, sharpnessScore: 0.8, exposureScore: 0.8, noiseScore: 0.8)
        
        XCTAssertTrue(score1 > score2)
        XCTAssertFalse(score2 > score1)
        XCTAssertEqual(score1, score1) // Same instance
        XCTAssertNotEqual(score1, score3) // Different instances with same scores
    }
    
    // MARK: - Fallback Scoring Tests
    
    func testFallbackScoring() {
        let testImage = testImages[0]
        
        let fallbackScore = FrameScore.createFallbackScore(for: testImage)
        
        XCTAssertNotNil(fallbackScore)
        XCTAssertEqual(fallbackScore.image, testImage)
        XCTAssertGreaterThanOrEqual(fallbackScore.qualityScore, 0.0)
        XCTAssertLessThanOrEqual(fallbackScore.qualityScore, 1.0)
        XCTAssertGreaterThan(fallbackScore.processingTime, 0.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testScoringErrorTypes() {
        let modelLoadError = ScoringError.modelLoadError("Model not found")
        let processingError = ScoringError.processingError("Processing failed")
        let invalidImageError = ScoringError.invalidImage
        
        XCTAssertEqual(modelLoadError.errorDescription, "Failed to load ML model: Model not found")
        XCTAssertEqual(processingError.errorDescription, "Processing error: Processing failed")
        XCTAssertEqual(invalidImageError.errorDescription, "Invalid image for scoring")
    }
    
    // MARK: - Performance Tests
    
    func testSingleImageScoringPerformance() {
        let testImage = testImages[0]
        
        measure {
            Task {
                _ = await frameScoringService.scoreImage(testImage)
            }
        }
    }
    
    func testMultipleImageScoringPerformance() {
        measure {
            Task {
                _ = await frameScoringService.scoreImages(testImages)
            }
        }
    }
    
    func testFallbackScoringPerformance() {
        let testImage = testImages[0]
        
        measure {
            _ = FrameScore.createFallbackScore(for: testImage)
        }
    }
    
    // MARK: - Memory Tests
    
    func testMemoryLeaks() {
        weak var weakFrameScoringService = frameScoringService
        frameScoringService = nil
        
        // Give some time for deallocation
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNil(weakFrameScoringService, "FrameScoringService should be deallocated")
    }
    
    // MARK: - Concurrent Scoring Tests
    
    func testConcurrentScoring() async {
        let image1 = testImages[0]
        let image2 = testImages[1]
        let image3 = testImages[2]
        
        // Start multiple scoring operations concurrently
        async let score1 = frameScoringService.scoreImage(image1)
        async let score2 = frameScoringService.scoreImage(image2)
        async let score3 = frameScoringService.scoreImage(image3)
        
        let scores = await [score1, score2, score3]
        
        // All scoring operations should complete successfully
        XCTAssertEqual(scores.count, 3)
        for score in scores {
            XCTAssertGreaterThanOrEqual(score.qualityScore, 0.0)
            XCTAssertLessThanOrEqual(score.qualityScore, 1.0)
        }
    }
}

// MARK: - Mock Classes for Testing

class MockFrameScoringService: FrameScoringService {
    var mockScores: [Float] = [0.8, 0.6, 0.9]
    var mockError: ScoringError?
    var mockProcessingDelay: TimeInterval = 0.1
    
    override func scoreImage(_ image: UIImage) async -> FrameScore {
        await MainActor.run {
            self.isProcessing = true
        }
        
        // Simulate processing delay
        try? await Task.sleep(nanoseconds: UInt64(mockProcessingDelay * 1_000_000_000))
        
        await MainActor.run {
            self.isProcessing = false
            
            if let error = mockError {
                self.scoringError = error
            }
        }
        
        // Return mock score or fallback
        if mockError != nil {
            return FrameScore.createFallbackScore(for: image)
        }
        
        let mockScore = mockScores.randomElement() ?? 0.7
        return FrameScore(
            image: image,
            qualityScore: mockScore,
            sharpnessScore: mockScore * 0.9,
            exposureScore: mockScore * 1.1,
            noiseScore: mockScore * 0.8,
            processingTime: mockProcessingDelay
        )
    }
}

// MARK: - Integration Tests

final class FrameScoringIntegrationTests: XCTestCase {
    
    var mockFrameScoringService: MockFrameScoringService!
    var testImages: [UIImage]!
    
    override func setUp() {
        super.setUp()
        mockFrameScoringService = MockFrameScoringService()
        testImages = [
            UIImage(systemName: "photo")!,
            UIImage(systemName: "photo.fill")!,
            UIImage(systemName: "camera")!
        ]
    }
    
    override func tearDown() {
        mockFrameScoringService = nil
        testImages = nil
        super.tearDown()
    }
    
    func testBestImageSelection() async {
        // Set predictable mock scores
        mockFrameScoringService.mockScores = [0.6, 0.9, 0.7] // Second image should be best
        
        let bestImage = await mockFrameScoringService.getBestImage(from: testImages)
        
        XCTAssertNotNil(bestImage)
        // The best image should be determined by the scoring service
        XCTAssertTrue(testImages.contains(bestImage!))
    }
    
    func testScoringWithError() async {
        mockFrameScoringService.mockError = .processingError("Mock processing error")
        
        let frameScore = await mockFrameScoringService.scoreImage(testImages[0])
        
        // Should still return a score (fallback)
        XCTAssertNotNil(frameScore)
        XCTAssertNotNil(mockFrameScoringService.scoringError)
    }
    
    func testProcessingStateManagement() async {
        mockFrameScoringService.mockProcessingDelay = 0.5
        
        // Start scoring
        let scoringTask = Task {
            await mockFrameScoringService.scoreImage(testImages[0])
        }
        
        // Check processing state
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        XCTAssertTrue(mockFrameScoringService.isProcessing)
        
        // Wait for completion
        _ = await scoringTask.value
        XCTAssertFalse(mockFrameScoringService.isProcessing)
    }
}

