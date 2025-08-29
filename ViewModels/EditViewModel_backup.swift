//
//  EditViewModel.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import SwiftUI
import Combine

/// ViewModel for handling creative prompts and custom image edits
@MainActor
class EditViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var customPrompt = ""
    @Published var selectedPrompt: EditPrompt?
    @Published var selectedCategory: PromptCategory = .general
    
    // Results
    @Published var originalImage: UIImage?
    @Published var editedImage: UIImage?
    @Published var editHistory: [EditedImage] = []
    
    // UI State
    @Published var showingPromptPicker = false
    @Published var showingCustomPrompt = false
    @Published var showingHistory = false
    
    // Error handling
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // Prompts
    @Published var availablePrompts: [EditPrompt] = []
    @Published var recentPrompts: [EditPrompt] = []
    @Published var customPrompts: [EditPrompt] = []
    
    // MARK: - Private Properties
    private let aiService = AIService()
    private let storageService = StorageService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadPrompts()
        loadEditHistory()
    }
    
    // MARK: - Public Methods
    
    /// Apply selected prompt to image
    func applyPrompt(_ prompt: EditPrompt, to image: UIImage) async {
        guard !isProcessing else { return }
        
        isProcessing = true
        errorMessage = nil
        originalImage = image
        
        do {
            guard let enhanced = await aiService.enhanceImage(image, prompt: prompt.text) else {
                throw EditError.enhancementFailed
            }
            
            editedImage = enhanced
            
            // Update prompt usage
            updatePromptUsage(prompt)
            
            // Save to history
            await saveToHistory(original: image, enhanced: enhanced, prompt: prompt)
            
        } catch {
            handleError(error)
        }
        
        isProcessing = false
    }
    
    /// Apply custom prompt to image
    func applyCustomPrompt(to image: UIImage) async {
        guard !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a prompt"
            showingError = true
            return
        }
        
        let prompt = EditPrompt(text: customPrompt, category: .custom, isCustom: true)
        await applyPrompt(prompt, to: image)
        
        // Add to custom prompts if successful
        if editedImage != nil {
            addCustomPrompt(prompt)
        }
    }
    
    /// Get prompts for selected category
    func getPromptsForCategory(_ category: PromptCategory) -> [EditPrompt] {
        switch category {
        case .custom:
            return customPrompts
        default:
            return EditPrompt.prompts(for: category)
        }
    }
    
    /// Add custom prompt to collection
    func addCustomPrompt(_ prompt: EditPrompt) {
        let customPrompt = EditPrompt(
            text: prompt.text,
            category: .custom,
            isCustom: true
        )
        
        customPrompts.append(customPrompt)
        saveCustomPrompts()
    }
    
    /// Delete custom prompt
    func deleteCustomPrompt(_ prompt: EditPrompt) {
        customPrompts.removeAll { $0.id == prompt.id }
        saveCustomPrompts()
    }
    
    /// Load edit history
    func loadEditHistory() {
        Task {
            editHistory = await storageService.loadEditedImages()
        }
    }
    
    /// Delete edit from history
    func deleteFromHistory(_ editedImage: EditedImage) async {
        let success = await storageService.deleteEditedImage(editedImage)
        if success {
            editHistory.removeAll { $0.id == editedImage.id }
        }
    }
    
    /// Clear custom prompt text
    func clearCustomPrompt() {
        customPrompt = ""
    }
    
    /// Reset edit state
    func resetEdit() {
        originalImage = nil
        editedImage = nil
        selectedPrompt = nil
        customPrompt = ""
        errorMessage = nil
        showingError = false
    }
    
    /// Get popular prompts based on usage
    func getPopularPrompts(limit: Int = 5) -> [EditPrompt] {
        let allPrompts = availablePrompts + customPrompts
        return EditPrompt.popularPrompts(from: allPrompts, limit: limit)
    }
    
    /// Get recent prompts
    func getRecentPrompts(limit: Int = 5) -> [EditPrompt] {
        let allPrompts = availablePrompts + customPrompts
        return EditPrompt.recentPrompts(from: allPrompts, limit: limit)
    }
    
    /// Check if AI service is available
    func isAIServiceAvailable() -> Bool {
        return aiService.isAPIKeyConfigured() && aiService.canUseService()
    }
    
    /// Get remaining uses
    func getRemainingUses() -> Int {
        return aiService.remainingFreeUses
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind AI service properties
        aiService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isProcessing, on: self)
            .store(in: &cancellables)
        
        aiService.$processingError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.handleError(error)
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadPrompts() {
        availablePrompts = EditPrompt.predefinedPrompts
        loadCustomPrompts()
        updateRecentPrompts()
    }
    
    private func loadCustomPrompts() {
        if let data = UserDefaults.standard.data(forKey: "custom_prompts"),
           let prompts = try? JSONDecoder().decode([EditPrompt].self, from: data) {
            customPrompts = prompts
        }
    }
    
    private func saveCustomPrompts() {
        if let data = try? JSONEncoder().encode(customPrompts) {
            UserDefaults.standard.set(data, forKey: "custom_prompts")
        }
    }
    
    private func updatePromptUsage(_ prompt: EditPrompt) {
        let updatedPrompt = prompt.withUpdatedUsage()
        
        // Update in appropriate collection
        if prompt.isCustom {
            if let index = customPrompts.firstIndex(where: { $0.id == prompt.id }) {
                customPrompts[index] = updatedPrompt
                saveCustomPrompts()
            }
        } else {
            if let index = availablePrompts.firstIndex(where: { $0.id == prompt.id }) {
                availablePrompts[index] = updatedPrompt
            }
        }
        
        updateRecentPrompts()
    }
    
    private func updateRecentPrompts() {
        let allPrompts = availablePrompts + customPrompts
        recentPrompts = EditPrompt.recentPrompts(from: allPrompts)
    }
    
    private func saveToHistory(original: UIImage, enhanced: UIImage, prompt: EditPrompt) async {
        let editedImage = EditedImage(
            originalImage: original,
            enhancedImage: enhanced,
            prompt: prompt.text
        )
        
        let success = await storageService.saveEditedImageLocally(editedImage)
        if success {
            editHistory.insert(editedImage, at: 0)
        }
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showingError = true
        isProcessing = false
    }
}

// MARK: - Edit Errors
enum EditError: LocalizedError {
    case enhancementFailed
    case invalidPrompt
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .enhancementFailed:
            return "Failed to enhance image. Please try again."
        case .invalidPrompt:
            return "Please enter a valid prompt."
        case .serviceUnavailable:
            return "AI service is currently unavailable."
        }
    }
}

