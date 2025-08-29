//
//  EditTypes.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import UIKit
import Foundation

// MARK: - Edit Request

/// Request for image editing/enhancement
public struct EditRequest: Sendable {
    public let image: UIImage
    public let prompt: String
    public let task: EditTask
    public let quality: EditQuality
    public let userId: String?
    
    public init(
        image: UIImage,
        prompt: String,
        task: EditTask = .simpleEnhance,
        quality: EditQuality = .standard,
        userId: String? = nil
    ) {
        self.image = image
        self.prompt = prompt
        self.task = task
        self.quality = quality
        self.userId = userId
    }
}

// MARK: - Edit Result

/// Result of image editing operation
public enum EditResult: Sendable {
    case success(image: UIImage, metadata: EditMetadata)
    case requiresUpgrade(reason: UpgradeReason)
    case failure(error: EditError)
    
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    public var image: UIImage? {
        if case .success(let image, _) = self { return image }
        return nil
    }
    
    public var metadata: EditMetadata? {
        if case .success(_, let metadata) = self { return metadata }
        return nil
    }
}

// MARK: - Edit Task

/// Type of editing task to perform
public enum EditTask: String, CaseIterable, Sendable {
    case simpleEnhance = "simple_enhance"
    case portraitEnhance = "portrait_enhance"
    case hdrEnhance = "hdr_enhance"
    case backgroundRemoval = "background_removal"
    case cleanup = "cleanup"
    case creative = "creative"
    case localEdit = "local_edit"
    
    public var displayName: String {
        switch self {
        case .simpleEnhance: return "Simple Enhancement"
        case .portraitEnhance: return "Portrait Enhancement"
        case .hdrEnhance: return "HDR Enhancement"
        case .backgroundRemoval: return "Background Removal"
        case .cleanup: return "Cleanup"
        case .creative: return "Creative Edit"
        case .localEdit: return "Local Edit"
        }
    }
    
    public var requiresPremium: Bool {
        switch self {
        case .simpleEnhance, .cleanup:
            return false
        case .portraitEnhance, .hdrEnhance, .backgroundRemoval, .creative, .localEdit:
            return true
        }
    }
}

// MARK: - Edit Quality

/// Quality level for editing
public enum EditQuality: String, CaseIterable, Sendable {
    case draft = "draft"
    case standard = "standard"
    case high = "high"
    case ultra = "ultra"
    
    public var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .standard: return "Standard"
        case .high: return "High"
        case .ultra: return "Ultra"
        }
    }
    
    public var creditsRequired: Int {
        switch self {
        case .draft: return 1
        case .standard: return 2
        case .high: return 3
        case .ultra: return 5
        }
    }
}

// MARK: - Edit Metadata

/// Metadata about the editing operation
public struct EditMetadata: Sendable {
    public let provider: String
    public let processingTime: TimeInterval
    public let creditsUsed: Int
    public let quality: Double
    public let timestamp: Date
    
    public init(
        provider: String,
        processingTime: TimeInterval,
        creditsUsed: Int,
        quality: Double,
        timestamp: Date = Date()
    ) {
        self.provider = provider
        self.processingTime = processingTime
        self.creditsUsed = creditsUsed
        self.quality = quality
        self.timestamp = timestamp
    }
}

// MARK: - Upgrade Reason

/// Reason why an upgrade is required
public enum UpgradeReason: String, Sendable {
    case insufficientCredits = "insufficient_credits"
    case premiumFeature = "premium_feature"
    case qualityLimit = "quality_limit"
    case monthlyLimit = "monthly_limit"
    
    public var displayTitle: String {
        switch self {
        case .insufficientCredits: return "Insufficient Credits"
        case .premiumFeature: return "Premium Feature"
        case .qualityLimit: return "Quality Limit"
        case .monthlyLimit: return "Monthly Limit Reached"
        }
    }
    
    public var displayMessage: String {
        switch self {
        case .insufficientCredits:
            return "You don't have enough credits for this operation. Upgrade to Pro or buy more credits."
        case .premiumFeature:
            return "This feature requires PhotoStop Pro. Upgrade to unlock advanced editing capabilities."
        case .qualityLimit:
            return "Higher quality processing requires PhotoStop Pro."
        case .monthlyLimit:
            return "You've reached your monthly limit. Upgrade to Pro for unlimited processing."
        }
    }
}

// MARK: - Edit Error

/// Errors that can occur during editing
public enum EditError: Error, LocalizedError, Sendable {
    case networkError
    case processingFailed
    case invalidImage
    case providerUnavailable
    case timeout
    case quotaExceeded
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed. Please check your internet connection."
        case .processingFailed:
            return "Image processing failed. Please try again."
        case .invalidImage:
            return "Invalid image format. Please select a different image."
        case .providerUnavailable:
            return "AI service is temporarily unavailable. Please try again later."
        case .timeout:
            return "Processing timed out. Please try again."
        case .quotaExceeded:
            return "You've exceeded your usage quota. Please upgrade or try again later."
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Routing Decision

/// Decision made by the routing system
public enum RoutingDecision: Sendable {
    case route(provider: String, cost: Int)
    case requiresUpgrade(reason: UpgradeReason)
    case fallback(provider: String, reason: String)
    
    public var canProceed: Bool {
        if case .route = self { return true }
        if case .fallback = self { return true }
        return false
    }
    
    public var provider: String? {
        switch self {
        case .route(let provider, _): return provider
        case .fallback(let provider, _): return provider
        case .requiresUpgrade: return nil
        }
    }
    
    public var cost: Int {
        switch self {
        case .route(_, let cost): return cost
        case .fallback: return 1 // Fallback is always budget
        case .requiresUpgrade: return 0
        }
    }
}

// MARK: - Processing State

/// State of image processing
public enum ProcessingState: Sendable {
    case idle
    case analyzing
    case enhancing
    case finalizing
    case complete
    case failed(EditError)
    
    public var displayMessage: String {
        switch self {
        case .idle: return ""
        case .analyzing: return "Analyzing image..."
        case .enhancing: return "Enhancing with AI..."
        case .finalizing: return "Finalizing..."
        case .complete: return "Complete!"
        case .failed(let error): return error.localizedDescription
        }
    }
    
    public var progress: Float {
        switch self {
        case .idle: return 0.0
        case .analyzing: return 0.2
        case .enhancing: return 0.7
        case .finalizing: return 0.9
        case .complete: return 1.0
        case .failed: return 0.0
        }
    }
}

// MARK: - Capture State

/// State of camera capture
public enum CaptureState: Sendable {
    case idle
    case preparing
    case capturing
    case processing
    case complete
    case failed(CameraError)
    
    public var displayMessage: String {
        switch self {
        case .idle: return ""
        case .preparing: return "Preparing..."
        case .capturing: return "Capturing..."
        case .processing: return "Processing..."
        case .complete: return "Complete!"
        case .failed(let error): return error.localizedDescription
        }
    }
}

// MARK: - Camera Error

/// Errors that can occur during camera operations
public enum CameraError: Error, LocalizedError, Sendable {
    case notAuthorized
    case configurationFailed
    case captureFailed
    case deviceUnavailable
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Camera access is required to capture photos."
        case .configurationFailed:
            return "Failed to configure camera. Please try again."
        case .captureFailed:
            return "Failed to capture photo. Please try again."
        case .deviceUnavailable:
            return "Camera is not available on this device."
        case .unknown(let message):
            return message
        }
    }
}

