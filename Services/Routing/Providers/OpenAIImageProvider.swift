//
//  OpenAIImageProvider.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import os.log

/// Provider for OpenAI DALL-E image editing API
final class OpenAIImageProvider: ImageEditProvider {
    let id: ProviderID = .openAI
    let costClass: CostClass = .budget
    
    private let logger = Logger(subsystem: "PhotoStop", category: "OpenAIImageProvider")
    private let keychain = KeychainService.shared
    private let session: URLSession
    
    // API Configuration
    private let baseURL = "https://api.openai.com/v1"
    private let timeout: TimeInterval = 60.0 // OpenAI can be slower
    
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
            return true // DALL-E excels at these
        case .simpleEnhance, .cleanup:
            return true // Can handle with prompting
        case .bgRemove:
            return false // DALL-E doesn't do background removal well
        case .subjectConsistency, .multiImageFusion:
            return false // Not supported by DALL-E API
        }
    }
    
    func edit(image: UIImage, task: EditTask, options: EditOptions) async throws -> ProviderResult {
        let startTime = Date()
        
        guard let apiKey = getAPIKey() else {
            throw ProviderError.unauthorized
        }
        
        logger.info("Starting OpenAI edit: \(task.rawValue)")
        
        // Prepare the request based on task type
        let resultImage: UIImage
        
        switch task {
        case .restyle, .localObjectEdit, .simpleEnhance, .cleanup:
            resultImage = try await performImageEdit(
                image: image,
                task: task,
                options: options,
                apiKey: apiKey
            )
        default:
            throw ProviderError.notSupported
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        let metadata: [String: Any] = [
            "model": "dall-e-2", // or dall-e-3 based on availability
            "prompt": options.prompt ?? getDefaultPrompt(for: task),
            "processing_time": processingTime,
            "image_size": "\(Int(image.size.width))x\(Int(image.size.height))",
            "task": task.rawValue
        ]
        
        logger.info("OpenAI edit completed in \(processingTime)s")
        
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
            throw ProviderError.configurationError("OpenAI API key not configured")
        }
        
        // Test API connectivity
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
    
    // MARK: - Image Editing Methods
    
    private func performImageEdit(
        image: UIImage,
        task: EditTask,
        options: EditOptions,
        apiKey: String
    ) async throws -> UIImage {
        
        // For DALL-E, we need to use image variations or edits
        // Since DALL-E doesn't have direct image-to-image editing,
        // we'll use the variations endpoint for style changes
        
        let prompt = buildPrompt(for: task, options: options)
        
        if task == .restyle {
            // Use variations for style changes
            return try await performImageVariation(
                image: image,
                prompt: prompt,
                apiKey: apiKey
            )
        } else {
            // For other tasks, use the edit endpoint with a mask
            return try await performImageEditWithMask(
                image: image,
                prompt: prompt,
                options: options,
                apiKey: apiKey
            )
        }
    }
    
    private func performImageVariation(
        image: UIImage,
        prompt: String,
        apiKey: String
    ) async throws -> UIImage {
        
        let url = URL(string: "\(baseURL)/images/variations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Prepare multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image
        if let imageData = prepareImageData(image) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add parameters
        let parameters = [
            "n": "1",
            "size": "1024x1024",
            "response_format": "b64_json"
        ]
        
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        return try await executeRequest(request)
    }
    
    private func performImageEditWithMask(
        image: UIImage,
        prompt: String,
        options: EditOptions,
        apiKey: String
    ) async throws -> UIImage {
        
        let url = URL(string: "\(baseURL)/images/edits")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Prepare multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image
        if let imageData = prepareImageData(image) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add mask (for now, create a simple mask)
        if let maskData = createSimpleMask(for: image) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"mask\"; filename=\"mask.png\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(maskData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add prompt
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(prompt)\r\n".data(using: .utf8)!)
        
        // Add parameters
        let parameters = [
            "n": "1",
            "size": "1024x1024",
            "response_format": "b64_json"
        ]
        
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        return try await executeRequest(request)
    }
    
    private func executeRequest(_ request: URLRequest) async throws -> UIImage {
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
            let openAIResponse = try JSONDecoder().decode(OpenAIImageResponse.self, from: data)
            
            guard let imageData = openAIResponse.data.first?.b64_json,
                  let decodedData = Data(base64Encoded: imageData),
                  let image = UIImage(data: decodedData) else {
                throw ProviderError.decodeFailed
            }
            
            return image
            
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAPIKey() -> String? {
        return keychain.get("openai_api_key")
    }
    
    private func buildPrompt(for task: EditTask, options: EditOptions) -> String {
        let basePrompt = options.prompt ?? getDefaultPrompt(for: task)
        
        // Add task-specific instructions for DALL-E
        let taskInstructions = getTaskInstructions(for: task)
        
        return "\(basePrompt). \(taskInstructions)"
    }
    
    private func getDefaultPrompt(for task: EditTask) -> String {
        switch task {
        case .simpleEnhance:
            return "Enhance this image with better lighting, colors, and clarity"
        case .cleanup:
            return "Clean up and improve this image by removing imperfections"
        case .restyle:
            return "Apply an artistic style transformation to this image"
        case .localObjectEdit:
            return "Make targeted improvements to specific elements in this image"
        default:
            return "Improve and enhance this image"
        }
    }
    
    private func getTaskInstructions(for task: EditTask) -> String {
        switch task {
        case .simpleEnhance:
            return "Focus on natural enhancement without changing the core composition."
        case .cleanup:
            return "Remove unwanted elements while maintaining image integrity."
        case .restyle:
            return "Apply creative styling while preserving the main subject."
        case .localObjectEdit:
            return "Make precise, localized improvements to specific areas."
        default:
            return "Maintain high quality and natural appearance."
        }
    }
    
    private func prepareImageData(_ image: UIImage) -> Data? {
        // Resize to OpenAI requirements (max 4MB, square format preferred)
        let maxSize: CGFloat = 1024
        let size = image.size
        let scale = min(maxSize / size.width, maxSize / size.height)
        
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage.pngData()
    }
    
    private func createSimpleMask(for image: UIImage) -> Data? {
        // Create a simple center mask for editing
        // In a real implementation, you'd use more sophisticated masking
        
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let maskImage = renderer.image { context in
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Create a white circle in the center for editing
            context.cgContext.setFillColor(UIColor.white.cgColor)
            let radius = min(size.width, size.height) * 0.3
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.cgContext.fillEllipse(in: rect)
        }
        
        return maskImage.pngData()
    }
}

// MARK: - API Models

private struct OpenAIImageResponse: Codable {
    let created: Int
    let data: [OpenAIImageData]
}

private struct OpenAIImageData: Codable {
    let b64_json: String?
    let url: String?
}

