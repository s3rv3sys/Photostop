//
//  FalFluxProvider.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import os.log

/// Provider for Fal.ai FLUX models (fast and cost-effective image generation)
final class FalFluxProvider: ImageEditProvider {
    let id: ProviderID = .falFlux
    let costClass: CostClass = .budget
    
    private let logger = Logger(subsystem: "PhotoStop", category: "FalFluxProvider")
    private let keychain = KeychainService.shared
    private let session: URLSession
    
    // API Configuration
    private let baseURL = "https://fal.run/fal-ai"
    private let timeout: TimeInterval = 45.0
    
    // Model selection based on task
    private enum FluxModel: String {
        case schnell = "flux/schnell" // Fastest, good for simple edits
        case dev = "flux/dev" // Better quality, slightly slower
        case pro = "flux-pro" // Best quality, most expensive
        
        var endpoint: String {
            return self.rawValue
        }
    }
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - ImageEditProvider Implementation
    
    func supports(_ task: EditTask) -> Bool {
        switch task {
        case .restyle, .localObjectEdit:
            return true // FLUX excels at creative transformations
        case .simpleEnhance:
            return true // Can handle with img2img
        case .cleanup:
            return true // Good for inpainting-style cleanup
        case .bgRemove, .subjectConsistency, .multiImageFusion:
            return false // Not optimal for these tasks
        }
    }
    
    func edit(image: UIImage, task: EditTask, options: EditOptions) async throws -> ProviderResult {
        let startTime = Date()
        
        guard let apiKey = getAPIKey() else {
            throw ProviderError.unauthorized
        }
        
        logger.info("Starting Fal.ai FLUX edit: \(task.rawValue)")
        
        // Select appropriate model based on task and quality requirements
        let model = selectModel(for: task, quality: options.quality)
        
        // Prepare the request
        let prompt = buildPrompt(for: task, options: options)
        let imageData = try prepareImageData(image, targetSize: options.targetSize)
        
        // Make API request
        let response = try await makeAPIRequest(
            model: model,
            imageData: imageData,
            prompt: prompt,
            options: options,
            apiKey: apiKey
        )
        
        // Process response
        let resultImage = try await processResponse(response)
        
        let processingTime = Date().timeIntervalSince(startTime)
        let metadata: [String: Any] = [
            "model": model.rawValue,
            "prompt": prompt,
            "processing_time": processingTime,
            "image_size": "\(Int(image.size.width))x\(Int(image.size.height))",
            "task": task.rawValue,
            "strength": getStrength(for: task)
        ]
        
        logger.info("Fal.ai FLUX edit completed in \(processingTime)s")
        
        return ProviderResult(
            image: resultImage,
            provider: id,
            costClass: costClass,
            processingTime: processingTime,
            metadata: metadata
        )
    }
    
    func validateConfiguration() async throws {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            throw ProviderError.configurationError("Fal.ai API key not configured")
        }
        
