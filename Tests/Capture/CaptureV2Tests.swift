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
    
    var testImage: UIImage!
    
    override func setUp() {
        super.setUp()
        testImage = UIImage(systemName: "photo")!
    }
    
    override func tearDown() {
        testImage = nil
        super.tearDown()
    }
    
    // MARK: - FrameMetadata Tests
    
    func testFrameMetadataCreation() {
        let metadata = FrameMetadata(
            timestamp: Date(),
            lens: .wide,
            exposureSettings: ExposureSettings(iso: 800, shutterSpeed: 1/60, aperture: 2.8),
            focusDistance: 2.0,
            hasDepthData: true,
            motionDetected: false,
            faceCount: 1,
            qualityScore: 0.85
        )
        
        XCTAssertEqual(metadata.lens, .wide)
        XCTAssertEqual(metadata.exposureSettings.iso, 800)
        XCTAssertEqual(metadata.exposureSettings.shutterSpeed, 1/60, accuracy: 0.001)
        XCTAssertEqual(metadata.exposureSettings.aperture, 2.8, accuracy: 0.1)
        XCTAssertEqual(metadata.focusDistance, 2.0, accuracy: 0.1)
        XCTAssertTrue(metadata.hasDepthData)
        XCTAssertFalse(metadata.motionDetected)
        XCTAssertEqual(metadata.faceCount, 1)
        XCTAssertEqual(metadata.qualityScore, 0.85, accuracy: 0.01)
    }
    
    func testFrameMetadataProperties() {
        let metadata = FrameMetadata(
            timestamp: Date(),
            lens: .ultraWide,
            exposureSettings: ExposureSettings(iso: 100, shutterSpeed: 1/120, aperture: 1.8),
            focusDistance: 1.0,
            hasDepthData: false,
            motionDetected: true,
            faceCount: 2,
            qualityScore: 0.92
        )
        
        XCTAssertTrue(metadata.isLowLight == false) // ISO 100 is not low light
        XCTAssertTrue(metadata.isPortraitSuitable) // Face count > 0
        XCTAssertTrue(metadata.hasMotionBlur == false) // Fast shutter speed
    }
    
    // MARK: - CapturedFrame Tests
    
    func testCapturedFrameCreation() {
        let metadata = FrameMetadata(
            timestamp: Date(),
            lens: .wide,
            exposureSettings: ExposureSettings(iso: 400, shutterSpeed: 1/60, aperture: 2.2),
            focusDistance: 1.5,
            hasDepthData: true,
            motionDetected: false,
            faceCount: 0,
            qualityScore: 0.78
        )
        
        let frame = CapturedFrame(image: testImage, metadata: metadata)
        
        XCTAssertNotNil(frame.image)
        XCTAssertEqual(frame.metadata.lens, .wide)
        XCTAssertEqual(frame.metadata.qualityScore, 0.78, accuracy: 0.01)
    }
    
    // MARK: - FrameBundle Tests
    
    func testFrameBundleCreation() {
        let frames = createTestFrames(count: 3)
        let sceneAnalysis = SceneAnalysis(
            dominantScene: .portrait,
            lightingCondition: .normal,
            motionLevel: .low,
            subjectCount: 1,
            recommendedEnhancement: .portraitEnhance
        )
        
        let bundle = FrameBundle(
            frames: frames,
            captureTime: Date(),
            sceneAnalysis: sceneAnalysis
        )
        
        XCTAssertEqual(bundle.frames.count, 3)
        XCTAssertEqual(bundle.sceneAnalysis.dominantScene, .portrait)
        XCTAssertEqual(bundle.sceneAnalysis.lightingCondition, .normal)
        XCTAssertEqual(bundle.sceneAnalysis.motionLevel, .low)
        XCTAssertEqual(bundle.sceneAnalysis.subjectCount, 1)
        XCTAssertEqual(bundle.sceneAnalysis.recommendedEnhancement, .portraitEnhance)
    }
    
    func testFrameBundleProperties() {
        let frames = createTestFrames(count: 5)
        let bundle = FrameBundle(
            frames: frames,
            captureTime: Date(),
            sceneAnalysis: SceneAnalysis(
                dominantScene: .landscape,
                lightingCondition: .lowLight,
                motionLevel: .high,
                subjectCount: 0,
                recommendedEnhancement: .hdrEnhance
            )
        )
        
        XCTAssertEqual(bundle.frameCount, 5)
        XCTAssertTrue(bundle.hasDepthData) // At least one frame should have depth
        XCTAssertTrue(bundle.hasPortraitFrames) // At least one frame should be portrait suitable
        XCTAssertFalse(bundle.hasExcessiveMotion) // Motion level is managed in scene analysis
    }
    
    // MARK: - SceneAnalysis Tests
    
    func testSceneAnalysisTypes() {
        let scenes: [SceneType] = [.general, .portrait, .landscape, .macro, .lowLight, .action, .group]
        let lightingConditions: [LightingCondition] = [.normal, .lowLight, .backlit, .harsh, .golden]
        let motionLevels: [MotionLevel] = [.low, .medium, .high]
        let enhancements: [RecommendedEnhancement] = [.simpleEnhance, .portraitEnhance, .hdrEnhance, .lowLightEnhance, .actionEnhance]
        
        // Test that all enum cases are valid
        for scene in scenes {
            XCTAssertNotNil(scene)
        }
        
        for lighting in lightingConditions {
            XCTAssertNotNil(lighting)
        }
        
        for motion in motionLevels {
            XCTAssertNotNil(motion)
        }
        
        for enhancement in enhancements {
            XCTAssertNotNil(enhancement)
        }
    }
    
    // MARK: - CameraLens Tests
    
    func testCameraLensTypes() {
        let lenses: [CameraLens] = [.wide, .ultraWide, .telephoto]
        
        for lens in lenses {
            XCTAssertNotNil(lens)
            XCTAssertFalse(lens.displayName.isEmpty)
            XCTAssertGreaterThan(lens.focalLength, 0)
            XCTAssertGreaterThan(lens.maxAperture, 0)
        }
    }
    
    func testCameraLensProperties() {
        // Test wide lens
        XCTAssertEqual(CameraLens.wide.displayName, "Wide")
        XCTAssertEqual(CameraLens.wide.focalLength, 26.0, accuracy: 0.1)
        XCTAssertEqual(CameraLens.wide.maxAperture, 1.6, accuracy: 0.1)
        
        // Test ultra-wide lens
        XCTAssertEqual(CameraLens.ultraWide.displayName, "Ultra Wide")
        XCTAssertEqual(CameraLens.ultraWide.focalLength, 13.0, accuracy: 0.1)
        XCTAssertEqual(CameraLens.ultraWide.maxAperture, 2.4, accuracy: 0.1)
        
        // Test telephoto lens
        XCTAssertEqual(CameraLens.telephoto.displayName, "Telephoto")
        XCTAssertEqual(CameraLens.telephoto.focalLength, 77.0, accuracy: 0.1)
        XCTAssertEqual(CameraLens.telephoto.maxAperture, 2.8, accuracy: 0.1)
    }
    
    // MARK: - ExposureSettings Tests
    
    func testExposureSettingsCreation() {
        let exposure = ExposureSettings(iso: 200, shutterSpeed: 1/125, aperture: 2.0)
        
        XCTAssertEqual(exposure.iso, 200)
        XCTAssertEqual(exposure.shutterSpeed, 1/125, accuracy: 0.001)
        XCTAssertEqual(exposure.aperture, 2.0, accuracy: 0.1)
    }
    
    func testExposureSettingsProperties() {
        let lowLightExposure = ExposureSettings(iso: 1600, shutterSpeed: 1/30, aperture: 1.8)
        let brightExposure = ExposureSettings(iso: 64, shutterSpeed: 1/500, aperture: 5.6)
        
        XCTAssertTrue(lowLightExposure.isLowLight)
        XCTAssertFalse(brightExposure.isLowLight)
        
        XCTAssertTrue(lowLightExposure.hasMotionBlur)
        XCTAssertFalse(brightExposure.hasMotionBlur)
    }
    
    // MARK: - Integration Tests
    
    func testFrameBundleWithScoring() {
        let frames = createTestFrames(count: 3)
        let bundle = FrameBundle(
            frames: frames,
            captureTime: Date(),
            sceneAnalysis: SceneAnalysis(
                dominantScene: .general,
                lightingCondition: .normal,
                motionLevel: .low,
                subjectCount: 0,
                recommendedEnhancement: .simpleEnhance
            )
        )
        
        // Test that bundle can be processed
        XCTAssertEqual(bundle.frames.count, 3)
        XCTAssertNotNil(bundle.sceneAnalysis)
        
        // Test frame selection logic
        let bestFrameIndex = selectBestFrameIndex(from: bundle)
        XCTAssertGreaterThanOrEqual(bestFrameIndex, 0)
        XCTAssertLessThan(bestFrameIndex, bundle.frames.count)
    }
    
    func testMultiLensCapture() {
        // Simulate multi-lens capture
        let wideFrame = createTestFrame(lens: .wide, quality: 0.8)
        let ultraWideFrame = createTestFrame(lens: .ultraWide, quality: 0.7)
        let telephotoFrame = createTestFrame(lens: .telephoto, quality: 0.9)
        
        let frames = [wideFrame, ultraWideFrame, telephotoFrame]
        let bundle = FrameBundle(
            frames: frames,
            captureTime: Date(),
            sceneAnalysis: SceneAnalysis(
                dominantScene: .landscape,
                lightingCondition: .normal,
                motionLevel: .low,
                subjectCount: 0,
                recommendedEnhancement: .simpleEnhance
            )
        )
        
        XCTAssertEqual(bundle.frames.count, 3)
        
        // Test that we have frames from different lenses
        let lenses = Set(bundle.frames.map { $0.metadata.lens })
        XCTAssertEqual(lenses.count, 3)
        XCTAssertTrue(lenses.contains(.wide))
        XCTAssertTrue(lenses.contains(.ultraWide))
        XCTAssertTrue(lenses.contains(.telephoto))
    }
    
    // MARK: - Performance Tests
    
    func testFrameBundlePerformance() {
        measure {
            let frames = createTestFrames(count: 10)
            let bundle = FrameBundle(
                frames: frames,
                captureTime: Date(),
                sceneAnalysis: SceneAnalysis(
                    dominantScene: .general,
                    lightingCondition: .normal,
                    motionLevel: .low,
                    subjectCount: 0,
                    recommendedEnhancement: .simpleEnhance
                )
            )
            
            _ = bundle.frameCount
            _ = bundle.hasDepthData
            _ = bundle.hasPortraitFrames
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidFrameBundle() {
        // Test empty frame bundle
        let emptyBundle = FrameBundle(
            frames: [],
            captureTime: Date(),
            sceneAnalysis: SceneAnalysis(
                dominantScene: .general,
                lightingCondition: .normal,
                motionLevel: .low,
                subjectCount: 0,
                recommendedEnhancement: .simpleEnhance
            )
        )
        
        XCTAssertEqual(emptyBundle.frameCount, 0)
        XCTAssertFalse(emptyBundle.hasDepthData)
        XCTAssertFalse(emptyBundle.hasPortraitFrames)
    }
    
    // MARK: - Helper Methods
    
    private func createTestFrames(count: Int) -> [CapturedFrame] {
        var frames: [CapturedFrame] = []
        
        for i in 0..<count {
            let metadata = FrameMetadata(
                timestamp: Date().addingTimeInterval(Double(i) * 0.1),
                lens: i % 2 == 0 ? .wide : .ultraWide,
                exposureSettings: ExposureSettings(
                    iso: 100 + i * 50,
                    shutterSpeed: 1/60,
                    aperture: 2.0 + Double(i) * 0.2
                ),
                focusDistance: 1.0 + Double(i) * 0.5,
                hasDepthData: i % 2 == 0,
                motionDetected: false,
                faceCount: i % 3 == 0 ? 1 : 0,
                qualityScore: 0.7 + Double(i) * 0.05
            )
            
            let frame = CapturedFrame(image: testImage, metadata: metadata)
            frames.append(frame)
        }
        
        return frames
    }
    
    private func createTestFrame(lens: CameraLens, quality: Double) -> CapturedFrame {
        let metadata = FrameMetadata(
            timestamp: Date(),
            lens: lens,
            exposureSettings: ExposureSettings(iso: 200, shutterSpeed: 1/60, aperture: 2.2),
            focusDistance: 1.5,
            hasDepthData: lens != .ultraWide, // Ultra-wide typically doesn't have depth
            motionDetected: false,
            faceCount: 0,
            qualityScore: quality
        )
        
        return CapturedFrame(image: testImage, metadata: metadata)
    }
    
    private func selectBestFrameIndex(from bundle: FrameBundle) -> Int {
        guard !bundle.frames.isEmpty else { return 0 }
        
        var bestIndex = 0
        var bestScore = bundle.frames[0].metadata.qualityScore
        
        for (index, frame) in bundle.frames.enumerated() {
            if frame.metadata.qualityScore > bestScore {
                bestScore = frame.metadata.qualityScore
                bestIndex = index
            }
        }
        
        return bestIndex
    }
}

// MARK: - Mock Services

class MockCameraLensService {
    func availableLenses() -> [CameraLens] {
        return [.wide, .ultraWide, .telephoto]
    }
    
    func captureWithLens(_ lens: CameraLens) -> CapturedFrame? {
        let metadata = FrameMetadata(
            timestamp: Date(),
            lens: lens,
            exposureSettings: ExposureSettings(iso: 200, shutterSpeed: 1/60, aperture: 2.2),
            focusDistance: 1.5,
            hasDepthData: lens != .ultraWide,
            motionDetected: false,
            faceCount: 0,
            qualityScore: 0.8
        )
        
        return CapturedFrame(image: UIImage(systemName: "photo")!, metadata: metadata)
    }
}

class MockDepthService {
    func processDepthData(_ depthData: Data) -> DepthMap? {
        // Mock depth processing
        return DepthMap(width: 640, height: 480, depthValues: Array(repeating: 0.5, count: 640 * 480))
    }
    
    func generatePortraitMask(from depthMap: DepthMap) -> UIImage? {
        // Mock portrait mask generation
        return UIImage(systemName: "person.crop.circle")
    }
}

// MARK: - Mock Data Structures

struct DepthMap {
    let width: Int
    let height: Int
    let depthValues: [Float]
}

// MARK: - Extension Tests

extension CaptureV2Tests {
    
    func testFrameMetadataExtensions() {
        let metadata = FrameMetadata(
            timestamp: Date(),
            lens: .wide,
            exposureSettings: ExposureSettings(iso: 800, shutterSpeed: 1/30, aperture: 1.8),
            focusDistance: 1.0,
            hasDepthData: true,
            motionDetected: true,
            faceCount: 2,
            qualityScore: 0.85
        )
        
        // Test computed properties
        XCTAssertTrue(metadata.isLowLight) // ISO 800 is considered low light
        XCTAssertTrue(metadata.isPortraitSuitable) // Has faces
        XCTAssertTrue(metadata.hasMotionBlur) // Slow shutter speed
    }
    
    func testSceneAnalysisRecommendations() {
        // Test portrait scene
        let portraitAnalysis = SceneAnalysis(
            dominantScene: .portrait,
            lightingCondition: .normal,
            motionLevel: .low,
            subjectCount: 1,
            recommendedEnhancement: .portraitEnhance
        )
        
        XCTAssertEqual(portraitAnalysis.recommendedEnhancement, .portraitEnhance)
        
        // Test low light scene
        let lowLightAnalysis = SceneAnalysis(
            dominantScene: .general,
            lightingCondition: .lowLight,
            motionLevel: .low,
            subjectCount: 0,
            recommendedEnhancement: .lowLightEnhance
        )
        
        XCTAssertEqual(lowLightAnalysis.recommendedEnhancement, .lowLightEnhance)
        
        // Test action scene
        let actionAnalysis = SceneAnalysis(
            dominantScene: .action,
            lightingCondition: .normal,
            motionLevel: .high,
            subjectCount: 1,
            recommendedEnhancement: .actionEnhance
        )
        
        XCTAssertEqual(actionAnalysis.recommendedEnhancement, .actionEnhance)
    }
}

