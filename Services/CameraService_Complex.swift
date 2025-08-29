//
//  CameraService.swift
//  PhotoStop - Capture v2
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import AVFoundation
import UIKit
import Vision
import OSLog

/// Advanced camera service with multi-lens burst capture and depth integration
@MainActor
public final class CameraService: NSObject, ObservableObject {
    
    static let shared = CameraService()
    
    // MARK: - Published Properties
    
    @Published public var isSessionRunning = false
    @Published public var isCapturing = false
    @Published public var captureProgress: Double = 0.0
    @Published public var lastError: CameraError?
    @Published public var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    // MARK: - Public Properties
    
    public let captureSession = AVCaptureSession()
    public private(set) var isFlashOn = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "CameraService")
    private let lensService = CameraLensService.shared
    private let depthService = DepthService.shared
    
    // Multi-cam session for simultaneous capture
    private var multiCamSession: AVCaptureMultiCamSession?
    
    // Single-cam components for fallback
    private var currentInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    
    // Multi-cam components
    private var multiCamInputs: [AVCaptureDeviceInput] = []
    private var multiCamOutputs: [AVCapturePhotoOutput] = []
    
    // Capture state
    private var captureStartTime: Date?
    private var capturedFrames: [CapturedFrame] = []
    private var expectedFrameCount = 0
    private var captureCompletion: ((Result<FrameBundle, CameraError>) -> Void)?
    
    // Face detection
    private let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupFaceDetection()
    }
    
    // MARK: - Public Interface
    
    /// Request camera permission and setup session
    public func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            authorizationStatus = .authorized
            return true
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
            return granted
            
        case .denied, .restricted:
            authorizationStatus = status
            return false
            
        @unknown default:
            authorizationStatus = .denied
            return false
        }
    }
    
    /// Setup camera session with optimal configuration
    public func setupSession() async throws {
        guard await requestPermission() else {
            throw CameraError.permissionDenied
        }
        
        // Discover available lenses
        lensService.discoverAvailableLenses()
        
        // Setup multi-cam if supported, otherwise fallback to single-cam
        if lensService.isMultiCamSupported {
            try setupMultiCamSession()
        } else {
            try setupSingleCamSession()
        }
        
        logger.info("Camera session setup complete - Multi-cam: \(lensService.isMultiCamSupported)")
    }
    
    /// Start camera session
    public func startSession() {
        guard !isSessionRunning else { return }
        
        Task {
            do {
                if captureSession.inputs.isEmpty {
                    try await setupSession()
                }
                
                if lensService.isMultiCamSupported {
                    multiCamSession?.startRunning()
                } else {
                    captureSession.startRunning()
                }
                
                isSessionRunning = true
                logger.info("Camera session started")
                
            } catch {
                lastError = error as? CameraError ?? .sessionSetupFailed
                logger.error("Failed to start camera session: \(error.localizedDescription)")
            }
        }
    }
    
    /// Stop camera session
    public func stopSession() {
        guard isSessionRunning else { return }
        
        if lensService.isMultiCamSupported {
            multiCamSession?.stopRunning()
        } else {
            captureSession.stopRunning()
        }
        
        isSessionRunning = false
        logger.info("Camera session stopped")
    }
    
    /// Capture multi-lens burst with depth and metadata
    public func captureBundle() async throws -> FrameBundle {
        guard !isCapturing else {
            throw CameraError.captureInProgress
        }
        
        isCapturing = true
        captureProgress = 0.0
        captureStartTime = Date()
        capturedFrames = []
        lastError = nil
        
        defer {
            isCapturing = false
            captureProgress = 0.0
        }
        
        do {
            let bundle: FrameBundle
            
            if lensService.isMultiCamSupported {
                bundle = try await captureMultiCamBundle()
            } else {
                bundle = try await captureSingleCamBundle()
            }
            
            logger.info("Captured bundle with \(bundle.frameCount) frames in \(bundle.captureDuration)s")
            return bundle
            
        } catch {
            lastError = error as? CameraError ?? .captureFailure
            logger.error("Bundle capture failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Toggle flash on/off
    public func toggleFlash() {
        isFlashOn.toggle()
        logger.info("Flash toggled: \(isFlashOn ? "ON" : "OFF")")
    }
    
    /// Switch to a specific lens (single-cam mode)
    public func switchToLens(_ lens: FrameMetadata.Lens) async throws {
        guard !lensService.isMultiCamSupported else {
            logger.warning("Cannot switch lens in multi-cam mode")
            return
        }
        
        guard let device = lensService.device(for: lens) else {
            throw CameraError.lensNotAvailable
        }
        
        try await switchCameraInput(to: device)
        lensService.currentLens = lens
        
        logger.info("Switched to lens: \(lens.displayName)")
    }
    
    // MARK: - Multi-Cam Capture
    
    private func captureMultiCamBundle() async throws -> FrameBundle {
        guard let session = multiCamSession else {
            throw CameraError.multiCamNotAvailable
        }
        
        let devices = lensService.devicesForMultiCam()
        let lenses = devices.compactMap { device in
            lensService.availableLenses.first { lens in
                lensService.device(for: lens) == device
            }
        }
        
        // Calculate expected frame count (3-5 frames per lens with exposure bracketing)
        expectedFrameCount = lenses.count * 3 // 3 exposure brackets per lens
        
        return try await withCheckedThrowingContinuation { continuation in
            captureCompletion = continuation.resume
            
            // Capture from each output simultaneously
            for (index, output) in multiCamOutputs.enumerated() {
                guard index < lenses.count else { continue }
                
                let lens = lenses[index]
                let bracketSettings = createBracketSettings(for: lens)
                
                output.capturePhoto(with: bracketSettings, delegate: self)
            }
            
            // Timeout after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.isCapturing {
                    continuation.resume(throwing: CameraError.captureTimeout)
                }
            }
        }
    }
    
    // MARK: - Single-Cam Capture (Fallback)
    
    private func captureSingleCamBundle() async throws -> FrameBundle {
        let availableLenses = lensService.availableLenses
        var allFrames: [CapturedFrame] = []
        
        // Calculate expected frame count
        expectedFrameCount = availableLenses.count * 3 // 3 exposure brackets per lens
        
        // Capture from each lens sequentially
        for lens in availableLenses {
            guard let device = lensService.device(for: lens) else { continue }
            
            // Switch to this lens
            try await switchCameraInput(to: device)
            
            // Capture bracketed frames
            let frames = try await captureBracketedFrames(for: lens)
            allFrames.append(contentsOf: frames)
            
            // Update progress
            captureProgress = Double(allFrames.count) / Double(expectedFrameCount)
        }
        
        // Process captured frames into bundle
        return try await processFramesIntoBundle(allFrames)
    }
    
    private func captureBracketedFrames(for lens: FrameMetadata.Lens) async throws -> [CapturedFrame] {
        guard let output = photoOutput else {
            throw CameraError.outputNotConfigured
        }
        
        let bracketSettings = createBracketSettings(for: lens)
        var frames: [CapturedFrame] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            var capturedCount = 0
            let expectedCount = bracketSettings.bracketedSettings.count
            
            let delegate = BracketCaptureDelegate(lens: lens) { result in
                switch result {
                case .success(let frame):
                    frames.append(frame)
                    capturedCount += 1
                    
                    if capturedCount >= expectedCount {
                        continuation.resume(returning: frames)
                    }
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            output.capturePhoto(with: bracketSettings, delegate: delegate)
        }
    }
    
    // MARK: - Session Setup
    
    private func setupMultiCamSession() throws {
        multiCamSession = AVCaptureMultiCamSession()
        guard let session = multiCamSession else {
            throw CameraError.multiCamNotAvailable
        }
        
        session.beginConfiguration()
        
        let devices = lensService.devicesForMultiCam()
        
        for device in devices {
            // Create input
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                logger.warning("Cannot add input for device: \(device.localizedName)")
                continue
            }
            session.addInput(input)
            multiCamInputs.append(input)
            
            // Create output
            let output = AVCapturePhotoOutput()
            output.isDepthDataDeliveryEnabled = lensService.supportsDepthCapture(
                lens: lensService.availableLenses.first { lensService.device(for: $0) == device } ?? .wide
            )
            
            guard session.canAddOutput(output) else {
                logger.warning("Cannot add output for device: \(device.localizedName)")
                continue
            }
            session.addOutput(output)
            multiCamOutputs.append(output)
        }
        
        session.commitConfiguration()
        
        logger.info("Multi-cam session configured with \(multiCamInputs.count) inputs")
    }
    
    private func setupSingleCamSession() throws {
        captureSession.beginConfiguration()
        
        // Use wide lens as default
        guard let wideDevice = lensService.device(for: .wide) else {
            throw CameraError.noCamera
        }
        
        let input = try AVCaptureDeviceInput(device: wideDevice)
        guard captureSession.canAddInput(input) else {
            throw CameraError.inputNotSupported
        }
        captureSession.addInput(input)
        currentInput = input
        
        let output = AVCapturePhotoOutput()
        output.isDepthDataDeliveryEnabled = lensService.supportsDepthCapture(lens: .wide)
        
        guard captureSession.canAddOutput(output) else {
            throw CameraError.outputNotSupported
        }
        captureSession.addOutput(output)
        photoOutput = output
        
        captureSession.commitConfiguration()
        
        logger.info("Single-cam session configured")
    }
    
    private func switchCameraInput(to device: AVCaptureDevice) async throws {
        guard let currentInput = currentInput else {
            throw CameraError.inputNotConfigured
        }
        
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
        
        let newInput = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(newInput) else {
            // Restore previous input
            captureSession.addInput(currentInput)
            captureSession.commitConfiguration()
            throw CameraError.inputNotSupported
        }
        
        captureSession.addInput(newInput)
        self.currentInput = newInput
        captureSession.commitConfiguration()
    }
    
    // MARK: - Capture Settings
    
    private func createBracketSettings(for lens: FrameMetadata.Lens) -> AVCapturePhotoBracketSettings {
        let exposureBiases = lensService.exposureBracketSettings(for: lens)
        
        let bracketedSettings = exposureBiases.map { bias in
            AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: bias)
        }
        
        let settings = AVCapturePhotoBracketSettings(
            rawPixelFormatType: 0,
            processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg],
            bracketedSettings: bracketedSettings
        )
        
        // Configure depth data delivery if supported
        if lensService.supportsDepthCapture(lens: lens) {
            settings.isDepthDataDeliveryEnabled = true
            settings.embedsDepthDataInPhoto = false
        }
        
        // Configure flash
        settings.flashMode = isFlashOn ? .on : .off
        
        return settings
    }
    
    // MARK: - Frame Processing
    
    private func processFramesIntoBundle(_ frames: [CapturedFrame]) async throws -> FrameBundle {
        guard !frames.isEmpty else {
            throw CameraError.noFramesCaptured
        }
        
        let startTime = captureStartTime ?? Date()
        let duration = Date().timeIntervalSince(startTime)
        
        // Convert captured frames to bundle items
        var bundleItems: [FrameBundle.Item] = []
        
        for frame in frames {
            // Process depth data if available
            var depthResult: DepthResult?
            if let photo = frame.photo, photo.depthData != nil {
                depthResult = await depthService.processDepthData(from: photo)
            }
            
            let item = FrameBundle.Item(
                image: frame.image,
                depth: depthResult?.depthMap,
                matte: depthResult?.portraitMatte,
                metadata: frame.metadata
            )
            
            bundleItems.append(item)
        }
        
        // Analyze scene hints
        let sceneHints = SceneHints.analyze(from: bundleItems)
        
        // Create session metadata
        let sessionMetadata = SessionMetadata(
            deviceModel: UIDevice.current.model,
            iosVersion: UIDevice.current.systemVersion,
            usedMultiCam: lensService.isMultiCamSupported,
            availableLenses: lensService.availableLenses,
            captureMode: "burst_v2",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
        )
        
        return FrameBundle(
            items: bundleItems,
            sceneHints: sceneHints,
            sessionMetadata: sessionMetadata,
            captureDuration: duration,
            captureStartTime: startTime
        )
    }
    
    // MARK: - Face Detection
    
    private func setupFaceDetection() {
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
    }
    
    private func detectFaces(in image: UIImage) async -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        
        return await withCheckedContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([faceDetectionRequest])
                let faceCount = faceDetectionRequest.results?.count ?? 0
                continuation.resume(returning: faceCount)
            } catch {
                logger.error("Face detection failed: \(error.localizedDescription)")
                continuation.resume(returning: 0)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            logger.error("Photo capture failed: \(error.localizedDescription)")
            captureCompletion?(.failure(.captureFailure))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            logger.error("Failed to create image from photo data")
            captureCompletion?(.failure(.imageCreationFailed))
            return
        }
        
        // Determine which lens was used (this would be more sophisticated in practice)
        let lens = determineLensFromOutput(output)
        
        // Create metadata
        let metadata = FrameMetadata.from(
            resolvedSettings: photo.resolvedSettings,
            lens: lens,
            image: image,
            depthData: photo.depthData
        )
        
        let capturedFrame = CapturedFrame(
            image: image,
            metadata: metadata,
            photo: photo
        )
        
        capturedFrames.append(capturedFrame)
        
        // Update progress
        captureProgress = Double(capturedFrames.count) / Double(expectedFrameCount)
        
        // Check if we've captured all expected frames
        if capturedFrames.count >= expectedFrameCount {
            Task {
                do {
                    let bundle = try await processFramesIntoBundle(capturedFrames)
                    captureCompletion?(.success(bundle))
                } catch {
                    captureCompletion?(.failure(error as? CameraError ?? .processingFailed))
                }
            }
        }
    }
    
    private func determineLensFromOutput(_ output: AVCapturePhotoOutput) -> FrameMetadata.Lens {
        // In multi-cam mode, determine lens from output index
        if lensService.isMultiCamSupported {
            if let index = multiCamOutputs.firstIndex(of: output) {
                let devices = lensService.devicesForMultiCam()
                if index < devices.count {
                    let device = devices[index]
                    return lensService.availableLenses.first { lens in
                        lensService.device(for: lens) == device
                    } ?? .wide
                }
            }
        }
        
        // In single-cam mode, use current lens
        return lensService.currentLens
    }
}

