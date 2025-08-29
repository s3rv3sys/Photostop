//
//  EditViewModel.swift
//  PhotoStop - Enhanced with Personalization v1
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI
import Combine
import os.log

/// ViewModel for custom photo editing with creative prompts, routing integration, and personalization feedback
@MainActor
final class EditViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var sourceImage: UIImage?
    @Published var editedImage: UIImage?
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var showingPaywall = false
    @Published var routingDecision: RoutingDecision?
    
    // Edit parameters
    @Published var customPrompt: String = ""
    @Published var selectedTask: EditTask = .restyle
    @Published var useHighQuality = false
    @Published var targetSize: CGSize?
    
    // Predefined prompts
    @Published var selectedPresetPrompt: PresetPrompt?
    
    // History
    @Published var editHistory: [EditHistoryItem] = []
    @Published var canUndo = false
    @Published var canRedo = false
    
    // NEW: Personalization feedback
    @Published var showingRatingPrompt = false
    @Published var lastEditResult: EditResult?
    @Published var pendingFeedbackItem: FrameBundle.Item?
    
    // MARK: - Services
    
    private let routingService = RoutingService.shared
    private let usageTracker = UsageTracker.shared
    private let storageService = StorageService.shared
    
    // NEW: Personalization integration
    private let personalizationEngine = PersonalizationEngine.shared
    private let frameScoringService = FrameScoringService.shared
    
    private let logger = Logger(subsystem: "PhotoStop", category: "EditViewModel")
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var undoStack: [UIImage] = []
    private var redoStack: [UIImage] = []
    private var currentEditSession: EditSession?
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        loadEditHistory()
    }
    
    // MARK: - Public Interface
    
    /// Apply edit with routing and personalization feedback
    func applyEdit() async {
        guard let sourceImage = sourceImage else {
            errorMessage = "No source image available"
            return
        }
        
        guard !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter an edit prompt"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            processingProgress = 1.0
        }
        
        do {
            // Start edit session for personalization tracking
            currentEditSession = EditSession(
                sourceImage: sourceImage,
                prompt: customPrompt,
                task: selectedTask,
                startTime: Date()
            )
            
            // Create edit request
            let request = EditRequest(
                image: sourceImage,
                prompt: customPrompt,
                task: selectedTask,
                quality: useHighQuality ? .high : .standard,
                targetSize: targetSize
            )
            
            processingProgress = 0.2
            
            // Route the edit request
            let decision = await routingService.routeEditRequest(request)
            routingDecision = decision
            
            switch decision {
            case .route(let provider, let config):
                processingProgress = 0.4
                
                // Execute the edit
                let result = try await provider.editImage(request, config: config)
                
                processingProgress = 0.8
                
                // Handle successful result
                await handleEditSuccess(result: result, provider: provider)
                
            case .requiresUpgrade(let reason):
                // Show paywall
                showingPaywall = true
                logger.info("Edit requires upgrade: \(reason.rawValue)")
                
            case .failed(let error):
                errorMessage = error.localizedDescription
                logger.error("Edit routing failed: \(error.localizedDescription)")
            }
            
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Edit failed: \(error.localizedDescription)")
        }
    }
    
    /// Handle successful edit result with personalization tracking
    private func handleEditSuccess(result: EditResult, provider: any ImageEditProvider) async {
        // Update UI
        editedImage = result.image
        
        // Add to history
        let historyItem = EditHistoryItem(
            id: UUID(),
            sourceImage: sourceImage!,
            editedImage: result.image,
            prompt: customPrompt,
            task: selectedTask,
            provider: provider.name,
            timestamp: Date(),
            processingTime: result.processingTime
        )
        
        editHistory.insert(historyItem, at: 0)
        saveEditHistory()
        
        // Update undo stack
        if let currentImage = editedImage {
            undoStack.append(currentImage)
            redoStack.removeAll()
            updateUndoRedoState()
        }
        
        // Store the result for potential personalization feedback
        lastEditResult = result
        
        // Create a FrameBundle.Item for personalization (simulate capture metadata)
        if let editSession = currentEditSession {
            let simulatedMetadata = createSimulatedMetadata(for: result.image, from: editSession)
            let frameItem = FrameBundle.Item(
                image: result.image,
                metadata: simulatedMetadata,
                qualityScore: 0.8 // Default score for edited images
            )
            
            pendingFeedbackItem = frameItem
            
            // Show rating prompt after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.personalizationEngine.currentProfile().enabled {
                    self.showingRatingPrompt = true
                }
            }
        }
        
        // Save to storage if requested
        if let targetSize = targetSize {
            try? await storageService.saveEditedImage(result.image, metadata: result.metadata)
        }
        
        logger.info("Edit completed successfully with \(provider.name)")
    }
    
    /// Process user feedback for personalization
    func submitFeedback(_ feedback: PersonalizationEvent.Feedback) {
        guard let frameItem = pendingFeedbackItem else {
            logger.warning("No pending feedback item available")
            return
        }
        
        // Create personalization event
        let event = PersonalizationEvent.from(item: frameItem, feedback: feedback)
        
        // Update personalization engine
        personalizationEngine.update(with: event)
        
        // Clear pending feedback
        pendingFeedbackItem = nil
        showingRatingPrompt = false
        
        logger.info("Submitted personalization feedback: \(feedback.rawValue)")
        
        // Show brief confirmation
        showFeedbackConfirmation(feedback)
    }
    
    /// Skip feedback (implicit neutral)
    func skipFeedback() {
        pendingFeedbackItem = nil
        showingRatingPrompt = false
        logger.debug("Skipped personalization feedback")
    }
    
    /// Apply preset prompt
    func applyPresetPrompt(_ preset: PresetPrompt) {
        selectedPresetPrompt = preset
        customPrompt = preset.prompt
        selectedTask = preset.task
        
        // Apply edit automatically for preset prompts
        Task {
            await applyEdit()
        }
    }
    
    /// Undo last edit
    func undo() {
        guard !undoStack.isEmpty else { return }
        
        if let currentImage = editedImage {
            redoStack.append(currentImage)
        }
        
        editedImage = undoStack.removeLast()
        updateUndoRedoState()
    }
    
    /// Redo last undone edit
    func redo() {
        guard !redoStack.isEmpty else { return }
        
        if let currentImage = editedImage {
            undoStack.append(currentImage)
        }
        
        editedImage = redoStack.removeLast()
        updateUndoRedoState()
    }
    
    /// Clear current edit
    func clearEdit() {
        editedImage = nil
        customPrompt = ""
        selectedPresetPrompt = nil
        errorMessage = nil
        routingDecision = nil
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoState()
    }
    
    /// Retry edit after paywall completion
    func retryAfterUpgrade() {
        showingPaywall = false
        Task {
            await applyEdit()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor usage changes
        usageTracker.$currentUsage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Update UI based on usage changes
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Monitor personalization changes
        personalizationEngine.$profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    private func loadEditHistory() {
        // Load from UserDefaults or Core Data
        if let data = UserDefaults.standard.data(forKey: "edit_history"),
           let history = try? JSONDecoder().decode([EditHistoryItem].self, from: data) {
            editHistory = history
        }
    }
    
    private func saveEditHistory() {
        // Keep only recent 50 items
        let recentHistory = Array(editHistory.prefix(50))
        
        if let data = try? JSONEncoder().encode(recentHistory) {
            UserDefaults.standard.set(data, forKey: "edit_history")
        }
    }
    
    private func createSimulatedMetadata(for image: UIImage, from session: EditSession) -> FrameMetadata {
        // Create simulated metadata for edited images (for personalization)
        return FrameMetadata(
            lens: .wide, // Default to wide lens
            iso: 400, // Moderate ISO
            shutterMS: 16.0, // 1/60s
            aperture: 2.8,
            meanLuma: 0.5, // Assume balanced exposure
            motionScore: 0.2, // Assume sharp (edited image)
            hasDepth: false, // Edited images typically don't have depth
            depthQuality: 0.0,
            timestamp: session.startTime,
            isLowLight: false,
            hasMotionBlur: false,
            isPortraitSuitable: session.task == .portrait
        )
    }
    
    private func showFeedbackConfirmation(_ feedback: PersonalizationEvent.Feedback) {
        // Show brief toast or animation
        let message = feedback == .positive ? 
            "Thanks! We'll improve your picks." : 
            "Got it! We'll adjust your preferences."
        
        // This would trigger a toast notification in the UI
        // For now, just log it
        logger.info("Feedback confirmation: \(message)")
    }
}

// MARK: - Supporting Types

/// Edit session for tracking personalization context
private struct EditSession {
    let sourceImage: UIImage
    let prompt: String
    let task: EditTask
    let startTime: Date
}

/// Edit history item
struct EditHistoryItem: Codable, Identifiable {
    let id: UUID
    let sourceImage: Data // Encoded as Data for persistence
    let editedImage: Data
    let prompt: String
    let task: EditTask
    let provider: String
    let timestamp: Date
    let processingTime: TimeInterval
    
    init(id: UUID, sourceImage: UIImage, editedImage: UIImage, prompt: String, task: EditTask, provider: String, timestamp: Date, processingTime: TimeInterval) {
        self.id = id
        self.sourceImage = sourceImage.jpegData(compressionQuality: 0.8) ?? Data()
        self.editedImage = editedImage.jpegData(compressionQuality: 0.8) ?? Data()
        self.prompt = prompt
        self.task = task
        self.provider = provider
        self.timestamp = timestamp
        self.processingTime = processingTime
    }
    
    var sourceUIImage: UIImage? {
        return UIImage(data: sourceImage)
    }
    
    var editedUIImage: UIImage? {
        return UIImage(data: editedImage)
    }
}

/// Preset prompts for common edits
struct PresetPrompt: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let prompt: String
    let task: EditTask
    let category: Category
    
    enum Category: String, CaseIterable {
        case artistic = "Artistic"
        case enhancement = "Enhancement"
        case style = "Style"
        case creative = "Creative"
        case cleanup = "Cleanup"
        
        var icon: String {
            switch self {
            case .artistic: return "paintbrush.fill"
            case .enhancement: return "wand.and.stars"
            case .style: return "camera.filters"
            case .creative: return "sparkles"
            case .cleanup: return "trash.fill"
            }
        }
    }
    
    static let presets: [PresetPrompt] = [
        // Artistic
        PresetPrompt(name: "Oil Painting", prompt: "Transform into a beautiful oil painting with visible brushstrokes", task: .restyle, category: .artistic),
        PresetPrompt(name: "Watercolor", prompt: "Convert to a soft watercolor painting with flowing colors", task: .restyle, category: .artistic),
        PresetPrompt(name: "Pencil Sketch", prompt: "Create a detailed pencil sketch drawing", task: .restyle, category: .artistic),
        
        // Enhancement
        PresetPrompt(name: "Auto Enhance", prompt: "Enhance colors, contrast, and sharpness for the best quality", task: .enhance, category: .enhancement),
        PresetPrompt(name: "Brighten", prompt: "Brighten the image while maintaining natural colors", task: .enhance, category: .enhancement),
        PresetPrompt(name: "Sharpen Details", prompt: "Enhance sharpness and bring out fine details", task: .enhance, category: .enhancement),
        
        // Style
        PresetPrompt(name: "Vintage Film", prompt: "Apply a vintage film look with warm tones and grain", task: .restyle, category: .style),
        PresetPrompt(name: "Black & White", prompt: "Convert to dramatic black and white with enhanced contrast", task: .restyle, category: .style),
        PresetPrompt(name: "Cinematic", prompt: "Apply cinematic color grading with teal and orange tones", task: .restyle, category: .style),
        
        // Creative
        PresetPrompt(name: "Fantasy Art", prompt: "Transform into a magical fantasy artwork with ethereal effects", task: .restyle, category: .creative),
        PresetPrompt(name: "Cyberpunk", prompt: "Apply cyberpunk style with neon colors and futuristic effects", task: .restyle, category: .creative),
        PresetPrompt(name: "Double Exposure", prompt: "Create a double exposure effect with artistic blending", task: .creative, category: .creative),
        
        // Cleanup
        PresetPrompt(name: "Remove Background", prompt: "Remove the background and make it transparent", task: .removeBackground, category: .cleanup),
        PresetPrompt(name: "Noise Reduction", prompt: "Reduce noise while preserving important details", task: .enhance, category: .cleanup),
        PresetPrompt(name: "Fix Lighting", prompt: "Correct lighting and exposure issues", task: .enhance, category: .cleanup),
        PresetPrompt(name: "Upscale", prompt: "Increase resolution while maintaining quality", task: .enhance, category: .cleanup)
    ]
}

