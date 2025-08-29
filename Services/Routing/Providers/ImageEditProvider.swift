//
//  ImageEditProvider.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit

/// Result of an edit operation
public enum EditResult {
    case success(image: UIImage, provider: String, processingTime: TimeInterval, metadata: [String: String])
    case failure(Error)
    case requiresUpgrade(reason: UpgradeReason)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var image: UIImage? {
        if case .success(let image, _, _, _) = self { return image }
        return nil
    }
    
    var error: Error? {
        if case .failure(let error) = self { return error }
        return nil
    }
    
    var upgradeReason: UpgradeReason? {
        if case .requiresUpgrade(let reason) = self { return reason }
        return nil
    }
}

/// Reasons why an upgrade might be required
public enum UpgradeReason {
    case insufficientBudgetCredits(required: Int, remaining: Int)
    case insufficientPremiumCredits(required: Int, remaining: Int)
    case premiumFeatureRequired(feature: String)
    case tierLimitReached(tier: UserTier, limit: String)
    
    var displayTitle: String {
        switch self {
        case .insufficientBudgetCredits:
            return "Out of Budget Credits"
        case .insufficientPremiumCredits:
            return "Out of Premium Credits"
        case .premiumFeatureRequired:
            return "Premium Feature"
        case .tierLimitReached:
            return "Tier Limit Reached"
        }
    }
    
    var displayMessage: String {
        switch self {
        case .insufficientBudgetCredits(let required, let remaining):
            return "This edit requires \(required) budget credits, but you only have \(remaining) remaining this month."
        case .insufficientPremiumCredits(let required, let remaining):
            return "This edit requires \(required) premium credits, but you only have \(remaining) remaining this month."
        case .premiumFeatureRequired(let feature):
            return "\(feature) is a premium feature that requires PhotoStop Pro."
        case .tierLimitReached(let tier, let limit):
            return "You've reached the \(limit) limit for \(tier.displayName) users."
        }
    }
    
    var suggestedAction: String {
        switch self {
        case .insufficientBudgetCredits, .insufficientPremiumCredits:
            return "Upgrade to Pro for more credits"
        case .premiumFeatureRequired, .tierLimitReached:
            return "Upgrade to PhotoStop Pro"
        }
    }
}

/// Defines the type of edit task to be performed
public enum EditTask: String, Codable, CaseIterable {
    case simpleEnhance = "simple_enhance"
    case bgRemove = "bg_remove"
    case cleanup = "cleanup"
    case restyle = "restyle"
    case localObjectEdit = "local_object_edit"
    case subjectConsistency = "subject_consistency"
    case multiImageFusion = "multi_image_fusion"
    
    /// Human-readable description of the task
    public var description: String {
        switch self {
        case .simpleEnhance:
            return "Simple Enhancement"
        case .bgRemove:
            return "Background Removal"
        case .cleanup:
            return "Object Cleanup"
        case .restyle:
            return "Style Transfer"
        case .localObjectEdit:
            return "Local Object Edit"
        case .subjectConsistency:
            return "Subject Consistency"
        case .multiImageFusion:
            return "Multi-Image Fusion"
        }
    }
    
    /// Complexity level of the task
    public var complexity: TaskComplexity {
        switch self {
        case .simpleEnhance:
            return .simple
        case .bgRemove, .cleanup:
            return .moderate
        case .restyle, .localObjectEdit:
            return .complex
        case .subjectConsistency, .multiImageFusion:
            return .advanced
        }
    }
}

/// Task complexity levels
public enum TaskComplexity: Int, Comparable {
    case simple = 1
    case moderate = 2
    case complex = 3
    case advanced = 4
    
