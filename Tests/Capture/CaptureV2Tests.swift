//
//  CaptureV2Tests.swift
//  PhotoStopTests
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import XCTest
import AVFoundation
@testable import PhotoStop

final class CaptureV2Tests: XCTestCase {
    
    var cameraService: CameraService!
    var frameScoringService: FrameScoringService!
    var mockCameraLensService: MockCameraLensService!
    var mockDepthService: MockDepthService!
    
    override func setUp() {
        super.setUp()
        mockCameraLensService = MockCameraLensService()
        mockDepthService = MockDepthService()
        cameraService = CameraService()
        frameScoringService = FrameScoringService.shared
    }
    
    override func tearDown() {
        cameraService = nil
        frameScoringService = nil
        mockCameraLensService = nil
        mockDepthService = nil
        super.tearDown()
    }
    
    // MARK: - FrameMetadata Tests
    
    func testFrameMetadataCreation() {
        let metadata = FrameMetadata(
            lens: .wide,
            iso: 800,
            shutterMS: 16.0,
            aperture: 2.8,
            meanLuma: 0.6,
            motionScore: 0.3,
            hasDepth: true,
            depthQuality: 0.8,
            timestamp: Date(),
            isLowLight: false,
            hasMotionBlur: false,
            isPortraitSuitable: true
        )
        
        XCTAssertEqual(metadata.lens, .wide)
        XCTAssertEqual(metadata.iso, 800)
        XCTAssertEqual(metadata.shutterMS, 16.0, accuracy: 0.1)
        XCTAssertEqual(metadata.aperture, 2.8, accuracy: 0.1)
        XCTAssertEqual(metadata.meanLuma, 0.6, accuracy: 0.01)
        XCTAssertEqual(metadata.motionScore, 0.3, accuracy: 0.01)
        XCTAssertTrue(metadata.hasDepth)
        XCTAssertEqual(metadata.depthQuality, 0.8, accuracy: 0.01)
        XCTAssertFalse(metadata.isLowLight)
        XCTAssertFalse(metadata.hasMotionBlur)
        XCTAssertTrue(metadata.isPortraitSuitable)
    }
    
    func testFrameMetadataLensDisplayNames() {
        XCTAssertEqual(FrameMetadata.Lens.ultraWide.displayName, "Ultra Wide")
        XCTAssertEqual(FrameMetadata.Lens.wide.displayName, "Wide")
        XCTAssertEqual(FrameMetadata.Lens.telephoto.displayName, "Telephoto")
    }
    
    func testFrameMetadataQualityAssessment() {
        // High quality metadata
        let highQuality = FrameMetadata(
            lens: .wide,
            iso: 200,
            shutterMS: 8.0,
            aperture: 2.8,
            meanLuma: 0.5,
            motionScore: 0.1,
            hasDepth: true,
            depthQuality: 0.9,
            timestamp: Date(),
            isLowLight: false,
            hasMotionBlur: false,
            isPortraitSuitable: true
        )
        
        XCTAssertFalse(highQuality.isLowLight)
        XCTAssertFalse(highQuality.hasMotionBlur)
        XCTAssertLessThan(highQuality.motionScore, 0.3)
        XCTAssertLessThan(highQuality.iso, 400)
        
        // Low quality metadata
        let lowQuality = FrameMetadata(
            lens: .ultraWide,
            iso: 3200,
            shutterMS: 33.0,
            aperture: 4.0,
            meanLuma: 0.1,
            motionScore: 0.8,
            hasDepth: false,
            depthQuality: 0.0,
            timestamp: Date(),
            isLowLight: true,
            hasMotionBlur: true,
            isPortraitSuitable: false
        )
        
        XCTAssertTrue(lowQuality.isLowLight)
        XCTAssertTrue(lowQuality.hasMotionBlur)
        XCTAssertGreaterThan(lowQuality.motionScore, 0.5)
        XCTAssertGreaterThan(lowQuality.iso, 1600)
    }
    
