//
//  CameraViewModel.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI
import AVFoundation
import Combine
import os.log

/// ViewModel for camera capture and AI enhancement workflow with routing integration
@MainActor
final class CameraViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Core state
    @Published var captureState: CaptureState = .idle
    @Published var processingState: ProcessingState = .idle
    @Published var enhancedImage: UIImage?
    @Published var originalImage: UIImage?
    @Published var errorMessage: String?
    @Published var currentError: Error?
    
    // UI state
    @Published var showingPaywall = false
    @Published var showingSettings = false
    @Published var showingResult = false
    @Published var routingDecision: RoutingDecision?
    
    // Camera properties (required by CameraView)
    @Published var captureSession: AVCaptureSession?
    @Published var isFlashOn = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    
    // Processing properties (required by CameraView)
    @Published var isProcessing = false
    @Published var processingStatus = ""
    @Published var processingProgress: Float = 0.0
    
    // Enhancement options
    @Published var customPrompt: String = ""
    @Published var selectedTask: EditTask = .simpleEnhance
    @Published var useHighQuality = false
    
    // MARK: - Services
    
    private let cameraService = CameraService.shared
    private let routingService = RoutingService.shared
    private let usageTracker = UsageTracker.shared
    private let logger = Logger(subsystem: "PhotoStop", category: "CameraViewModel")
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var pendingEditRequest: PendingEditRequest?
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        setupCamera()
    }
    
    // MARK: - Public Methods
    
    /// Start camera session
    func startSession() {
        Task {
            do {
                try await cameraService.startSession()
                captureSession = cameraService.captureSession
                logger.info("Camera session started")
            } catch {
                await MainActor.run {
                    currentError = PhotoStopError.cameraNotAvailable
                    errorMessage = "Failed to start camera: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Stop camera session
    func stopSession() {
        cameraService.stopSession()
        captureSession = nil
        logger.info("Camera session stopped")
    }
    
    /// Toggle flash on/off
    func toggleFlash() {
        isFlashOn.toggle()
        cameraService.setFlashMode(isFlashOn ? .on : .off)
        logger.info("Flash toggled: \(isFlashOn)")
    }
    
    /// Switch camera position
    func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        Task {
            do {
                try await cameraService.switchCamera(to: cameraPosition)
                logger.info("Camera switched to: \(cameraPosition)")
            } catch {
                await MainActor.run {
                    currentError = PhotoStopError.cameraNotAvailable
                }
            }
        }
    }
    
    /// Capture and enhance photo with one tap
    func captureAndEnhance() {
        guard !isProcessing else { return }
        
        Task {
            await performCaptureAndEnhance()
        }
    }
    
    /// Retry enhancement with different settings
    func retryEnhancement() {
        guard let request = pendingEditRequest else { return }
        
        Task {
            await performEnhancement(
                image: request.image,
                prompt: request.prompt,
                task: request.task,
                useHighQuality: request.useHighQuality
            )
        }
    }
    
    /// Clear current error
    func clearError() {
        currentError = nil
        errorMessage = nil
    }
    
    /// Present paywall for upgrade
    func presentPaywall(reason: UpgradeReason) {
        routingDecision = .requiresUpgrade(reason: reason)
        showingPaywall = true
    }
    
    /// Handle successful purchase
    func handlePurchaseSuccess() {
        showingPaywall = false
        
        // Retry pending request if available
        if pendingEditRequest != nil {
            retryEnhancement()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind processing state to UI properties
        $processingState
            .sink { [weak self] state in
                self?.updateProcessingUI(for: state)
            }
            .store(in: &cancellables)
        
        // Bind capture state
        $captureState
            .sink { [weak self] state in
                self?.updateCaptureUI(for: state)
            }
            .store(in: &cancellables)
    }
    
    private func setupCamera() {
        // Initialize camera service
        Task {
            await requestCameraPermission()
        }
    }
    
    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            await startSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await startSession()
            } else {
                await MainActor.run {
                    currentError = PhotoStopError.cameraPermissionDenied
                }
            }
        case .denied, .restricted:
            await MainActor.run {
                currentError = PhotoStopError.cameraPermissionDenied
            }
        @unknown default:
            await MainActor.run {
                currentError = PhotoStopError.cameraNotAvailable
            }
        }
    }
    
    private func updateProcessingUI(for state: ProcessingState) {
        switch state {
        case .idle:
            isProcessing = false
            processingStatus = ""
            processingProgress = 0.0
            
        case .capturing:
            isProcessing = true
            processingStatus = "Capturing frames..."
            processingProgress = 0.2
            
        case .analyzing:
            isProcessing = true
            processingStatus = "Analyzing quality..."
            processingProgress = 0.4
            
        case .enhancing(let provider):
            isProcessing = true
            processingStatus = "Enhancing with \(provider)..."
            processingProgress = 0.7
            
        case .finalizing:
            isProcessing = true
            processingStatus = "Finalizing result..."
            processingProgress = 0.9
            
        case .completed:
            isProcessing = false
            processingStatus = "Complete!"
            processingProgress = 1.0
            showingResult = true
            
        case .failed(let error):
            isProcessing = false
            processingStatus = ""
            processingProgress = 0.0
            currentError = error
        }
    }
    
    private func updateCaptureUI(for state: CaptureState) {
        switch state {
        case .idle:
            break
        case .capturing:
            processingState = .capturing
        case .processing:
            processingState = .analyzing
        case .completed:
            processingState = .completed
        case .failed(let error):
            processingState = .failed(error: error)
        }
    }
    
    private func performCaptureAndEnhance() async {
        logger.info("Starting capture and enhance workflow")
        
        // Update state
        captureState = .capturing
        
        do {
            // Capture frames
            let frameBundle = try await cameraService.captureFrameBundle()
            logger.info("Captured \(frameBundle.frames.count) frames")
            
            // Store original image
            originalImage = frameBundle.bestFrame?.image
            
            // Update state
            captureState = .processing
            
            // Enhance with routing
            let editRequest = EditRequest(
                image: frameBundle.bestFrame?.image ?? UIImage(),
                prompt: customPrompt.isEmpty ? "enhance photo quality" : customPrompt,
                task: selectedTask,
                useHighQuality: useHighQuality
            )
            
            // Store pending request for retry
            pendingEditRequest = PendingEditRequest(
                image: editRequest.image,
                prompt: editRequest.prompt,
                task: editRequest.task,
                useHighQuality: editRequest.useHighQuality
            )
            
            let result = await routingService.routeEdit(editRequest)
            
            switch result {
            case .success(let enhancedImage, let metadata):
                // Success
                self.enhancedImage = enhancedImage
                captureState = .completed
                logger.info("Enhancement completed with \(metadata.provider)")
                
            case .requiresUpgrade(let reason):
                // Show paywall
                presentPaywall(reason: reason)
                captureState = .idle
                
            case .failed(let error):
                // Handle error
                captureState = .failed(error: error)
                logger.error("Enhancement failed: \(error.localizedDescription)")
            }
            
        } catch {
            captureState = .failed(error: error)
            logger.error("Capture failed: \(error.localizedDescription)")
        }
    }
    
    private func performEnhancement(image: UIImage, prompt: String, task: EditTask, useHighQuality: Bool) async {
        let editRequest = EditRequest(
            image: image,
            prompt: prompt,
            task: task,
            useHighQuality: useHighQuality
        )
        
        processingState = .enhancing(provider: "AI")
        
        let result = await routingService.routeEdit(editRequest)
        
        switch result {
        case .success(let enhancedImage, let metadata):
            self.enhancedImage = enhancedImage
            processingState = .completed
            logger.info("Retry enhancement completed with \(metadata.provider)")
            
        case .requiresUpgrade(let reason):
            presentPaywall(reason: reason)
            processingState = .idle
            
        case .failed(let error):
            processingState = .failed(error: error)
            logger.error("Retry enhancement failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

/// Capture states
enum CaptureState: Equatable {
    case idle
    case capturing
    case processing
    case completed
    case failed(error: Error)
    
    static func == (lhs: CaptureState, rhs: CaptureState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.capturing, .capturing),
             (.processing, .processing),
             (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

/// Pending edit request for retry
struct PendingEditRequest {
    let image: UIImage
    let prompt: String
    let task: EditTask
    let useHighQuality: Bool
}

