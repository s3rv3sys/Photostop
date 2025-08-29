//
//  PersonalizationEngineTests.swift
//  PhotoStopTests
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import XCTest
@testable import PhotoStop

final class PersonalizationEngineTests: XCTestCase {
    
    var engine: PersonalizationEngine!
    
    override func setUp() {
        super.setUp()
        engine = PersonalizationEngine.shared
        engine.reset() // Start with clean state
    }
    
    override func tearDown() {
        engine.reset()
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Profile Management Tests
    
    func testInitialProfileIsNeutral() {
        let profile = engine.currentProfile()
        
        XCTAssertTrue(profile.enabled)
        XCTAssertTrue(profile.isNeutral)
        XCTAssertEqual(profile.sharpnessBias, 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.exposureBias, 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.noiseTolerance, 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.portraitAffinity, 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.hdrAffinity, 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.teleAffinity, 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.ultraWideAffinity, 0.0, accuracy: 0.001)
    }
    
    func testEnableDisablePersonalization() {
        // Test disabling
        engine.setEnabled(false)
        XCTAssertFalse(engine.currentProfile().enabled)
        
        // Test enabling
        engine.setEnabled(true)
        XCTAssertTrue(engine.currentProfile().enabled)
    }
    
    func testProfilePersistence() {
        // Make some changes
        engine.setEnabled(false)
        engine.learnFromRating(true, frameScore: createMockFrameScore(sharpness: 0.9))
        
        // Create new engine instance (simulates app restart)
        let newEngine = PersonalizationEngine()
        
        // Should load persisted profile
        let profile = newEngine.currentProfile()
        XCTAssertFalse(profile.enabled) // Should remember disabled state
    }
    
    // MARK: - Learning Tests
    
    func testPositiveLearning() {
        let highSharpnessScore = createMockFrameScore(sharpness: 0.9, exposure: 0.8, noise: 0.7)
        
        // Learn from positive rating
        engine.learnFromRating(true, frameScore: highSharpnessScore)
        
        let profile = engine.currentProfile()
        
        // Should increase sharpness bias slightly
        XCTAssertGreaterThan(profile.sharpnessBias, 0.0)
        XCTAssertLessThan(profile.sharpnessBias, 0.1) // Should be small increment
    }
    
    func testNegativeLearning() {
        let lowSharpnessScore = createMockFrameScore(sharpness: 0.3, exposure: 0.4, noise: 0.2)
        
        // Learn from negative rating
        engine.learnFromRating(false, frameScore: lowSharpnessScore)
        
        let profile = engine.currentProfile()
        
        // Should decrease tolerance for low sharpness
        XCTAssertLessThan(profile.sharpnessBias, 0.0)
        XCTAssertGreaterThan(profile.sharpnessBias, -0.1) // Should be small decrement
    }
    
    func testLearningFromKeepReject() {
        let goodScore = createMockFrameScore(sharpness: 0.8, exposure: 0.9, noise: 0.8)
        let badScore = createMockFrameScore(sharpness: 0.4, exposure: 0.3, noise: 0.2)
        
        // Learn from keep/reject behavior
        engine.learnFromKeepReject(kept: goodScore, rejected: [badScore])
        
        let profile = engine.currentProfile()
        
        // Should adjust preferences based on kept vs rejected
        XCTAssertNotEqual(profile.sharpnessBias, 0.0)
        XCTAssertNotEqual(profile.exposureBias, 0.0)
    }
    
    func testLearningBounds() {
        let extremeScore = createMockFrameScore(sharpness: 1.0, exposure: 1.0, noise: 1.0)
        
        // Learn many times to test bounds
        for _ in 0..<100 {
            engine.learnFromRating(true, frameScore: extremeScore)
        }
        
        let profile = engine.currentProfile()
        
        // All biases should be bounded to [-0.15, 0.15]
        XCTAssertLessThanOrEqual(profile.sharpnessBias, 0.15)
        XCTAssertGreaterThanOrEqual(profile.sharpnessBias, -0.15)
        XCTAssertLessThanOrEqual(profile.exposureBias, 0.15)
        XCTAssertGreaterThanOrEqual(profile.exposureBias, -0.15)
        XCTAssertLessThanOrEqual(profile.noiseTolerance, 0.15)
        XCTAssertGreaterThanOrEqual(profile.noiseTolerance, -0.15)
    }
    
    // MARK: - Score Personalization Tests
    
    func testScorePersonalizationDisabled() {
        engine.setEnabled(false)
        
        let originalScore = createMockFrameScore(sharpness: 0.7, exposure: 0.8, noise: 0.6)
        let personalizedScore = engine.personalizeScore(originalScore)
        
        // When disabled, should return original score
        XCTAssertEqual(personalizedScore.overallScore, originalScore.overallScore, accuracy: 0.001)
        XCTAssertEqual(personalizedScore.sharpnessScore, originalScore.sharpnessScore, accuracy: 0.001)
        XCTAssertEqual(personalizedScore.exposureScore, originalScore.exposureScore, accuracy: 0.001)
    }
    
    func testScorePersonalizationEnabled() {
        // Learn to prefer sharper images
        let sharpScore = createMockFrameScore(sharpness: 0.9, exposure: 0.7, noise: 0.6)
        for _ in 0..<10 {
            engine.learnFromRating(true, frameScore: sharpScore)
        }
        
        let originalScore = createMockFrameScore(sharpness: 0.8, exposure: 0.7, noise: 0.6)
        let personalizedScore = engine.personalizeScore(originalScore)
        
        // Should boost scores for sharp images
        XCTAssertGreaterThan(personalizedScore.overallScore, originalScore.overallScore)
    }
    
    func testScorePersonalizationBounds() {
        // Create extreme bias
        let extremeScore = createMockFrameScore(sharpness: 1.0, exposure: 1.0, noise: 1.0)
        for _ in 0..<50 {
            engine.learnFromRating(true, frameScore: extremeScore)
        }
        
        let testScore = createMockFrameScore(sharpness: 0.5, exposure: 0.5, noise: 0.5)
        let personalizedScore = engine.personalizeScore(testScore)
        
        // Personalized scores should still be in valid range [0, 1]
        XCTAssertGreaterThanOrEqual(personalizedScore.overallScore, 0.0)
        XCTAssertLessThanOrEqual(personalizedScore.overallScore, 1.0)
        XCTAssertGreaterThanOrEqual(personalizedScore.sharpnessScore, 0.0)
        XCTAssertLessThanOrEqual(personalizedScore.sharpnessScore, 1.0)
        XCTAssertGreaterThanOrEqual(personalizedScore.exposureScore, 0.0)
        XCTAssertLessThanOrEqual(personalizedScore.exposureScore, 1.0)
    }
    
    // MARK: - Lens Preference Tests
    
    func testLensPreferenceLearning() {
        let wideScore = createMockFrameScore(sharpness: 0.8, exposure: 0.7, noise: 0.6, lens: .wide)
        let teleScore = createMockFrameScore(sharpness: 0.7, exposure: 0.8, noise: 0.7, lens: .telephoto)
        
        // Learn preference for telephoto
        for _ in 0..<10 {
            engine.learnFromRating(true, frameScore: teleScore)
            engine.learnFromRating(false, frameScore: wideScore)
        }
        
        let profile = engine.currentProfile()
        
        // Should develop telephoto preference
        XCTAssertGreaterThan(profile.teleAffinity, profile.ultraWideAffinity)
    }
    
    // MARK: - Portrait and HDR Preference Tests
    
    func testPortraitPreferenceLearning() {
        let portraitScore = createMockFrameScore(sharpness: 0.8, exposure: 0.7, noise: 0.6, faceCount: 2)
        let nonPortraitScore = createMockFrameScore(sharpness: 0.8, exposure: 0.7, noise: 0.6, faceCount: 0)
        
        // Learn preference for portraits
        for _ in 0..<10 {
            engine.learnFromRating(true, frameScore: portraitScore)
            engine.learnFromRating(false, frameScore: nonPortraitScore)
        }
        
        let profile = engine.currentProfile()
        
        // Should develop portrait preference
        XCTAssertGreaterThan(profile.portraitAffinity, 0.0)
    }
    
    func testHDRPreferenceLearning() {
        let hdrScore = createMockFrameScore(sharpness: 0.7, exposure: 0.9, noise: 0.6, hasGoodLighting: false)
        let normalScore = createMockFrameScore(sharpness: 0.7, exposure: 0.6, noise: 0.6, hasGoodLighting: true)
        
        // Learn preference for HDR scenarios
        for _ in 0..<10 {
            engine.learnFromRating(true, frameScore: hdrScore)
            engine.learnFromRating(false, frameScore: normalScore)
        }
        
        let profile = engine.currentProfile()
        
        // Should develop HDR preference
        XCTAssertGreaterThan(profile.hdrAffinity, 0.0)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Make changes
        engine.setEnabled(false)
        let score = createMockFrameScore(sharpness: 0.9, exposure: 0.8, noise: 0.7)
        for _ in 0..<10 {
            engine.learnFromRating(true, frameScore: score)
        }
        
        // Verify changes
        var profile = engine.currentProfile()
        XCTAssertFalse(profile.enabled)
        XCTAssertFalse(profile.isNeutral)
        
        // Reset
        engine.reset()
        
        // Should be back to neutral
        profile = engine.currentProfile()
        XCTAssertTrue(profile.enabled)
        XCTAssertTrue(profile.isNeutral)
    }
    
    // MARK: - Performance Tests
    
    func testLearningPerformance() {
        let score = createMockFrameScore(sharpness: 0.8, exposure: 0.7, noise: 0.6)
        
        measure {
            for _ in 0..<100 {
                engine.learnFromRating(true, frameScore: score)
            }
        }
    }
    
    func testPersonalizationPerformance() {
        // Build some preferences first
        let score = createMockFrameScore(sharpness: 0.8, exposure: 0.7, noise: 0.6)
        for _ in 0..<20 {
            engine.learnFromRating(true, frameScore: score)
        }
        
        measure {
            for _ in 0..<100 {
                _ = engine.personalizeScore(score)
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentLearning() {
        let expectation = XCTestExpectation(description: "Concurrent learning")
        expectation.expectedFulfillmentCount = 10
        
        let score = createMockFrameScore(sharpness: 0.8, exposure: 0.7, noise: 0.6)
        
        // Perform concurrent learning operations
        for i in 0..<10 {
            DispatchQueue.global().async {
                self.engine.learnFromRating(i % 2 == 0, frameScore: score)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should complete without crashing
        XCTAssertTrue(true)
    }
    
    // MARK: - Edge Cases Tests
    
    func testExtremeScores() {
        let minScore = createMockFrameScore(sharpness: 0.0, exposure: 0.0, noise: 0.0)
        let maxScore = createMockFrameScore(sharpness: 1.0, exposure: 1.0, noise: 1.0)
        
        // Should handle extreme scores without crashing
        engine.learnFromRating(true, frameScore: minScore)
        engine.learnFromRating(false, frameScore: maxScore)
        
        let personalizedMin = engine.personalizeScore(minScore)
        let personalizedMax = engine.personalizeScore(maxScore)
        
        // Results should still be in valid range
        XCTAssertGreaterThanOrEqual(personalizedMin.overallScore, 0.0)
        XCTAssertLessThanOrEqual(personalizedMin.overallScore, 1.0)
        XCTAssertGreaterThanOrEqual(personalizedMax.overallScore, 0.0)
        XCTAssertLessThanOrEqual(personalizedMax.overallScore, 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockFrameScore(
        sharpness: Float = 0.7,
        exposure: Float = 0.7,
        noise: Float = 0.7,
        faceCount: Int = 0,
        hasGoodLighting: Bool = true,
        lens: CameraLens = .wide
    ) -> FrameScore {
        return FrameScore(
            overallScore: (sharpness + exposure + noise) / 3.0,
            sharpnessScore: sharpness,
            exposureScore: exposure,
            compositionScore: 0.7,
            noiseScore: noise,
            faceCount: faceCount,
            hasGoodLighting: hasGoodLighting,
            isWellComposed: true,
            timestamp: Date(),
            lens: lens
        )
    }
}

// MARK: - Mock Personalization Store

class MockPersonalizationStore: PersonalizationStore {
    private var mockProfile = PersonalizationProfile()
    
    override var currentProfile: PersonalizationProfile {
        get { return mockProfile }
        set { mockProfile = newValue }
    }
    
    override func save(_ profile: PersonalizationProfile) {
        mockProfile = profile
    }
    
    override func load() -> PersonalizationProfile {
        return mockProfile
    }
    
    override func reset() {
        mockProfile = PersonalizationProfile()
    }
}

// MARK: - Integration Tests

final class PersonalizationEngineIntegrationTests: XCTestCase {
    
    var engine: PersonalizationEngine!
    
    override func setUp() {
        super.setUp()
        engine = PersonalizationEngine.shared
        engine.reset()
    }
    
    override func tearDown() {
        engine.reset()
        engine = nil
        super.tearDown()
    }
    
    func testRealisticLearningScenario() {
        // Simulate user who prefers sharp, well-exposed portraits
        let goodPortrait = createFrameScore(sharpness: 0.9, exposure: 0.8, faceCount: 1)
        let blurryPortrait = createFrameScore(sharpness: 0.4, exposure: 0.8, faceCount: 1)
        let sharpLandscape = createFrameScore(sharpness: 0.9, exposure: 0.7, faceCount: 0)
        
        // User rates good portraits highly
        for _ in 0..<15 {
            engine.learnFromRating(true, frameScore: goodPortrait)
        }
        
        // User rates blurry portraits poorly
        for _ in 0..<10 {
            engine.learnFromRating(false, frameScore: blurryPortrait)
        }
        
        // User sometimes likes landscapes
        for _ in 0..<5 {
            engine.learnFromRating(true, frameScore: sharpLandscape)
        }
        
        let profile = engine.currentProfile()
        
        // Should develop preferences
        XCTAssertGreaterThan(profile.sharpnessBias, 0.0) // Prefers sharp images
        XCTAssertGreaterThan(profile.portraitAffinity, 0.0) // Prefers portraits
        XCTAssertFalse(profile.isNeutral) // Should have learned preferences
        
        // Test personalization effect
        let testPortrait = createFrameScore(sharpness: 0.8, exposure: 0.7, faceCount: 1)
        let personalizedScore = engine.personalizeScore(testPortrait)
        
        // Should boost portrait scores
        XCTAssertGreaterThan(personalizedScore.overallScore, testPortrait.overallScore)
    }
    
    private func createFrameScore(sharpness: Float, exposure: Float, faceCount: Int) -> FrameScore {
        return FrameScore(
            overallScore: (sharpness + exposure) / 2.0,
            sharpnessScore: sharpness,
            exposureScore: exposure,
            compositionScore: 0.7,
            noiseScore: 0.7,
            faceCount: faceCount,
            hasGoodLighting: true,
            isWellComposed: true,
            timestamp: Date()
        )
    }
}

