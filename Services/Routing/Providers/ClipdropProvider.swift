//
//  ClipdropProvider.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import os.log

/// Provider for Clipdrop API (specialized in background removal and cleanup)
final class ClipdropProvider: ImageEditProvider {
    let id: ProviderID = .clipdrop
    let costClass: CostClass = .budget
    
    private let logger = Logger(subsystem: "PhotoStop", category: "ClipdropProvider")
    private let keychain = KeychainService.shared
    private let session: URLSession
    
    // API Configuration
    private let baseURL = "https://clipdrop-api.co"
    private let timeout: TimeInterval = 30.0
    
    // Available Clipdrop endpoints
    private enum ClipdropEndpoint: String {
        case removeBackground = "remove-background/v1"
        case cleanup = "cleanup/v1"
        case uncrop = "uncrop/v1"
        case reimagine = "reimagine/v1"
        
        var path: String {
            return "/\(self.rawValue)"
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
        case .bgRemove:
            return true // Primary use case
        case .cleanup:
            return true // Good for object removal
        case .simpleEnhance:
            return false // Not Clipdrop's strength
        case .restyle, .localObjectEdit, .subjectConsistency, .multiImageFusion:
            return false // Not supported
        }
    }
    
    func edit(image: UIImage, task: EditTask, options: EditOptions) async throws -> ProviderResult {
        let startTime = Date()
        
        guard let apiKey = getAPIKey() else {
            throw ProviderError.unauthorized
        }
        
        logger.info("Starting Clipdrop edit: \(task.rawValue)")
        
        // Select appropriate endpoint based on task
        let endpoint = selectEndpoint(for: task)
        
        // Prepare the request
        let imageData = try prepareImageData(image, targetSize: options.targetSize)
        
        // Make API request
        let resultImage = try await makeAPIRequest(
            endpoint: endpoint,
            imageData: imageData,
            task: task,
            options: options,
            apiKey: apiKey
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        let metadata: [String: Any] = [
            "endpoint": endpoint.rawValue,
            "processing_time": processingTime,
            "image_size": "\(Int(image.size.width))x\(Int(image.size.height))",
            "task": task.rawValue
        ]
        
        logger.info("Clipdrop edit completed in \(processingTime)s")
        
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
            throw ProviderError.configurationError("Clipdrop API key not configured")
        }
        
        // Test API connectivity with a simple request
        do {
            let testURL = URL(string: "\(baseURL)/remove-background/v1")!
            var request = URLRequest(url: testURL)
            request.httpMethod = "POST"
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.timeoutInterval = 10.0
            
            // Send minimal test (will fail but should return proper error codes)
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299, 400: // 400 expected for empty request
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
        endpoint: ClipdropEndpoint,
        imageData: Data,
        task: EditTask,
        options: EditOptions,
        apiKey: String
    ) async throws -> UIImage {
        
        let url = URL(string: "\(baseURL)\(endpoint.path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        // Prepare multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image_file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add endpoint-specific parameters
        switch endpoint {
        case .removeBackground:
            // No additional parameters needed
            break
            
        case .cleanup:
            // Add mask if we have specific cleanup instructions
            if let maskData = createCleanupMask(for: task, options: options) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"mask_file\"; filename=\"mask.png\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
                body.append(maskData)
                body.append("\r\n".data(using: .utf8)!)
            }
            
        case .uncrop:
            // Add extend parameters
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"extend_left\"\r\n\r\n".data(using: .utf8)!)
            body.append("0\r\n".data(using: .utf8)!)
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"extend_right\"\r\n\r\n".data(using: .utf8)!)
            body.append("0\r\n".data(using: .utf8)!)
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"extend_up\"\r\n\r\n".data(using: .utf8)!)
            body.append("0\r\n".data(using: .utf8)!)
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"extend_down\"\r\n\r\n".data(using: .utf8)!)
            body.append("0\r\n".data(using: .utf8)!)
            
        case .reimagine:
            // Add prompt if available
            if let prompt = options.prompt {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(prompt)\r\n".data(using: .utf8)!)
            }
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
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
            
            // Parse image response
            guard let image = UIImage(data: data) else {
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
        return keychain.get("clipdrop_api_key")
    }
    
    private func selectEndpoint(for task: EditTask) -> ClipdropEndpoint {
        switch task {
        case .bgRemove:
            return .removeBackground
        case .cleanup:
            return .cleanup
        default:
            return .removeBackground // Default fallback
        }
    }
    
    private func createCleanupMask(for task: EditTask, options: EditOptions) -> Data? {
        // For now, return nil - in a real implementation, you'd analyze the prompt
        // to create appropriate masks for cleanup operations
        
        // Example: if prompt contains "remove person" or "remove object",
        // you could use object detection to create a mask
        
        return nil
    }
    
    private func prepareImageData(_ image: UIImage, targetSize: CGSize?) throws -> Data {
        var processedImage = image
        
        // Clipdrop has size limits (typically 10MB, max 4096x4096)
        let maxDimension: CGFloat = 4096
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
        
        // Use high quality JPEG for Clipdrop
        guard let imageData = processedImage.jpegData(compressionQuality: 0.95) else {
            throw ProviderError.invalidInput
        }
        
        // Check size limit (10MB)
        let maxSizeBytes = 10 * 1024 * 1024
        if imageData.count > maxSizeBytes {
            // Try with lower quality
            guard let compressedData = processedImage.jpegData(compressionQuality: 0.8) else {
                throw ProviderError.invalidInput
            }
            
            if compressedData.count > maxSizeBytes {
                throw ProviderError.invalidInput
            }
            
            return compressedData
        }
        
        return imageData
    }
    
    // MARK: - Specialized Methods
    
    /// Remove background from image
    func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let apiKey = getAPIKey() else {
            throw ProviderError.unauthorized
        }
        
        let imageData = try prepareImageData(image, targetSize: nil)
        
        return try await makeAPIRequest(
            endpoint: .removeBackground,
            imageData: imageData,
            task: .bgRemove,
            options: EditOptions(prompt: nil),
            apiKey: apiKey
        )
    }
    
    /// Clean up image by removing unwanted objects
    func cleanup(image: UIImage, mask: UIImage? = nil) async throws -> UIImage {
        guard let apiKey = getAPIKey() else {
            throw ProviderError.unauthorized
        }
        
        let imageData = try prepareImageData(image, targetSize: nil)
        
        return try await makeAPIRequest(
            endpoint: .cleanup,
            imageData: imageData,
            task: .cleanup,
            options: EditOptions(prompt: nil),
            apiKey: apiKey
        )
    }
    
    /// Extend image boundaries (uncrop)
    func uncrop(
        image: UIImage,
        extendLeft: Int = 0,
        extendRight: Int = 0,
        extendUp: Int = 0,
        extendDown: Int = 0
    ) async throws -> UIImage {
        guard let apiKey = getAPIKey() else {
            throw ProviderError.unauthorized
        }
        
        let imageData = try prepareImageData(image, targetSize: nil)
        
        // This would need custom implementation for uncrop parameters
        return try await makeAPIRequest(
            endpoint: .uncrop,
            imageData: imageData,
            task: .localObjectEdit,
            options: EditOptions(prompt: nil),
            apiKey: apiKey
        )
    }
}

