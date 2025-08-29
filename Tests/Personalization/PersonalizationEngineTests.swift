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
    var mockStore: MockPersonalizationStore!
    
    override func setUp() {
        super.setUp()
        mockStore = MockPersonalizationStore()
        engine = PersonalizationEngine(store: mockStore)
    }
    
    override func tearDown() {
        engine = nil
        mockStore = nil
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
        // Modify profile
        engine.updatePreference(\.sharpnessBias, value: 0.5)
        engine.updatePreference(\.portraitAffinity, value: -0.3)
        
        // Verify changes are saved
        XCTAssertTrue(mockStore.saveProfileCalled)
        
        // Verify profile values
        let profile = engine.currentProfile()
        XCTAssertEqual(profile.sharpnessBias, 0.5, accuracy: 0.001)
        XCTAssertEqual(profile.portraitAffinity, -0.3, accuracy: 0.001)
    }
    
    func testProfileReset() {
        // Modify profile
        engine.updatePreference(\.sharpnessBias, value: 0.8)
        engine.updatePreference(\.exposureBias, value: -0.4)
        engine.updatePreference(\.portraitAffinity, value: 0.6)
        
        // Reset
        engine.reset()
        
        // Verify reset to neutral
        let profile = engine.currentProfile()
        XCTAssertTrue(profile.isNeutral)
        XCTAssertEqual(profile.sharpnessBias, 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.exposureBias, 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.portraitAffinity, 0.0, accuracy: 0.001)
    }
    
    // MARK: - Learning Tests
    
    func testPositiveFeedbackLearning() {
        let features = PersonalizationFeatures(
            sharpness: 0.8,
            exposure: 0.6,
            noise: 0.2,
            isPortrait: true,
            isHDR: false
        )
        
        let event = PersonalizationEvent(
            features: features,
            feedback: .positive,
            lens: .wide,
            timestamp: Date()
        )
        
        // Apply multiple positive events
        for _ in 0..<10 {
            engine.update(with: event)
        }
        
        let profile = engine.currentProfile()
        
        // Should learn to prefer similar characteristics
        XCTAssertGreaterThan(profile.sharpnessBias, 0.0)
        XCTAssertGreaterThan(profile.exposureBias, 0.0)
        XCTAssertLessThan(profile.noiseTolerance, 0.0) // Lower noise is better
        XCTAssertGreaterThan(profile.portraitAffinity, 0.0)
        XCTAssertEqual(profile.hdrAffinity, 0.0, accuracy: 0.05) // No HDR in examples
    }
    
    func testNegativeFeedbackLearning() {
        let features = PersonalizationFeatures(
            sharpness: 0.3, // Low sharpness
            exposure: 0.2, // Underexposed
            noise: 0.8, // High noise
            isPortrait: false,
            isHDR: true
        )
        
        let event = PersonalizationEvent(
            features: features,
            feedback: .negative,
            lens: .ultraWide,
            timestamp: Date()
        )
        
        // Apply multiple negative events
        for _ in 0..<10 {
            engine.update(with: event)
        }
        
        let profile = engine.currentProfile()
        
        // Should learn to avoid similar characteristics
        XCTAssertLessThan(profile.sharpnessBias, 0.0) // Avoid low sharpness
        XCTAssertLessThan(profile.exposureBias, 0.0) // Avoid underexposure
        XCTAssertGreaterThan(profile.noiseTolerance, 0.0) // Avoid high noise
        XCTAssertLessThan(profile.hdrAffinity, 0.0) // Avoid HDR
        XCTAssertLessThan(profile.ultraWideAffinity, 0.0) // Avoid ultra-wide
    }
    
    func testMixedFeedbackLearning() {
        // Positive feedback for sharp, well-exposed portraits
        let positiveFeatures = PersonalizationFeatures(
            sharpness: 0.9,
            exposure: 0.7,
            noise: 0.1,
            isPortrait: true,
            isHDR: false
        )
        
        let positiveEvent = PersonalizationEvent(
            features: positiveFeatures,
            feedback: .positive,
            lens: .wide,
            timestamp: Date()
        )
        
        // Negative feedback for blurry, noisy landscapes
        let negativeFeatures = PersonalizationFeatures(
            sharpness: 0.2,
            exposure: 0.5,
            noise: 0.9,
            isPortrait: false,
            isHDR: false
        )
        
        let negativeEvent = PersonalizationEvent(
            features: negativeFeatures,
            feedback: .negative,
            lens: .ultraWide,
            timestamp: Date()
        )
        
        // Apply mixed feedback
        for _ in 0..<5 {
            engine.update(with: positiveEvent)
            engine.update(with: negativeEvent)
        }
        
        let profile = engine.currentProfile()
        
        // Should learn preferences from both positive and negative examples
        XCTAssertGreaterThan(profile.sharpnessBias, 0.0) // Prefer sharp images
        XCTAssertLessThan(profile.noiseTolerance, 0.0) // Avoid noise
        XCTAssertGreaterThan(profile.portraitAffinity, 0.0) // Prefer portraits
        XCTAssertLessThan(profile.ultraWideAffinity, 0.0) // Avoid ultra-wide for poor examples
    }
    
    // MARK: - Bias Application Tests
    
    func testBiasApplicationWithNeutralProfile() {
        let features = PersonalizationFeatures(
            sharpness: 0.6,
            exposure: 0.5,
            noise: 0.3,
            isPortrait: false,
            isHDR: false
        )
        
        let baseScore: Float = 0.7
        let biasedScore = engine.applyBias(
            baseScore: baseScore,
            features: features,
            lens: .wide
        )
        
        // Neutral profile should not change the score
        XCTAssertEqual(biasedScore, baseScore, accuracy: 0.001)
    }
    
    func testBiasApplicationWithLearnedPreferences() {
        // Train the engine to prefer sharp, portrait images
        let trainingFeatures = PersonalizationFeatures(
            sharpness: 0.9,
            exposure: 0.6,
            noise: 0.1,
            isPortrait: true,
            isHDR: false
        )
        
        let trainingEvent = PersonalizationEvent(
            features: trainingFeatures,
            feedback: .positive,
            lens: .wide,
            timestamp: Date()
        )
        
        // Train with multiple positive examples
        for _ in 0..<20 {
            engine.update(with: trainingEvent)
        }
        
        // Test bias application on similar image
        let testFeatures = PersonalizationFeatures(
            sharpness: 0.8,
            exposure: 0.6,
            noise: 0.2,
            isPortrait: true,
            isHDR: false
        )
        
        let baseScore: Float = 0.6
        let biasedScore = engine.applyBias(
            baseScore: baseScore,
            features: testFeatures,
            lens: .wide
        )
        
        // Should boost score for preferred characteristics
        XCTAssertGreaterThan(biasedScore, baseScore)
        XCTAssertLessThanOrEqual(biasedScore, 1.0) // Should not exceed maximum
    }
    
    func testBiasApplicationWithDislikedCharacteristics() {
        // Train the engine to dislike blurry, noisy images
        let trainingFeatures = PersonalizationFeatures(
            sharpness: 0.2,
            exposure: 0.3,
            noise: 0.9,
            isPortrait: false,
            isHDR: false
        )
        
        let trainingEvent = PersonalizationEvent(
            features: trainingFeatures,
            feedback: .negative,
            lens: .ultraWide,
            timestamp: Date()
        )
        
        // Train with multiple negative examples
        for _ in 0..<20 {
            engine.update(with: trainingEvent)
        }
        
        // Test bias application on similar image
        let testFeatures = PersonalizationFeatures(
            sharpness: 0.3,
            exposure: 0.4,
            noise: 0.8,
            isPortrait: false,
            isHDR: false
        )
        
        let baseScore: Float = 0.7
        let biasedScore = engine.applyBias(
            baseScore: baseScore,
            features: testFeatures,
            lens: .ultraWide
        )
        
        // Should reduce score for disliked characteristics
        XCTAssertLessThan(biasedScore, baseScore)
        XCTAssertGreaterThanOrEqual(biasedScore, 0.0) // Should not go below minimum
    }
    
    func testBiasClampingLimits() {
        // Create extreme profile values
        engine.updatePreference(\.sharpnessBias, value: 1.0) // Maximum positive
        engine.updatePreference(\.exposureBias, value: 1.0)
        engine.updatePreference(\.noiseTolerance, value: -1.0) // Maximum negative
        
        // Test with features that would create large bias
        let extremeFeatures = PersonalizationFeatures(
            sharpness: 1.0,
            exposure: 1.0,
            noise: 0.0,
            isPortrait: false,
            isHDR: false
        )
        
        let baseScore: Float = 0.5
        let biasedScore = engine.applyBias(
            baseScore: baseScore,
            features: extremeFeatures,
            lens: .wide
        )
        
        // Bias should be clamped to reasonable limits
        let maxExpectedBias: Float = 0.15 // As defined in PersonalizationEngine
        XCTAssertLessThanOrEqual(biasedScore - baseScore, maxExpectedBias)
        XCTAssertLessThanOrEqual(biasedScore, 1.0)
        XCTAssertGreaterThanOrEqual(biasedScore, 0.0)
    }
    
    // MARK: - Statistics Tests
    
    func testStatisticsCalculation() {
        // Train with some preferences
        let features = PersonalizationFeatures(
            sharpness: 0.8,
            exposure: 0.6,
            noise: 0.2,
            isPortrait: true,
            isHDR: false
        )
        
        let event = PersonalizationEvent(
            features: features,
            feedback: .positive,
            lens: .wide,
            timestamp: Date()
        )
        
        // Apply multiple events
        for _ in 0..<15 {
            engine.update(with: event)
        }
        
        let stats = engine.getStatistics()
        
        XCTAssertEqual(stats.totalFeedback, 15)
        XCTAssertFalse(stats.isNeutral)
        XCTAssertGreaterThan(stats.preferenceStrength, 0.0)
        XCTAssertLessThanOrEqual(stats.preferenceStrength, 1.0)
        XCTAssertFalse(stats.summary.isEmpty)
    }
    
    func testStatisticsWithNeutralProfile() {
        let stats = engine.getStatistics()
        
        XCTAssertEqual(stats.totalFeedback, 0)
        XCTAssertTrue(stats.isNeutral)
        XCTAssertEqual(stats.preferenceStrength, 0.0, accuracy: 0.001)
        XCTAssertTrue(stats.summary.contains("neutral") || stats.summary.contains("learning"))
    }
    
    // MARK: - Edge Cases Tests
    
    func testDisabledPersonalizationDoesNotApplyBias() {
        // Train the engine first
        let features = PersonalizationFeatures(
            sharpness: 0.9,
            exposure: 0.7,
            noise: 0.1,
            isPortrait: true,
            isHDR: false
        )
        
        let event = PersonalizationEvent(
            features: features,
            feedback: .positive,
            lens: .wide,
            timestamp: Date()
        )
        
        for _ in 0..<10 {
            engine.update(with: event)
        }
        
        // Disable personalization
        engine.setEnabled(false)
        
        // Test bias application
        let baseScore: Float = 0.6
        let biasedScore = engine.applyBias(
            baseScore: baseScore,
            features: features,
            lens: .wide
        )
        
        // Should not apply bias when disabled
        XCTAssertEqual(biasedScore, baseScore, accuracy: 0.001)
    }
    
    func testExtremeScoreValues() {
        // Test with minimum score
        let minScore = engine.applyBias(
            baseScore: 0.0,
            features: PersonalizationFeatures(
                sharpness: 0.5,
                exposure: 0.5,
                noise: 0.5,
                isPortrait: false,
                isHDR: false
            ),
            lens: .wide
        )
        XCTAssertGreaterThanOrEqual(minScore, 0.0)
        
        // Test with maximum score
        let maxScore = engine.applyBias(
            baseScore: 1.0,
            features: PersonalizationFeatures(
                sharpness: 0.5,
                exposure: 0.5,
                noise: 0.5,
                isPortrait: false,
                isHDR: false
            ),
            lens: .wide
        )
        XCTAssertLessThanOrEqual(maxScore, 1.0)
    }
    
    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        
        let features = PersonalizationFeatures(
            sharpness: 0.7,
            exposure: 0.6,
            noise: 0.3,
            isPortrait: false,
            isHDR: false
        )
        
        let event = PersonalizationEvent(
            features: features,
            feedback: .positive,
            lens: .wide,
            timestamp: Date()
        )
        
        // Simulate concurrent access from multiple threads
        for i in 0..<10 {
            DispatchQueue.global(qos: .background).async {
                self.engine.update(with: event)
                
                let biasedScore = self.engine.applyBias(
                    baseScore: 0.5,
                    features: features,
                    lens: .wide
                )
                
                XCTAssertGreaterThanOrEqual(biasedScore, 0.0)
                XCTAssertLessThanOrEqual(biasedScore, 1.0)
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Mock PersonalizationStore

class MockPersonalizationStore: PersonalizationStore {
    var saveProfileCalled = false
    var loadProfileCalled = false
    var storedProfile: PersonalizationProfile?
    
    func saveProfile(_ profile: PersonalizationProfile) {
        saveProfileCalled = true
        storedProfile = profile
    }
    
    func loadProfile() -> PersonalizationProfile? {
        loadProfileCalled = true
        return storedProfile
    }
}