    // MARK: - FrameBundle Tests
    
    func testFrameBundleCreation() {
        let testImage = createTestImage()
        let metadata = createTestMetadata()
        
        let item = FrameBundle.Item(
            image: testImage,
            metadata: metadata,
            qualityScore: 0.7
        )
        
        let sceneHints = SceneHints(
            sceneType: .portrait,
            lightingCondition: .natural,
            subjectCount: 1,
            hasMotion: false,
            confidence: 0.8
        )
        
        let bundle = FrameBundle(
            items: [item],
            sceneHints: sceneHints,
            captureMode: .single
        )
        
        XCTAssertEqual(bundle.frameCount, 1)
        XCTAssertEqual(bundle.sceneHints.sceneType, .portrait)
        XCTAssertEqual(bundle.captureMode, .single)
        XCTAssertNil(bundle.bestItem) // Not selected yet
        XCTAssertFalse(bundle.hasSelection)
    }
    
    func testFrameBundleMultipleFrames() {
        let testImages = [createTestImage(), createTestImage(), createTestImage()]
        let items = testImages.map { image in
            FrameBundle.Item(
                image: image,
                metadata: createTestMetadata(),
                qualityScore: Float.random(in: 0.3...0.9)
            )
        }
        
        let sceneHints = SceneHints(
            sceneType: .landscape,
            lightingCondition: .golden,
            subjectCount: 0,
            hasMotion: false,
            confidence: 0.9
        )
        
        let bundle = FrameBundle(
            items: items,
            sceneHints: sceneHints,
            captureMode: .burst
        )
        
        XCTAssertEqual(bundle.frameCount, 3)
        XCTAssertEqual(bundle.captureMode, .burst)
        XCTAssertFalse(bundle.hasSelection)
    }
    
    func testFrameBundleScoring() {
        let scores: [Float] = [0.6, 0.8, 0.4, 0.9, 0.5]
        let items = scores.map { score in
            FrameBundle.Item(
                image: createTestImage(),
                metadata: createTestMetadata(),
                qualityScore: score
            )
        }
        
        var bundle = FrameBundle(
            items: items,
            sceneHints: createTestSceneHints(),
            captureMode: .burst
        )
        
        // Update scores
        bundle.updateQualityScores(scores)
        
        // Select best item
        bundle.selectBestItem()
        
        XCTAssertTrue(bundle.hasSelection)
        XCTAssertEqual(bundle.bestItem?.qualityScore, 0.9, accuracy: 0.01)
        XCTAssertEqual(bundle.bestItemIndex, 3)
    }
    
    func testFrameBundleSceneAnalysis() {
        let portraitHints = SceneHints(
            sceneType: .portrait,
            lightingCondition: .natural,
            subjectCount: 1,
            hasMotion: false,
            confidence: 0.85
        )
        
        XCTAssertEqual(portraitHints.sceneType, .portrait)
        XCTAssertEqual(portraitHints.lightingCondition, .natural)
        XCTAssertEqual(portraitHints.subjectCount, 1)
        XCTAssertFalse(portraitHints.hasMotion)
        XCTAssertEqual(portraitHints.confidence, 0.85, accuracy: 0.01)
        
        let actionHints = SceneHints(
            sceneType: .action,
            lightingCondition: .artificial,
            subjectCount: 2,
            hasMotion: true,
            confidence: 0.7
        )
        
        XCTAssertEqual(actionHints.sceneType, .action)
        XCTAssertTrue(actionHints.hasMotion)
        XCTAssertEqual(actionHints.subjectCount, 2)
    }
    
    // MARK: - CameraLensService Tests
    
    func testCameraLensDiscovery() {
        let lensService = CameraLensService()
        
        // Test available lenses (will vary by device)
        let availableLenses = lensService.getAvailableLenses()
        XCTAssertFalse(availableLenses.isEmpty)
        
        // Wide lens should always be available
        XCTAssertTrue(availableLenses.contains(.wide))
        
        // Test device capabilities
        let capabilities = lensService.getDeviceCapabilities()
        XCTAssertNotNil(capabilities)
        XCTAssertTrue(capabilities.supportsMultiLens || capabilities.supportsSingleLens)
    }
    