// MARK: - Supporting Types

/// Captured frame with associated data
private struct CapturedFrame {
    let image: UIImage
    let metadata: FrameMetadata
    let photo: AVCapturePhoto?
}

/// Delegate for bracket capture in single-cam mode
private class BracketCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let lens: FrameMetadata.Lens
    private let completion: (Result<CapturedFrame, CameraError>) -> Void
    
    init(lens: FrameMetadata.Lens, completion: @escaping (Result<CapturedFrame, CameraError>) -> Void) {
        self.lens = lens
        self.completion = completion
    }
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            completion(.failure(.captureFailure))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completion(.failure(.imageCreationFailed))
            return
        }
        
        let metadata = FrameMetadata.from(
            resolvedSettings: photo.resolvedSettings,
            lens: lens,
            image: image,
            depthData: photo.depthData
        )
        
        let frame = CapturedFrame(image: image, metadata: metadata, photo: photo)
        completion(.success(frame))
    }
}

// MARK: - Error Types

public enum CameraError: Error, LocalizedError {
    case permissionDenied
    case noCamera
    case sessionSetupFailed
    case inputNotSupported
    case outputNotSupported
    case inputNotConfigured
    case outputNotConfigured
    case multiCamNotAvailable
    case lensNotAvailable
    case captureInProgress
    case captureFailure
    case captureTimeout
    case noFramesCaptured
    case imageCreationFailed
    case processingFailed
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission denied"
        case .noCamera:
            return "No camera available"
        case .sessionSetupFailed:
            return "Failed to setup camera session"
        case .inputNotSupported:
            return "Camera input not supported"
        case .outputNotSupported:
            return "Camera output not supported"
        case .inputNotConfigured:
            return "Camera input not configured"
        case .outputNotConfigured:
            return "Camera output not configured"
        case .multiCamNotAvailable:
            return "Multi-camera not available"
        case .lensNotAvailable:
            return "Requested lens not available"
        case .captureInProgress:
            return "Capture already in progress"
        case .captureFailure:
            return "Photo capture failed"
        case .captureTimeout:
            return "Capture timed out"
        case .noFramesCaptured:
            return "No frames were captured"
        case .imageCreationFailed:
            return "Failed to create image"
        case .processingFailed:
            return "Frame processing failed"
        }
    }
}