        // Test API connectivity
        do {
            let testURL = URL(string: "\(baseURL)/flux/schnell")!
            var request = URLRequest(url: testURL)
            request.httpMethod = "POST"
            request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10.0
            
            // Send a minimal test request
            let testBody = [
                "prompt": "test",
                "image_size": "square_hd",
                "num_inference_steps": 1
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: testBody)
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299, 400: // 400 is expected for minimal test
                    return // Success or expected validation error
                case 401:
                    throw ProviderError.unauthorized
                case 429:
                    throw ProviderError.rateLimited(retryAfter: nil)
                default:
                    throw ProviderError.serviceUnavailable
                }
            }
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
    
    // MARK: - API Communication
    
    private func makeAPIRequest(
        model: FluxModel,
        imageData: Data,
        prompt: String,
        options: EditOptions,
        apiKey: String
    ) async throws -> FalResponse {
        
        let url = URL(string: "\(baseURL)/\(model.endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare request body
        let base64Image = imageData.base64EncodedString()
        let imageUrl = "data:image/jpeg;base64,\(base64Image)"
        
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "image_url": imageUrl,
            "strength": getStrength(for: classifyTask(from: prompt)),
            "guidance_scale": getGuidanceScale(for: options.quality),
            "num_inference_steps": getInferenceSteps(for: model, quality: options.quality),
            "image_size": getImageSize(from: options.targetSize),
            "num_images": 1,
            "enable_safety_checker": true,
            "seed": nil // Random seed for variety
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw ProviderError.invalidInput
        }
        
        // Make request
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.networkError(URLError(.badServerResponse))
            }
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                break // Success
            case 400:
                throw ProviderError.invalidInput
            case 401:
                throw ProviderError.unauthorized
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { TimeInterval($0) }
                throw ProviderError.rateLimited(retryAfter: retryAfter)
            case 402:
                throw ProviderError.quotaExceeded
            case 500...599:
                throw ProviderError.serviceUnavailable
            default:
                throw ProviderError.unknown(URLError(.badServerResponse))
            }
            
            // Parse response
            let falResponse = try JSONDecoder().decode(FalResponse.self, from: data)
            return falResponse
            
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
    
    private func processResponse(_ response: FalResponse) async throws -> UIImage {
        guard let imageUrl = response.images.first?.url else {
            throw ProviderError.decodeFailed
        }
        
        // Download the generated image
        guard let url = URL(string: imageUrl) else {
            throw ProviderError.decodeFailed
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else {
                throw ProviderError.decodeFailed
            }
            return image
        } catch {
            throw ProviderError.networkError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAPIKey() -> String? {
        return keychain.get("fal_api_key")
    }
    
    private func selectModel(for task: EditTask, quality: Float) -> FluxModel {
        // Select model based on task complexity and quality requirements
        switch task {
        case .simpleEnhance:
            return quality > 0.8 ? .dev : .schnell
        case .cleanup:
            return .dev // Better for inpainting-style tasks
        case .restyle, .localObjectEdit:
            return quality > 0.9 ? .pro : .dev
        default:
            return .schnell
        }
    }
    
    private func buildPrompt(for task: EditTask, options: EditOptions) -> String {
        let basePrompt = options.prompt ?? getDefaultPrompt(for: task)
        
        // Add FLUX-specific instructions
        let fluxInstructions = getFluxInstructions(for: task)
        
        return "\(basePrompt), \(fluxInstructions)"
    }
    
    private func getDefaultPrompt(for task: EditTask) -> String {
        switch task {
        case .simpleEnhance:
            return "enhance this photo with better lighting, colors, and sharpness"
        case .cleanup:
            return "clean up this image by removing unwanted elements and imperfections"
        case .restyle:
            return "apply an artistic style transformation to this image"
        case .localObjectEdit:
            return "improve and modify specific elements in this image"
        default:
            return "enhance and improve this image"
        }
    }
    
    private func getFluxInstructions(for task: EditTask) -> String {
        let baseInstructions = "high quality, detailed, professional photography"
        
        switch task {
        case .simpleEnhance:
            return "\(baseInstructions), natural enhancement, preserve original composition"
        case .cleanup:
            return "\(baseInstructions), clean composition, remove distractions"
        case .restyle:
            return "\(baseInstructions), artistic style, creative transformation"
        case .localObjectEdit:
            return "\(baseInstructions), precise editing, seamless integration"
        default:
            return baseInstructions
        }
    }
    
    private func getStrength(for task: EditTask) -> Double {
        // Strength controls how much the image changes
        switch task {
        case .simpleEnhance:
            return 0.3 // Subtle changes
        case .cleanup:
            return 0.5 // Moderate changes
        case .restyle:
            return 0.7 // Significant style changes
        case .localObjectEdit:
            return 0.6 // Targeted changes
        default:
            return 0.5
        }
    }
    
    private func getGuidanceScale(for quality: Float) -> Double {
        // Higher guidance scale = more adherence to prompt
        return Double(7.0 + (quality * 3.0)) // Range: 7.0 to 10.0
    }
    
    private func getInferenceSteps(for model: FluxModel, quality: Float) -> Int {
        switch model {
        case .schnell:
            return quality > 0.8 ? 8 : 4 // Fast model, fewer steps
        case .dev:
            return quality > 0.8 ? 25 : 15 // Balanced
        case .pro:
            return quality > 0.8 ? 50 : 30 // High quality, more steps
        }
    }
    
    private func getImageSize(from targetSize: CGSize?) -> String {
        guard let size = targetSize else {
            return "square_hd" // Default 1024x1024
        }
        
        let width = Int(size.width)
        let height = Int(size.height)
        
        // Map to Fal.ai size options
        if width == height {
            return width <= 512 ? "square" : "square_hd"
        } else if width > height {
            return width <= 768 ? "landscape" : "landscape_16_9"
        } else {
            return height <= 768 ? "portrait" : "portrait_16_9"
        }
    }
    
    private func classifyTask(from prompt: String) -> EditTask {
        let lowercased = prompt.lowercased()
        
        if lowercased.contains("style") || lowercased.contains("artistic") {
            return .restyle
        } else if lowercased.contains("remove") || lowercased.contains("clean") {
            return .cleanup
        } else if lowercased.contains("enhance") || lowercased.contains("improve") {
            return .simpleEnhance
        } else {
            return .localObjectEdit
        }
    }
    
    private func prepareImageData(_ image: UIImage, targetSize: CGSize?) throws -> Data {
        var processedImage = image
        
        // Resize if needed (Fal.ai has size limits)
        let maxDimension: CGFloat = 1024
        let size = image.size
        
        if size.width > maxDimension || size.height > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            let newSize = CGSize(
                width: size.width * scale,
                height: size.height * scale
            )
            
            let renderer = UIGraphicsImageRenderer(size: newSize)
            processedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        
        // Apply target size if specified
        if let targetSize = targetSize {
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            processedImage = renderer.image { _ in
                processedImage.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }
        
        // Compress for API transmission
        guard let imageData = processedImage.jpegData(compressionQuality: 0.9) else {
            throw ProviderError.invalidInput
        }
        
        return imageData
    }
}

// MARK: - API Models

private struct FalResponse: Codable {
    let images: [FalImage]
    let timings: FalTimings?
    let seed: Int?
    let has_nsfw_concepts: [Bool]?
}

private struct FalImage: Codable {
    let url: String
    let width: Int
    let height: Int
    let content_type: String
}

private struct FalTimings: Codable {
    let inference: Double?
    let total: Double?
}