    func testCameraLensConfiguration() {
        let lensService = CameraLensService()
        
        // Test lens configuration for different scenarios
        let portraitConfig = lensService.getOptimalConfiguration(for: .portrait)
        XCTAssertTrue(portraitConfig.preferredLenses.contains(.wide) || portraitConfig.preferredLenses.contains(.telephoto))
        XCTAssertTrue(portraitConfig.enableDepth)
        
        let landscapeConfig = lensService.getOptimalConfiguration(for: .landscape)
        XCTAssertTrue(landscapeConfig.preferredLenses.contains(.wide) || landscapeConfig.preferredLenses.contains(.ultraWide))
        
        let macroConfig = lensService.getOptimalConfiguration(for: .macro)
        XCTAssertTrue(macroConfig.preferredLenses.contains(.wide))
        XCTAssertTrue(macroConfig.enableStabilization)
    }
    
    // MARK: - DepthService Tests
    
    func testDepthDataProcessing() {
        let depthService = DepthService()
        
        // Test depth quality assessment
        let highQualityDepth = depthService.assessDepthQuality(
            disparityRange: 0.8,
            accuracy: 0.9,
            completeness: 0.85
        )
        XCTAssertGreaterThan(highQualityDepth, 0.7)
        
        let lowQualityDepth = depthService.assessDepthQuality(
            disparityRange: 0.3,
            accuracy: 0.5,
            completeness: 0.4
        )
        XCTAssertLessThan(lowQualityDepth, 0.5)
    }
    
