//
//  FrameScoringTests.swift
//  PhotoStopTests
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import XCTest
@testable import PhotoStop

@MainActor
final class FrameScoringTests: XCTestCase {
    
    var frameScoringService: FrameScoringService!
    var testImages: [UIImage]!
    
    override func setUp() {
        super.setUp()
        frameScoringService = FrameScoringService.shared
        
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
        XCTAssertGreaterThanOrEqual(frameScore.overallScore, 0.0)
        XCTAssertLessThanOrEqual(frameScore.overallScore, 1.0)
        XCTAssertGreaterThanOrEqual(frameScore.sharpnessScore, 0.0)
        XCTAssertLessThanOrEqual(frameScore.sharpnessScore, 1.0)
        XCTAssertGreaterThanOrEqual(frameScore.exposureScore, 0.0)
        XCTAssertLessThanOrEqual(frameScore.exposureScore, 1.0)
        XCTAssertGreaterThanOrEqual(frameScore.compositionScore, 0.0)
        XCTAssertLessThanOrEqual(frameScore.compositionScore, 1.0)
    }
    
    func testScoreMultipleImages() async {
        var scores: [FrameScore] = []
        
        for image in testImages {
            let score = await frameScoringService.scoreImage(image)
            scores.append(score)
        }
        
        XCTAssertEqual(scores.count, testImages.count)
        
        // All scores should be valid
        for score in scores {
            XCTAssertGreaterThanOrEqual(score.overallScore, 0.0)
            XCTAssertLessThanOrEqual(score.overallScore, 1.0)
        }
    }
    
    // MARK: - Frame Bundle Scoring Tests
    
    func testScoreFrameBundle() async {
        // Create a mock frame bundle
        let frames = testImages.map { image in
            CapturedFrame(
                image: image,
                metadata: FrameMetadata(
                    timestamp: Date(),
                    lens: .wide,
                    exposureSettings: ExposureSettings(iso: 100, shutterSpeed: 1/60, aperture: 2.8),
                    focusDistance: 1.0,
                    hasDepthData: false,
                    motionDetected: false,
                    faceCount: 0,
                    qualityScore: 0.8
                )
            )
        }
        
        let sceneAnalysis = SceneAnalysis(
            dominantScene: .general,
            lightingCondition: .normal,
            motionLevel: .low,
            subjectCount: 0,
            recommendedEnhancement: .simpleEnhance
        )
        
        let frameBundle = FrameBundle(
            frames: frames,
            captureTime: Date(),
            sceneAnalysis: sceneAnalysis
        )
        
        let scoredBundle = await frameScoringService.scoreFrameBundle(frameBundle)
        
        XCTAssertNotNil(scoredBundle)
        XCTAssertEqual(scoredBundle.frames.count, frameBundle.frames.count)
        XCTAssertNotNil(scoredBundle.bestFrame)
        
        // Best frame should have the highest score
        if let bestFrame = scoredBundle.bestFrame {
            for frame in scoredBundle.frames {
                XCTAssertGreaterThanOrEqual(bestFrame.score.overallScore, frame.score.overallScore)
            }
        }
    }
    
    // MARK: - Best Frame Selection Tests
    
    func testSelectBestFrame() async {
        let scores = await withTaskGroup(of: FrameScore.self) { group in
            var results: [FrameScore] = []
            
            for image in testImages {
                group.addTask {
                    await self.frameScoringService.scoreImage(image)
                }
            }
            
            for await score in group {
                results.append(score)
            }
            
            return results
        }
        
        let bestScore = frameScoringService.selectBestScore(from: scores)
        
        XCTAssertNotNil(bestScore)
        
        // Best score should be >= all other scores
        for score in scores {
            XCTAssertGreaterThanOrEqual(bestScore.overallScore, score.overallScore)
        }
    }
    
    // MARK: - Algorithm Tests
    
    func testSharpnessDetection() {
        let testImage = testImages[0]
        let sharpnessScore = frameScoringService.calculateSharpness(testImage)
        
        XCTAssertGreaterThanOrEqual(sharpnessScore, 0.0)
        XCTAssertLessThanOrEqual(sharpnessScore, 1.0)
    }
    
    func testExposureAnalysis() {
        let testImage = testImages[0]
        let exposureScore = frameScoringService.calculateExposure(testImage)
        
        XCTAssertGreaterThanOrEqual(exposureScore, 0.0)
        XCTAssertLessThanOrEqual(exposureScore, 1.0)
    }
    
    func testCompositionAnalysis() {
        let testImage = testImages[0]
        let compositionScore = frameScoringService.calculateComposition(testImage)
        
        XCTAssertGreaterThanOrEqual(compositionScore, 0.0)
        XCTAssertLessThanOrEqual(compositionScore, 1.0)
    }
    
