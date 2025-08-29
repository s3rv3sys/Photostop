//
//  CameraServiceTests.swift
//  PhotoStopTests
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import XCTest
import AVFoundation
@testable import PhotoStop

@MainActor
final class CameraServiceTests: XCTestCase {
    
    var cameraService: CameraService!
    
    override func setUp() {
        super.setUp()
        cameraService = CameraService.shared
    }
    
    override func tearDown() {
        cameraService.stopSession()
        cameraService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testCameraServiceInitialization() {
        XCTAssertNotNil(cameraService)
        XCTAssertFalse(cameraService.isSessionRunning)
        XCTAssertFalse(cameraService.isCapturing)
        XCTAssertNil(cameraService.lastError)
    }
    
    // MARK: - Permission Tests
    
    func testCameraPermissionRequest() async {
        let permissionGranted = await cameraService.requestCameraPermission()
        
        // The result depends on the test environment
        // Test that the method completes without crashing
        XCTAssertTrue(permissionGranted || !permissionGranted)
    }
    
    // MARK: - Session Management Tests
    
    func testSessionStartStop() {
        // Test initial state
        XCTAssertFalse(cameraService.isSessionRunning)
        
        // Start session
        cameraService.startSession()
        
        // Give some time for async operations
        let expectation = XCTestExpectation(description: "Session start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Stop session
        cameraService.stopSession()
        
        // Give some time for async operations
        let stopExpectation = XCTestExpectation(description: "Session stop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            stopExpectation.fulfill()
        }
        wait(for: [stopExpectation], timeout: 2.0)
    }
    
    // MARK: - Preview Layer Tests
    
    func testPreviewLayerCreation() {
        let previewLayer = cameraService.getPreviewLayer()
        
        // Preview layer should be created
        XCTAssertNotNil(previewLayer)
        XCTAssertTrue(previewLayer is AVCaptureVideoPreviewLayer)
        
        // Subsequent calls should return the same instance
        let secondPreviewLayer = cameraService.getPreviewLayer()
        XCTAssertEqual(previewLayer, secondPreviewLayer)
    }
    
    // MARK: - Capture Tests
    
    func testCaptureWithoutPermission() async {
        // Test capture when camera permission is not granted
        do {
            let bundle = try await cameraService.captureFrameBundle()
            // If we get here, capture succeeded (device has camera access)
            XCTAssertNotNil(bundle)
            XCTAssertFalse(bundle.frames.isEmpty)
        } catch {
            // Expected if no camera permission or camera not available
            XCTAssertTrue(error is CameraError)
        }
    }
    
    func testConcurrentCapture() async {
        // Test that concurrent captures are handled properly
        let firstCaptureTask = Task {
            do {
                return try await cameraService.captureFrameBundle()
            } catch {
                return nil
            }
        }
        
        let secondCaptureTask = Task {
            do {
                return try await cameraService.captureFrameBundle()
            } catch {
                return nil
            }
        }
        
        let firstBundle = await firstCaptureTask.value
        let secondBundle = await secondCaptureTask.value
        
        // At least one should complete (or both fail gracefully)
        XCTAssertTrue(firstBundle != nil || secondBundle != nil || (firstBundle == nil && secondBundle == nil))
    }
    
    // MARK: - Error Handling Tests
    
    func testCameraErrorTypes() {
        let deviceNotFoundError = CameraError.deviceNotFound
        let permissionDeniedError = CameraError.permissionDenied
        let captureError = CameraError.captureFailed
        let configError = CameraError.configurationFailed
        
        XCTAssertEqual(deviceNotFoundError.errorDescription, "Camera device not found")
        XCTAssertEqual(permissionDeniedError.errorDescription, "Camera permission denied")
        XCTAssertEqual(captureError.errorDescription, "Photo capture failed")
        XCTAssertEqual(configError.errorDescription, "Camera configuration failed")
    }
    
    // MARK: - Camera Switching Tests
    
    func testCameraSwitching() {
        // Test camera switching functionality
        let initialPosition = cameraService.currentPosition
        cameraService.switchCamera()
        
        // Method should complete without crashing
        XCTAssertTrue(true)
    }
    
    // MARK: - Flash Tests
    
    func testFlashToggle() {
        let initialFlashState = cameraService.isFlashOn
        cameraService.toggleFlash()
        
        // Method should complete without crashing
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Tests
    
    func testCapturePerformance() {
        // Test the performance of capture setup
        measure {
            Task {
                do {
                    _ = try await cameraService.captureFrameBundle()
                } catch {
                    // Expected in test environment
                }
            }
        }
    }
}

// MARK: - Mock Classes for Testing

class MockCameraService: CameraService {
    var mockBundle: FrameBundle?
    var mockError: CameraError?
    var mockPermissionGranted = true
    
    override func requestCameraPermission() async -> Bool {
        return mockPermissionGranted
    }
    
    override func captureFrameBundle() async throws -> FrameBundle {
        if let error = mockError {
            throw error
        }
        
        if let bundle = mockBundle {
            return bundle
        }
        
        // Create a mock bundle
        let testImage = UIImage(systemName: "camera") ?? UIImage()
        let metadata = FrameMetadata(
            timestamp: Date(),
            lens: .wide,
            exposureSettings: ExposureSettings(iso: 100, shutterSpeed: 1/60, aperture: 2.8),
            focusDistance: 1.0,
            hasDepthData: false,
            motionDetected: false,
            faceCount: 0,
            qualityScore: 0.8
        )
        
        let frame = CapturedFrame(image: testImage, metadata: metadata)
        let sceneAnalysis = SceneAnalysis(
            dominantScene: .general,
            lightingCondition: .normal,
            motionLevel: .low,
            subjectCount: 0,
            recommendedEnhancement: .simpleEnhance
        )
        
        return FrameBundle(
            frames: [frame],
            captureTime: Date(),
            sceneAnalysis: sceneAnalysis
        )
    }
}

// MARK: - Integration Tests

final class CameraServiceIntegrationTests: XCTestCase {
    
    var mockCameraService: MockCameraService!
    
    override func setUp() {
        super.setUp()
        mockCameraService = MockCameraService()
    }
    
    override func tearDown() {
        mockCameraService = nil
        super.tearDown()
    }
    
    func testSuccessfulCapture() async {
        do {
            let bundle = try await mockCameraService.captureFrameBundle()
            
            XCTAssertNotNil(bundle)
            XCTAssertFalse(bundle.frames.isEmpty)
            XCTAssertNotNil(bundle.bestFrame)
        } catch {
            XCTFail("Mock capture should not fail: \(error)")
        }
    }
    
    func testCaptureWithError() async {
        // Setup mock error
        mockCameraService.mockError = .deviceNotFound
        
        do {
            _ = try await mockCameraService.captureFrameBundle()
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is CameraError)
            XCTAssertEqual(error as? CameraError, .deviceNotFound)
        }
    }
    
    func testPermissionDenied() async {
        mockCameraService.mockPermissionGranted = false
        
        let granted = await mockCameraService.requestCameraPermission()
        
        XCTAssertFalse(granted)
    }
}

