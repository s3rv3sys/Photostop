//
//  CameraViewModel.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI
import AVFoundation
import Combine
import os.log

/// ViewModel for camera capture and AI enhancement workflow with routing integration
@MainActor
final class CameraViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var captureState: CaptureState = .idle
    @Published var processingState: ProcessingState = .idle
    @Published var enhancedImage: UIImage?
    @Published var originalImage: UIImage?
    @Published var errorMessage: String?
    @Published var showingPaywall = false
    @Published var showingSettings = false
    @Published var routingDecision: RoutingDecision?
    
    // Camera preview
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isFlashOn = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    
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
    func startCamera() {
        Task {
            do {
                try await cameraService.startSession()
                previewLayer = cameraService.previewLayer
                logger.info("Camera session started")
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to start camera: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Stop camera session
    func stopCamera() {
        cameraService.stopSession()
        previewLayer = nil
        logger.info("Camera session stopped")
    }
    
    /// Capture and enhance photo with one tap
    func captureAndEnhance() {
        guard captureState == .idle else { return }
        
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
    
    /// Switch camera position
    func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        
        Task {
            do {
                try await cameraService.switchCamera(to: cameraPosition)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to switch camera: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Toggle flash
    func toggleFlash() {
        isFlashOn.toggle()
        cameraService.setFlashMode(isFlashOn ? .on : .off)
    }
    
    /// Clear current results
    func clearResults() {
        enhancedImage = nil
        originalImage = nil
        errorMessage = nil
        routingDecision = nil
        pendingEditRequest = nil
        captureState = .idle
        processingState = .idle
    }
    
    /// Handle paywall dismissal
    func handlePaywallDismissal(purchased: Bool) {
        showingPaywall = false
        
        if purchased {
            // Retry the pending operation
            retryEnhancement()
        } else {
            // User declined, clear pending request
            pendingEditRequest = nil
            processingState = .idle
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Listen for usage updates
        NotificationCenter.default.publisher(for: .usageUpdated)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Listen for subscription changes
        NotificationCenter.default.publisher(for: .subscriptionStatusChanged)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func setupCamera() {
        Task {
            await requestCameraPermission()
        }
    }
    
    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            startCamera()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                startCamera()
            } else {
                await MainActor.run {
                    errorMessage = "Camera access is required for PhotoStop"
                }
            }
        case .denied, .restricted:
            await MainActor.run {
                errorMessage = "Please enable camera access in Settings"
            }
        @unknown default:
            await MainActor.run {
                errorMessage = "Camera access status unknown"
            }
        }
    }
    
    private func performCaptureAndEnhance() async {
        // Update capture state
        captureState = .capturing
        errorMessage = nil
        
        do {
            // Capture burst of images
            let capturedImages = try await cameraService.captureBurstImages(count: 5)
            
            captureState = .processing
            processingState = .selectingBestFrame
            
            // Select best frame using ML scoring
            let bestImage = try await selectBestFrame(from: capturedImages)
            originalImage = bestImage
            
            // Perform AI enhancement
            await performEnhancement(
                image: bestImage,
                prompt: customPrompt.isEmpty ? nil : customPrompt,
                task: selectedTask,
                useHighQuality: useHighQuality
            )
            
        } catch {
            await MainActor.run {
                captureState = .idle
                processingState = .idle
                errorMessage = "Capture failed: \(error.localizedDescription)"
                logger.error("Capture failed: \(error)")
            }
        }
    }
    
    private func selectBestFrame(from images: [UIImage]) async throws -> UIImage {
        let frameScoringService = FrameScoringService.shared
        
        // Score all frames
        var bestImage = images.first!
        var bestScore: Float = 0
        
        for image in images {
            let score = try await frameScoringService.scoreImage(image)
            if score.overallScore > bestScore {
                bestScore = score.overallScore
                bestImage = image
            }
        }
        
        logger.info("Selected best frame with score: \(bestScore)")
        return bestImage
    }
    
    private func performEnhancement(
        image: UIImage,
        prompt: String?,
        task: EditTask,
        useHighQuality: Bool
    ) async {
        
        processingState = .enhancing
        
        // Store pending request for potential retry
        pendingEditRequest = PendingEditRequest(
            image: image,
            prompt: prompt,
            task: task,
            useHighQuality: useHighQuality
        )
        
        do {
            // Get routing decision first
            let decision = routingService.getRoutingDecision(
                for: task,
                tier: usageTracker.currentTier,
                imageSize: image.size
            )
            
            routingDecision = decision
            
            // Check if user has sufficient credits
            if decision.willConsumeCredit && !usageTracker.canPerform(decision.costClass) {
                await MainActor.run {
                    processingState = .idle
                    showingPaywall = true
                }
                return
            }
            
            // Perform the enhancement
            let result = try await routingService.requestEdit(
                source: image,
                prompt: prompt,
                requestedTask: task,
                tier: usageTracker.currentTier,
                targetSize: nil,
                allowWatermark: !useHighQuality,
                quality: useHighQuality ? 0.95 : 0.8
            )
            
            await MainActor.run {
                enhancedImage = result.image
                captureState = .completed
                processingState = .completed
                pendingEditRequest = nil
                
                logger.info("Enhancement completed using \(result.provider.rawValue)")
            }
            
        } catch let error as RoutingError {
            await handleRoutingError(error)
        } catch {
            await MainActor.run {
                processingState = .failed
                errorMessage = "Enhancement failed: \(error.localizedDescription)"
                logger.error("Enhancement failed: \(error)")
            }
        }
    }
    
    private func handleRoutingError(_ error: RoutingError) async {
        await MainActor.run {
            switch error {
            case .insufficientCredits(let required, let remaining):
                processingState = .idle
                showingPaywall = true
                errorMessage = "Need \(required.description) credits. \(remaining) remaining."
                
            case .allProvidersFailed(let originalError):
                processingState = .failed
                errorMessage = "All AI providers failed. Try again later."
                logger.error("All providers failed: \(originalError)")
                
            case .noProvidersAvailable:
                processingState = .failed
                errorMessage = "No AI providers available for this task."
                
            case .unknownError(let underlyingError):
                processingState = .failed
                errorMessage = "Enhancement failed: \(underlyingError.localizedDescription)"
            }
        }
    }
}

// MARK: - Supporting Types

extension CameraViewModel {
    
    enum CaptureState {
        case idle
        case capturing
        case processing
        case completed
        case failed
        
        var description: String {
            switch self {
            case .idle: return "Ready"
            case .capturing: return "Capturing..."
            case .processing: return "Processing..."
            case .completed: return "Complete"
            case .failed: return "Failed"
            }
        }
    }
    
    enum ProcessingState {
        case idle
        case selectingBestFrame
        case enhancing
        case completed
        case failed
        
        var description: String {
            switch self {
            case .idle: return ""
            case .selectingBestFrame: return "Selecting best frame..."
            case .enhancing: return "Enhancing with AI..."
            case .completed: return "Enhancement complete!"
            case .failed: return "Enhancement failed"
            }
        }
        
        var progress: Double {
            switch self {
            case .idle: return 0.0
            case .selectingBestFrame: return 0.3
            case .enhancing: return 0.7
            case .completed: return 1.0
            case .failed: return 0.0
            }
        }
    }
    
    private struct PendingEditRequest {
        let image: UIImage
        let prompt: String?
        let task: EditTask
        let useHighQuality: Bool
    }
}

// MARK: - Computed Properties

extension CameraViewModel {
    
    /// Whether capture is currently in progress
    var isCapturing: Bool {
        captureState == .capturing || captureState == .processing
    }
    
    /// Whether enhancement is in progress
    var isProcessing: Bool {
        processingState != .idle && processingState != .completed && processingState != .failed
    }
    
    /// Current processing progress (0.0 to 1.0)
    var processingProgress: Double {
        processingState.progress
    }
    
    /// Whether results are available
    var hasResults: Bool {
        enhancedImage != nil && originalImage != nil
    }
    
    /// Current usage statistics
    var usageStats: (budget: Int, premium: Int, budgetRemaining: Int, premiumRemaining: Int) {
        let tier = usageTracker.currentTier
        let budgetRemaining = usageTracker.remaining(for: tier, cost: .budget)
        let premiumRemaining = usageTracker.remaining(for: tier, cost: .premium)
        let budgetCapacity = usageTracker.capacity(for: tier, cost: .budget)
        let premiumCapacity = usageTracker.capacity(for: tier, cost: .premium)
        
        return (
            budget: budgetCapacity - budgetRemaining,
            premium: premiumCapacity - premiumRemaining,
            budgetRemaining: budgetRemaining,
            premiumRemaining: premiumRemaining
        )
    }
    
    /// Whether user should be encouraged to upgrade
    var shouldShowUpgradePrompt: Bool {
        let tier = usageTracker.currentTier
        if tier == .pro { return false }
        
        let budgetRemaining = usageTracker.remaining(for: tier, cost: .budget)
        let premiumRemaining = usageTracker.remaining(for: tier, cost: .premium)
        
        return budgetRemaining < 10 || premiumRemaining < 2
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("CameraViewModel.subscriptionStatusChanged")
}

