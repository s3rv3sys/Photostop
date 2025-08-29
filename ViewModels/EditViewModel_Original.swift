//
//  EditViewModel.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI
import Combine
import os.log

/// ViewModel for custom photo editing with creative prompts and routing integration
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
    
    // MARK: - Services
    
    private let routingService = RoutingService.shared
    private let usageTracker = UsageTracker.shared
    private let storageService = StorageService.shared
    private let logger = Logger(subsystem: "PhotoStop", category: "EditViewModel")
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var undoStack: [UIImage] = []
    private var redoStack: [UIImage] = []
    private var pendingEditRequest: PendingEditRequest?
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Set the source image for editing
    func setSourceImage(_ image: UIImage) {
        sourceImage = image
        editedImage = image
        clearHistory()
        logger.info("Source image set: \(Int(image.size.width))x\(Int(image.size.height))")
    }
    
    /// Apply edit with current settings
    func applyEdit() {
        guard let image = editedImage ?? sourceImage else { return }
        
        let prompt = getEffectivePrompt()
        guard !prompt.isEmpty else {
            errorMessage = "Please enter a prompt or select a preset"
            return
        }
        
        Task {
            await performEdit(
                image: image,
                prompt: prompt,
                task: selectedTask,
                useHighQuality: useHighQuality
            )
        }
    }
    
    /// Apply a preset prompt
    func applyPreset(_ preset: PresetPrompt) {
        selectedPresetPrompt = preset
        customPrompt = preset.prompt
        selectedTask = preset.suggestedTask
        
        applyEdit()
    }
    
    /// Undo last edit
    func undo() {
        guard canUndo, let previousImage = undoStack.popLast() else { return }
        
        if let currentImage = editedImage {
            redoStack.append(currentImage)
        }
        
        editedImage = previousImage
        updateUndoRedoState()
        logger.info("Undo applied")
    }
    
    /// Redo last undone edit
    func redo() {
        guard canRedo, let nextImage = redoStack.popLast() else { return }
        
        if let currentImage = editedImage {
            undoStack.append(currentImage)
        }
        
        editedImage = nextImage
        updateUndoRedoState()
        logger.info("Redo applied")
    }
    
    /// Reset to original image
    func resetToOriginal() {
        guard let original = sourceImage else { return }
        
        if let current = editedImage {
            undoStack.append(current)
        }
        
        editedImage = original
        redoStack.removeAll()
        updateUndoRedoState()
        logger.info("Reset to original")
    }
    
    /// Save edited image to Photos
    func saveToPhotos() {
        guard let image = editedImage else { return }
        
        Task {
            do {
                try await storageService.saveToPhotos(image)
                logger.info("Image saved to Photos")
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Save to edit history
    func saveToHistory() {
        guard let original = sourceImage,
              let edited = editedImage else { return }
        
        let historyItem = EditHistoryItem(
            originalImage: original,
            editedImage: edited,
            prompt: getEffectivePrompt(),
            task: selectedTask,
            timestamp: Date(),
            processingTime: 0 // Would be tracked during edit
        )
        
        Task {
            do {
                try await storageService.saveEditedImageLocally(EditedImage(
                    originalImage: original,
                    enhancedImage: edited,
                    prompt: historyItem.prompt,
                    qualityScore: nil,
                    processingTime: historyItem.processingTime
                ))
                
                await MainActor.run {
                    editHistory.insert(historyItem, at: 0)
                    logger.info("Edit saved to history")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save to history: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Handle paywall dismissal
    func handlePaywallDismissal(purchased: Bool) {
        showingPaywall = false
        
        if purchased {
            // Retry the pending operation
            retryEdit()
        } else {
            // User declined, clear pending request
            pendingEditRequest = nil
            isProcessing = false
        }
    }
    
    /// Retry the last edit operation
    func retryEdit() {
        guard let request = pendingEditRequest else { return }
        
        Task {
            await performEdit(
                image: request.image,
                prompt: request.prompt,
                task: request.task,
                useHighQuality: request.useHighQuality
            )
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
    
    private func getEffectivePrompt() -> String {
        if let preset = selectedPresetPrompt {
            return preset.prompt
        }
        return customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func performEdit(
        image: UIImage,
        prompt: String,
        task: EditTask,
        useHighQuality: Bool
    ) async {
        
        isProcessing = true
        processingProgress = 0.0
        errorMessage = nil
        
        // Store pending request for potential retry
        pendingEditRequest = PendingEditRequest(
            image: image,
            prompt: prompt,
            task: task,
            useHighQuality: useHighQuality
        )
        
        do {
            // Get routing decision
            let decision = routingService.getRoutingDecision(
                for: task,
                tier: usageTracker.currentTier,
                imageSize: image.size
            )
            
            routingDecision = decision
            processingProgress = 0.2
            
            // Check if user has sufficient credits
            if decision.willConsumeCredit && !usageTracker.canPerform(decision.costClass) {
                await MainActor.run {
                    isProcessing = false
                    showingPaywall = true
                }
                return
            }
            
            processingProgress = 0.4
            
            // Perform the edit
            let result = try await routingService.requestEdit(
                source: image,
                prompt: prompt,
                requestedTask: task,
                tier: usageTracker.currentTier,
                targetSize: targetSize,
                allowWatermark: !useHighQuality,
                quality: useHighQuality ? 0.95 : 0.8
            )
            
            await MainActor.run {
                // Save current state to undo stack
                if let current = editedImage {
                    undoStack.append(current)
                }
                
                // Clear redo stack
                redoStack.removeAll()
                
                // Set new image
                editedImage = result.image
                
                // Update state
                isProcessing = false
                processingProgress = 1.0
                pendingEditRequest = nil
                
                updateUndoRedoState()
                
                logger.info("Edit completed using \(result.provider.rawValue)")
            }
            
        } catch let error as RoutingError {
            await handleRoutingError(error)
        } catch {
            await MainActor.run {
                isProcessing = false
                processingProgress = 0.0
                errorMessage = "Edit failed: \(error.localizedDescription)"
                logger.error("Edit failed: \(error)")
            }
        }
    }
    
    private func handleRoutingError(_ error: RoutingError) async {
        await MainActor.run {
            isProcessing = false
            processingProgress = 0.0
            
            switch error {
            case .insufficientCredits(let required, let remaining):
                showingPaywall = true
                errorMessage = "Need \(required.description) credits. \(remaining) remaining."
                
            case .allProvidersFailed(let originalError):
                errorMessage = "All AI providers failed. Try again later."
                logger.error("All providers failed: \(originalError)")
                
            case .noProvidersAvailable:
                errorMessage = "No AI providers available for this task."
                
            case .unknownError(let underlyingError):
                errorMessage = "Edit failed: \(underlyingError.localizedDescription)"
            }
        }
    }
    
    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    private func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoState()
    }
}

// MARK: - Supporting Types

extension EditViewModel {
    
    struct PresetPrompt: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let prompt: String
        let suggestedTask: EditTask
        let category: Category
        
        enum Category: String, CaseIterable {
            case artistic = "Artistic"
            case enhancement = "Enhancement"
            case style = "Style"
            case creative = "Creative"
            case cleanup = "Cleanup"
        }
    }
    
    struct EditHistoryItem: Identifiable {
        let id = UUID()
        let originalImage: UIImage
        let editedImage: UIImage
        let prompt: String
        let task: EditTask
        let timestamp: Date
        let processingTime: TimeInterval
    }
    
    private struct PendingEditRequest {
        let image: UIImage
        let prompt: String
        let task: EditTask
        let useHighQuality: Bool
    }
}

// MARK: - Preset Prompts

extension EditViewModel {
    
    static let presetPrompts: [PresetPrompt] = [
        // Artistic
        PresetPrompt(
            name: "Oil Painting",
            prompt: "Transform into a beautiful oil painting with rich textures and artistic brushstrokes",
            suggestedTask: .restyle,
            category: .artistic
        ),
        PresetPrompt(
            name: "Watercolor",
            prompt: "Convert to a delicate watercolor painting with soft, flowing colors",
            suggestedTask: .restyle,
            category: .artistic
        ),
        PresetPrompt(
            name: "Vintage Film",
            prompt: "Apply vintage film aesthetic with warm tones and subtle grain",
            suggestedTask: .restyle,
            category: .artistic
        ),
        
        // Enhancement
        PresetPrompt(
            name: "Portrait Enhancement",
            prompt: "Enhance portrait with perfect skin, bright eyes, and natural beauty",
            suggestedTask: .simpleEnhance,
            category: .enhancement
        ),
        PresetPrompt(
            name: "Landscape Boost",
            prompt: "Enhance landscape with vibrant colors, sharp details, and dramatic sky",
            suggestedTask: .simpleEnhance,
            category: .enhancement
        ),
        PresetPrompt(
            name: "Low Light Fix",
            prompt: "Brighten and enhance low light photo while reducing noise",
            suggestedTask: .simpleEnhance,
            category: .enhancement
        ),
        
        // Style
        PresetPrompt(
            name: "Cinematic",
            prompt: "Apply cinematic color grading with dramatic lighting and mood",
            suggestedTask: .restyle,
            category: .style
        ),
        PresetPrompt(
            name: "Black & White",
            prompt: "Convert to stunning black and white with perfect contrast",
            suggestedTask: .restyle,
            category: .style
        ),
        PresetPrompt(
            name: "Warm Sunset",
            prompt: "Add warm, golden sunset lighting and atmosphere",
            suggestedTask: .restyle,
            category: .style
        ),
        
        // Creative
        PresetPrompt(
            name: "Fantasy Art",
            prompt: "Transform into magical fantasy artwork with ethereal effects",
            suggestedTask: .restyle,
            category: .creative
        ),
        PresetPrompt(
            name: "Cyberpunk",
            prompt: "Apply cyberpunk aesthetic with neon colors and futuristic mood",
            suggestedTask: .restyle,
            category: .creative
        ),
        PresetPrompt(
            name: "Anime Style",
            prompt: "Convert to anime/manga art style with vibrant colors",
            suggestedTask: .restyle,
            category: .creative
        ),
        
        // Cleanup
        PresetPrompt(
            name: "Remove Background",
            prompt: "Cleanly remove background while preserving subject details",
            suggestedTask: .bgRemove,
            category: .cleanup
        ),
        PresetPrompt(
            name: "Object Removal",
            prompt: "Remove unwanted objects and distractions from the image",
            suggestedTask: .cleanup,
            category: .cleanup
        ),
        PresetPrompt(
            name: "Blemish Fix",
            prompt: "Remove blemishes, spots, and imperfections naturally",
            suggestedTask: .cleanup,
            category: .cleanup
        )
    ]
}

// MARK: - Computed Properties

extension EditViewModel {
    
    /// Whether editing is available
    var canEdit: Bool {
        sourceImage != nil && !isProcessing
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