    public static func < (lhs: TaskComplexity, rhs: TaskComplexity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Options for image editing operations
public struct EditOptions: Sendable {
    public let prompt: String?
    public let targetSize: CGSize?
    public let allowWatermark: Bool
    public let quality: Float // 0.0 to 1.0
    public let preserveMetadata: Bool
    
    public init(
        prompt: String?,
        targetSize: CGSize? = nil,
        allowWatermark: Bool = true,
        quality: Float = 0.8,
        preserveMetadata: Bool = true
    ) {
        self.prompt = prompt
        self.targetSize = targetSize
        self.allowWatermark = allowWatermark
        self.quality = max(0.0, min(1.0, quality))
        self.preserveMetadata = preserveMetadata
    }
    
    /// Default options for simple enhancement
    public static let defaultEnhance = EditOptions(
        prompt: "Enhance photo for best quality: adjust lighting, sharpness, color, denoise if needed.",
        quality: 0.9
    )
    
    /// Default options for background removal
    public static let defaultBgRemove = EditOptions(
        prompt: "Remove background cleanly, preserve subject edges",
        quality: 0.95
    )
}

/// Unique identifier for each provider
public enum ProviderID: String, CaseIterable {
    case gemini = "gemini"
    case openAI = "openai"
    case falFlux = "fal_flux"
    case clipdrop = "clipdrop"
    case onDevice = "on_device"
    
    /// Human-readable name
    public var displayName: String {
        switch self {
        case .gemini:
            return "Gemini 2.5 Flash"
        case .openAI:
            return "OpenAI DALL-E"
        case .falFlux:
            return "Fal.ai FLUX"
        case .clipdrop:
            return "Clipdrop"
        case .onDevice:
            return "On-Device"
        }
    }
}

/// Result from a provider edit operation
public struct ProviderResult: Sendable {
    public let image: UIImage
    public let provider: ProviderID
    public let costClass: CostClass
    public let processingTime: TimeInterval
    public let metadata: [String: Any]
    
    public init(
        image: UIImage,
        provider: ProviderID,
        costClass: CostClass,
        processingTime: TimeInterval = 0,
        metadata: [String: Any] = [:]
    ) {
        self.image = image
        self.provider = provider
        self.costClass = costClass
        self.processingTime = processingTime
        self.metadata = metadata
    }
}

/// Cost classification for operations
public enum CostClass: String, CaseIterable {
    case freeLocal = "free_local"
    case budget = "budget"
    case premium = "premium"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .freeLocal:
            return "Free (On-Device)"
        case .budget:
            return "Budget AI"
        case .premium:
            return "Premium AI"
        }
    }
    
    /// Relative cost weight
    public var weight: Int {
        switch self {
        case .freeLocal:
            return 0
        case .budget:
            return 1
        case .premium:
            return 5
        }
    }
}

/// Protocol that all image edit providers must implement
public protocol ImageEditProvider: Sendable {
    /// Unique identifier for this provider
    var id: ProviderID { get }
    
    /// Cost class for operations from this provider
    var costClass: CostClass { get }
    
    /// Display name for UI
    var displayName: String { get }
    
    /// Whether this provider is currently available
    var isAvailable: Bool { get async }
    
    /// Check if this provider supports a specific task
    func supports(_ task: EditTask) -> Bool
    
    /// Estimate processing time for a task
    func estimatedProcessingTime(for task: EditTask, imageSize: CGSize) -> TimeInterval
    
    /// Perform the edit operation
    func edit(image: UIImage, task: EditTask, options: EditOptions) async throws -> ProviderResult
    
    /// Validate that the provider is properly configured
    func validateConfiguration() async throws
}

/// Errors that can occur during provider operations
public enum ProviderError: Error, LocalizedError {
    case notSupported
    case invalidInput
    case rateLimited(retryAfter: TimeInterval?)
    case serviceUnavailable
    case unauthorized
    case quotaExceeded
    case decodeFailed
    case networkError(Error)
    case configurationError(String)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Operation not supported by this provider"
        case .invalidInput:
            return "Invalid input provided"
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Rate limited. Retry after \(Int(retry)) seconds"
            }
            return "Rate limited. Please try again later"
        case .serviceUnavailable:
            return "Service temporarily unavailable"
        case .unauthorized:
            return "Unauthorized. Check API credentials"
        case .quotaExceeded:
            return "Usage quota exceeded"
        case .decodeFailed:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    /// Whether this error is recoverable with retry
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .serviceUnavailable, .networkError:
            return true
        case .notSupported, .invalidInput, .unauthorized, .quotaExceeded, .decodeFailed, .configurationError, .unknown:
            return false
        }
    }
}

/// Extension to provide default implementations
extension ImageEditProvider {
    public var displayName: String {
        return id.displayName
    }
    
    public var isAvailable: Bool {
        get async {
            do {
                try await validateConfiguration()
                return true
            } catch {
                return false
            }
        }
    }
    
    public func estimatedProcessingTime(for task: EditTask, imageSize: CGSize) -> TimeInterval {
        let baseTime: TimeInterval
        switch costClass {
        case .freeLocal:
            baseTime = 0.5
        case .budget:
            baseTime = 3.0
        case .premium:
            baseTime = 8.0
        }
        
        // Adjust for task complexity
        let complexityMultiplier = Double(task.complexity.rawValue)
        
        // Adjust for image size (rough estimate)
        let pixels = imageSize.width * imageSize.height
        let sizeMultiplier = max(1.0, pixels / (1024 * 1024)) // Base on 1MP
        
        return baseTime * complexityMultiplier * sizeMultiplier
    }
}

