//
//  GeminiProvider.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import os.log

/// Provider for Google Gemini 2.5 Flash Image API
final class GeminiProvider: ImageEditProvider {
    let id: ProviderID = .gemini
    let costClass: CostClass = .premium
    
    private let logger = Logger(subsystem: "PhotoStop", category: "GeminiProvider")
    private let keychain = KeychainService.shared
    private let session: URLSession
    
    // API Configuration
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "gemini-2.0-flash-exp"
    private let timeout: TimeInterval = 30.0
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - ImageEditProvider Implementation
    
    func supports(_ task: EditTask) -> Bool {
        switch task {
        case .subjectConsistency, .multiImageFusion:
            return true // Gemini excels at these
        case .localObjectEdit, .restyle:
            return true // Good for complex edits
        case .simpleEnhance, .bgRemove, .cleanup:
            return true // Can handle but not optimal
        }
    }
    
    func edit(image: UIImage, task: EditTask, options: EditOptions) async throws -> ProviderResult {
        let startTime = Date()
        
        guard let apiKey = getAPIKey() else {
            throw ProviderError.unauthorized
        }
        
        logger.info("Starting Gemini edit: \(task.rawValue)")
        
        // Prepare the request
        let prompt = buildPrompt(for: task, options: options)
        let imageData = try prepareImageData(image, targetSize: options.targetSize)
        
        // Make API request
        let response = try await makeAPIRequest(
            imageData: imageData,
            prompt: prompt,
            apiKey: apiKey
        )
        
        // Process response
        let resultImage = try processResponse(response)
        
        let processingTime = Date().timeIntervalSince(startTime)
        let metadata: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "processing_time": processingTime,
            "image_size": "\(Int(image.size.width))x\(Int(image.size.height))",
            "task": task.rawValue
        ]
        
        logger.info("Gemini edit completed in \(processingTime)s")
        
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
            throw ProviderError.configurationError("Gemini API key not configured")
        }
        
        // Test API connectivity with a simple request
        do {
            let testURL = URL(string: "\(baseURL)/models")!
            var request = URLRequest(url: testURL)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10.0
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    return // Success
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
        imageData: Data,
        prompt: String,
        apiKey: String
    ) async throws -> GeminiResponse {
        
        let url = URL(string: "\(baseURL)/models/\(model):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        // Prepare request body
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart.text(prompt),
                        GeminiPart.image(imageData)
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.1,
                topK: 32,
                topP: 1.0,
                maxOutputTokens: 4096
            )
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
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
            case 403:
                throw ProviderError.quotaExceeded
            case 500...599:
                throw ProviderError.serviceUnavailable
            default:
                throw ProviderError.unknown(URLError(.badServerResponse))
            }
            
            // Parse response
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            return geminiResponse
            
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
    
    private func processResponse(_ response: GeminiResponse) throws -> UIImage {
        guard let candidate = response.candidates.first,
              let part = candidate.content.parts.first else {
            throw ProviderError.decodeFailed
        }
        
        switch part {
        case .text(let text):
            // If we get text instead of image, it might be an error message
            throw ProviderError.decodeFailed
            
        case .image(let imageData):
            guard let image = UIImage(data: imageData) else {
                throw ProviderError.decodeFailed
            }
            return image
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAPIKey() -> String? {
        return keychain.get("gemini_api_key")
    }
    
    private func buildPrompt(for task: EditTask, options: EditOptions) -> String {
        let basePrompt = options.prompt ?? getDefaultPrompt(for: task)
        
        // Add task-specific instructions
        let taskInstructions = getTaskInstructions(for: task)
        
        return """
        \(basePrompt)
        
        \(taskInstructions)
        
        Please return the edited image directly. Maintain the original image quality and resolution as much as possible.
        """
    }
    
    private func getDefaultPrompt(for task: EditTask) -> String {
        switch task {
        case .simpleEnhance:
            return "Enhance this photo for best quality: adjust lighting, sharpness, color, and reduce noise if needed."
        case .bgRemove:
            return "Remove the background from this image, keeping the main subject intact with clean edges."
        case .cleanup:
            return "Clean up this image by removing unwanted objects, blemishes, or artifacts while preserving the main subject."
        case .restyle:
            return "Apply an artistic style transformation to this image while maintaining the subject's recognizability."
        case .localObjectEdit:
            return "Make localized edits to specific objects in this image as requested."
        case .subjectConsistency:
            return "Ensure the main subject maintains consistent appearance and identity across edits."
        case .multiImageFusion:
            return "Intelligently combine and enhance multiple image elements for optimal quality."
        }
    }
    
    private func getTaskInstructions(for task: EditTask) -> String {
        switch task {
        case .simpleEnhance:
            return "Focus on: exposure correction, color balance, sharpness, noise reduction, and overall image quality."
            
        case .bgRemove:
            return "Carefully preserve subject edges and fine details like hair. Make the background transparent or solid color."
            
        case .cleanup:
            return "Remove only unwanted elements. Preserve image composition and natural appearance."
            
        case .restyle:
            return "Apply creative styling while maintaining subject recognition and image coherence."
            
        case .localObjectEdit:
            return "Make precise, localized changes. Blend edits naturally with surrounding areas."
            
        case .subjectConsistency:
            return "Maintain facial features, body proportions, and identifying characteristics of the main subject."
            
        case .multiImageFusion:
            return "Combine the best elements from multiple frames. Enhance dynamic range and detail."
        }
    }
    
    private func prepareImageData(_ image: UIImage, targetSize: CGSize?) throws -> Data {
        var processedImage = image
        
        // Resize if target size specified
        if let targetSize = targetSize {
            processedImage = image.resized(to: targetSize) ?? image
        }
        
        // Compress for API transmission (max 4MB for Gemini)
        let maxSizeBytes = 4 * 1024 * 1024 // 4MB
        var compressionQuality: CGFloat = 0.9
        var imageData = processedImage.jpegData(compressionQuality: compressionQuality)
        
        while let data = imageData, data.count > maxSizeBytes && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = processedImage.jpegData(compressionQuality: compressionQuality)
        }
        
        guard let finalData = imageData else {
            throw ProviderError.invalidInput
        }
        
        return finalData
    }
}

// MARK: - API Models

private struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private enum GeminiPart: Codable {
    case text(String)
    case image(Data)
    
    private enum CodingKeys: String, CodingKey {
        case text, inlineData
    }
    
    private struct InlineData: Codable {
        let mimeType: String
        let data: String // Base64 encoded
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .image(let data):
            let base64Data = data.base64EncodedString()
            let inlineData = InlineData(mimeType: "image/jpeg", data: base64Data)
            try container.encode(inlineData, forKey: .inlineData)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let text = try? container.decode(String.self, forKey: .text) {
            self = .text(text)
        } else if let inlineData = try? container.decode(InlineData.self, forKey: .inlineData) {
            guard let data = Data(base64Encoded: inlineData.data) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid base64 data")
                )
            }
            self = .image(data)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown part type")
            )
        }
    }
}

private struct GeminiGenerationConfig: Codable {
    let temperature: Double
    let topK: Int
    let topP: Double
    let maxOutputTokens: Int
}

private struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
    let safetyRatings: [GeminiSafetyRating]?
}

private struct GeminiSafetyRating: Codable {
    let category: String
    let probability: String
}

// MARK: - UIImage Extensions

private extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

