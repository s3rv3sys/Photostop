//
//  AIService.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import Foundation
import GoogleGenerativeAI

/// Service responsible for AI image enhancement using Gemini API
@MainActor
class AIService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var processingError: AIError?
    @Published var usageCount = 0
    @Published var remainingFreeUses = 20
    
    // MARK: - Private Properties
    private var model: GenerativeModel?
    private let keychainService = KeychainService.shared
    private let apiKeyKey = "gemini_api_key"
    
    // MARK: - Constants
    private let freeUsageLimit = 20
    private let maxImageSize: CGFloat = 1024
    
    init() {
        setupModel()
        loadUsageCount()
    }
    
    // MARK: - Public Methods
    
    /// Set the Gemini API key
    func setAPIKey(_ apiKey: String) -> Bool {
        let success = keychainService.save(apiKey, forKey: apiKeyKey)
        if success {
            setupModel()
        }
        return success
    }
    
    /// Get the stored API key
    func getAPIKey() -> String? {
        return keychainService.get(apiKeyKey)
    }
    
    /// Check if API key is configured
    func isAPIKeyConfigured() -> Bool {
        return getAPIKey() != nil
    }
    
    /// Enhance image using AI with default prompt
    func enhanceImage(_ image: UIImage) async -> UIImage? {
        return await enhanceImage(image, prompt: EditPrompt.defaultEnhancement.text)
    }
    
    /// Enhance image using AI with custom prompt
    func enhanceImage(_ image: UIImage, prompt: String) async -> UIImage? {
        guard !isProcessing else { return nil }
        
        // Check usage limits
        if !canUseService() {
            processingError = .usageLimitExceeded
            return nil
        }
        
        guard let model = model else {
            processingError = .apiKeyNotConfigured
            return nil
        }
        
        isProcessing = true
        processingError = nil
        
        do {
            // Prepare image for API
            let processedImage = prepareImageForAPI(image)
            
            // Create the prompt with image
            let fullPrompt = """
            \(prompt)
            
            Please enhance this image and return only the enhanced image without any text or explanations.
            """
            
            // Convert image to data
            guard let imageData = processedImage.jpegData(compressionQuality: 0.8) else {
                throw AIError.imageProcessingError
            }
            
            // Create content with image
            let imageContent = ModelContent.Part.data(mimetype: "image/jpeg", imageData)
            let textContent = ModelContent.Part.text(fullPrompt)
            let content = ModelContent(role: "user", parts: [textContent, imageContent])
            
            // Generate response
            let response = try await model.generateContent([content])
            
            // For now, return the original image as enhanced
            // In a real implementation, you would parse the response and extract the enhanced image
            // The Gemini API doesn't directly return images, so you'd need to use a different approach
            // such as sending the image to a specialized image enhancement API
            
            incrementUsageCount()
            isProcessing = false
            
            // Simulate enhancement by applying basic adjustments
            let enhancedImage = applyBasicEnhancements(to: processedImage, prompt: prompt)
            return enhancedImage
            
        } catch {
            isProcessing = false
            processingError = .networkError(error.localizedDescription)
            return nil
        }
    }
    
    /// Check if service can be used (within limits)
    func canUseService() -> Bool {
        return remainingFreeUses > 0 || isPremiumUser()
    }
    
    /// Reset usage count (for premium users or new month)
    func resetUsageCount() {
        usageCount = 0
        remainingFreeUses = freeUsageLimit
        saveUsageCount()
    }
    
    // MARK: - Private Methods
    
    private func setupModel() {
        guard let apiKey = getAPIKey() else { return }
        
        model = GenerativeModel(
            name: "gemini-1.5-flash",
            apiKey: apiKey,
            generationConfig: GenerationConfig(
                temperature: 0.1,
                topP: 0.8,
                topK: 10,
                maxOutputTokens: 1000
            )
        )
    }
    
    private func prepareImageForAPI(_ image: UIImage) -> UIImage {
        // Resize image if too large
        let size = image.size
        let maxDimension = max(size.width, size.height)
        
        if maxDimension > maxImageSize {
            let scale = maxImageSize / maxDimension
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            return image.resized(to: newSize)
        }
        
        return image
    }
    
    private func applyBasicEnhancements(to image: UIImage, prompt: String) -> UIImage {
        // This is a fallback enhancement when the API doesn't return an image
        // Apply basic Core Image filters based on the prompt
        
        guard let ciImage = CIImage(image: image) else { return image }
        let context = CIContext()
        
        var outputImage = ciImage
        
        // Apply enhancements based on prompt keywords
        let lowercasePrompt = prompt.lowercased()
        
        // Brightness and contrast
        if lowercasePrompt.contains("bright") || lowercasePrompt.contains("lighting") {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)
                filter.setValue(1.1, forKey: kCIInputContrastKey)
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }
        
        // Sharpness
        if lowercasePrompt.contains("sharp") || lowercasePrompt.contains("detail") {
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(0.4, forKey: kCIInputSharpnessKey)
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }
        
        // Vibrance
        if lowercasePrompt.contains("vibrant") || lowercasePrompt.contains("color") {
            if let filter = CIFilter(name: "CIVibrance") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(0.3, forKey: "inputAmount")
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }
        
        // Noise reduction
        if lowercasePrompt.contains("denoise") || lowercasePrompt.contains("noise") {
            if let filter = CIFilter(name: "CINoiseReduction") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(0.02, forKey: "inputNoiseLevel")
                filter.setValue(0.4, forKey: "inputSharpness")
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }
        
        // Convert back to UIImage
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func incrementUsageCount() {
        usageCount += 1
        remainingFreeUses = max(0, freeUsageLimit - usageCount)
        saveUsageCount()
    }
    
    private func loadUsageCount() {
        usageCount = UserDefaults.standard.integer(forKey: "ai_usage_count")
        remainingFreeUses = max(0, freeUsageLimit - usageCount)
    }
    
    private func saveUsageCount() {
        UserDefaults.standard.set(usageCount, forKey: "ai_usage_count")
    }
    
    private func isPremiumUser() -> Bool {
        // Check if user has premium subscription
        // This would integrate with StoreKit2 in a real implementation
        return UserDefaults.standard.bool(forKey: "is_premium_user")
    }
}

// MARK: - AI Errors
enum AIError: LocalizedError {
    case apiKeyNotConfigured
    case networkError(String)
    case imageProcessingError
    case usageLimitExceeded
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "Gemini API key not configured"
        case .networkError(let message):
            return "Network error: \(message)"
        case .imageProcessingError:
            return "Failed to process image"
        case .usageLimitExceeded:
            return "Usage limit exceeded. Upgrade to premium for unlimited access."
        case .invalidResponse:
            return "Invalid response from AI service"
        }
    }
}