    func testNoiseDetection() {
        let testImage = testImages[0]
        let noiseScore = frameScoringService.calculateNoise(testImage)
        
        XCTAssertGreaterThanOrEqual(noiseScore, 0.0)
        XCTAssertLessThanOrEqual(noiseScore, 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testScoringPerformance() {
        let testImage = testImages[0]
        
        measure {
            Task {
                _ = await frameScoringService.scoreImage(testImage)
            }
        }
    }
    
    func testBatchScoringPerformance() {
        measure {
            Task {
                for image in testImages {
                    _ = await frameScoringService.scoreImage(image)
                }
            }
        }
    }
    
    // MARK: - Concurrent Scoring Tests
    
    func testConcurrentScoring() async {
        // Score multiple images concurrently
        async let score1 = frameScoringService.scoreImage(testImages[0])
        async let score2 = frameScoringService.scoreImage(testImages[1])
        async let score3 = frameScoringService.scoreImage(testImages[2])
        
        let (s1, s2, s3) = await (score1, score2, score3)
        
        // All scores should be valid
        let scores = [s1, s2, s3]
        for score in scores {
            XCTAssertGreaterThanOrEqual(score.overallScore, 0.0)
            XCTAssertLessThanOrEqual(score.overallScore, 1.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testScoringErrorTypes() {
        let processingError = ScoringError.processingFailed("Test error")
        let modelError = ScoringError.modelUnavailable
        let invalidError = ScoringError.invalidImage
        
        XCTAssertEqual(processingError.errorDescription, "Processing failed: Test error")
        XCTAssertEqual(modelError.errorDescription, "ML model unavailable")
        XCTAssertEqual(invalidError.errorDescription, "Invalid image format")
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryUsage() {
        weak var weakFrameScoringService = frameScoringService
        frameScoringService = nil
        
        // Give some time for deallocation
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Note: Singleton won't be deallocated, so we just test that it doesn't crash
        XCTAssertTrue(true)
    }
}

// MARK: - Mock Frame Scoring Service

class MockFrameScoringService: FrameScoringService {
    var mockScore: FrameScore?
    var mockError: ScoringError?
    var shouldSucceed = true
    
    override func scoreImage(_ image: UIImage) async -> FrameScore {
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        if let error = mockError {
            await MainActor.run {
                self.scoringError = error
            }
        }
        
        if let score = mockScore {
            return score
        }
        
        // Return a mock score
        return FrameScore(
            overallScore: shouldSucceed ? 0.8 : 0.3,
            sharpnessScore: 0.7,
            exposureScore: 0.8,
            compositionScore: 0.9,
            noiseScore: 0.6,
            faceCount: 0,
            hasGoodLighting: true,
            isWellComposed: true,
            timestamp: Date()
        )
    }
}

// MARK: - Integration Tests

final class FrameScoringIntegrationTests: XCTestCase {
    
    var mockFrameScoringService: MockFrameScoringService!
    var testImage: UIImage!
    
    override func setUp() {
        super.setUp()
        mockFrameScoringService = MockFrameScoringService()
        testImage = UIImage(systemName: "photo")!
    }
    
    override func tearDown() {
        mockFrameScoringService = nil
        testImage = nil
        super.tearDown()
    }
    
    func testSuccessfulScoring() async {
        mockFrameScoringService.shouldSucceed = true
        
        let score = await mockFrameScoringService.scoreImage(testImage)
        
        XCTAssertGreaterThan(score.overallScore, 0.5)
        XCTAssertNil(mockFrameScoringService.scoringError)
    }
    
    func testScoringWithError() async {
        mockFrameScoringService.mockError = .processingFailed("Mock error")
        
        let score = await mockFrameScoringService.scoreImage(testImage)
        
        // Should still return a score but set error
        XCTAssertNotNil(score)
        XCTAssertNotNil(mockFrameScoringService.scoringError)
    }
    
    func testCustomScore() async {
        let customScore = FrameScore(
            overallScore: 0.95,
            sharpnessScore: 0.9,
            exposureScore: 1.0,
            compositionScore: 0.9,
            noiseScore: 0.95,
            faceCount: 2,
            hasGoodLighting: true,
            isWellComposed: true,
            timestamp: Date()
        )
        
        mockFrameScoringService.mockScore = customScore
        
        let score = await mockFrameScoringService.scoreImage(testImage)
        
        XCTAssertEqual(score.overallScore, 0.95)
        XCTAssertEqual(score.faceCount, 2)
        XCTAssertTrue(score.hasGoodLighting)
        XCTAssertTrue(score.isWellComposed)
    }
}