    func testPortraitEffectGeneration() {
        let depthService = DepthService()
        let testImage = createTestImage()
        
        // Test portrait effect parameters
        let params = PortraitEffectParams(
            blurStrength: 0.7,
            focusPoint: CGPoint(x: 0.5, y: 0.4),
            subjectMask: nil,
            preserveEdges: true
        )
        
        XCTAssertEqual(params.blurStrength, 0.7, accuracy: 0.01)
        XCTAssertEqual(params.focusPoint.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(params.focusPoint.y, 0.4, accuracy: 0.01)
        XCTAssertTrue(params.preserveEdges)
    }
    
    // MARK: - Frame Scoring Integration Tests
    
    func testFrameScoringWithPersonalization() async throws {
        let testImage = createTestImage()
        let metadata = createTestMetadata()
        
        let item = FrameBundle.Item(
            image: testImage,
            metadata: metadata,
            qualityScore: 0.0 // Will be calculated
        )
        
        let sceneHints = createTestSceneHints()
        
        // Test scoring
        let score = try await frameScoringService.scoreFrame(item, sceneHints: sceneHints)
        
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }
    
    func testFrameBundleScoring() async throws {
        let items = (0..<5).map { _ in
            FrameBundle.Item(
                image: createTestImage(),
                metadata: createTestMetadata(),
                qualityScore: 0.0
            )
        }
        
        let bundle = FrameBundle(
            items: items,
            sceneHints: createTestSceneHints(),
            captureMode: .burst
        )
        
        let scoredBundle = try await frameScoringService.scoreFrameBundle(bundle)
        
        XCTAssertEqual(scoredBundle.frameCount, 5)
        XCTAssertTrue(scoredBundle.hasSelection)
        XCTAssertNotNil(scoredBundle.bestItem)
        
        // All items should have scores
        for item in scoredBundle.items {
            XCTAssertGreaterThan(item.qualityScore, 0.0)
            XCTAssertLessThanOrEqual(item.qualityScore, 1.0)
        }
    }
    
    func testScoringExplanation() async {
        let testImage = createTestImage()
        let metadata = createTestMetadata()
        
        let item = FrameBundle.Item(
            image: testImage,
            metadata: metadata,
            qualityScore: 0.7
        )
        
        let sceneHints = createTestSceneHints()
        
        let explanation = await frameScoringService.getScoringExplanation(
            for: item,
            sceneHints: sceneHints
        )
        
        XCTAssertGreaterThanOrEqual(explanation.technicalScore, 0.0)
        XCTAssertLessThanOrEqual(explanation.technicalScore, 1.0)
        XCTAssertGreaterThanOrEqual(explanation.aestheticScore, 0.0)
        XCTAssertLessThanOrEqual(explanation.aestheticScore, 1.0)
        XCTAssertGreaterThanOrEqual(explanation.contextualScore, 0.0)
        XCTAssertLessThanOrEqual(explanation.contextualScore, 1.0)
        XCTAssertGreaterThanOrEqual(explanation.overallScore, 0.0)
        XCTAssertLessThanOrEqual(explanation.overallScore, 1.0)
        
        XCTAssertFalse(explanation.summary.isEmpty)
        XCTAssertFalse(explanation.detailedBreakdown.isEmpty)
        XCTAssertFalse(explanation.factors.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testFrameScoringPerformance() async throws {
        let items = (0..<10).map { _ in
            FrameBundle.Item(
                image: createTestImage(),
                metadata: createTestMetadata(),
                qualityScore: 0.0
            )
        }
        
        let bundle = FrameBundle(
            items: items,
            sceneHints: createTestSceneHints(),
            captureMode: .burst
        )
        
        measure {
            Task {
                _ = try await frameScoringService.scoreFrameBundle(bundle)
            }
        }
    }
    
    func testPersonalizationFeatureExtraction() {
        let metadata = createTestMetadata()
        let testImage = createTestImage()
        
        let item = FrameBundle.Item(
            image: testImage,
            metadata: metadata,
            qualityScore: 0.7
        )
        
        let features = PersonalizationFeatures.from(item: item)
        
        XCTAssertGreaterThanOrEqual(features.sharpness, 0.0)
        XCTAssertLessThanOrEqual(features.sharpness, 1.0)
        XCTAssertGreaterThanOrEqual(features.exposure, 0.0)
        XCTAssertLessThanOrEqual(features.exposure, 1.0)
        XCTAssertGreaterThanOrEqual(features.noise, 0.0)
        XCTAssertLessThanOrEqual(features.noise, 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    private func createTestMetadata() -> FrameMetadata {
        return FrameMetadata(
            lens: .wide,
            iso: 400,
            shutterMS: 16.0,
            aperture: 2.8,
            meanLuma: 0.5,
            motionScore: 0.3,
            hasDepth: false,
            depthQuality: 0.0,
            timestamp: Date(),
            isLowLight: false,
            hasMotionBlur: false,
            isPortraitSuitable: false
        )
    }
    
    private func createTestSceneHints() -> SceneHints {
        return SceneHints(
            sceneType: .general,
            lightingCondition: .natural,
            subjectCount: 1,
            hasMotion: false,
            confidence: 0.7
        )
    }
}

// MARK: - Mock Services

class MockCameraLensService {
    func getAvailableLenses() -> [FrameMetadata.Lens] {
        return [.ultraWide, .wide, .telephoto]
    }
    
    func getDeviceCapabilities() -> DeviceCapabilities {
        return DeviceCapabilities(
            supportsMultiLens: true,
            supportsSingleLens: true,
            supportsDepth: true,
            supportsBurst: true,
            maxBurstCount: 10
        )
    }
}

class MockDepthService {
    func assessDepthQuality(disparityRange: Float, accuracy: Float, completeness: Float) -> Float {
        return (disparityRange + accuracy + completeness) / 3.0
    }
}

struct DeviceCapabilities {
    let supportsMultiLens: Bool
    let supportsSingleLens: Bool
    let supportsDepth: Bool
    let supportsBurst: Bool
    let maxBurstCount: Int
}

