//
//  PhotoStopError.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation

/// Comprehensive error types for PhotoStop app
public enum PhotoStopError: LocalizedError, Sendable {
    
    // MARK: - Camera Errors
    case cameraNotAvailable
    case cameraPermissionDenied
    case cameraConfigurationFailed
    case captureSessionFailed
    case photoCaptureFailed
    
    // MARK: - AI Processing Errors
    case aiProcessingFailed(String)
    case providerNotAvailable(String)
    case invalidImageData
    case processingTimeout
    case quotaExceeded
    
    // MARK: - Subscription Errors
    case subscriptionRequired
    case purchaseFailed(String)
    case receiptValidationFailed
    case subscriptionExpired
    case insufficientCredits
    
    // MARK: - Storage Errors
    case saveToPhotosFailed
    case fileSystemError
    case insufficientStorage
    
    // MARK: - Network Errors
    case networkUnavailable
    case apiKeyMissing(String)
    case rateLimitExceeded
    case serverError(Int)
    
    // MARK: - User Errors
    case invalidInput
    case operationCancelled
    case featureNotAvailable
    
    // MARK: - LocalizedError Implementation
    
    public var errorDescription: String? {
        switch self {
        // Camera Errors
        case .cameraNotAvailable:
            return "Camera Not Available"
        case .cameraPermissionDenied:
            return "Camera Permission Denied"
        case .cameraConfigurationFailed:
            return "Camera Configuration Failed"
        case .captureSessionFailed:
            return "Camera Session Failed"
        case .photoCaptureFailed:
            return "Photo Capture Failed"
            
        // AI Processing Errors
        case .aiProcessingFailed(let provider):
            return "AI Processing Failed (\(provider))"
        case .providerNotAvailable(let provider):
            return "\(provider) Not Available"
        case .invalidImageData:
            return "Invalid Image Data"
        case .processingTimeout:
            return "Processing Timeout"
        case .quotaExceeded:
            return "Quota Exceeded"
            
        // Subscription Errors
        case .subscriptionRequired:
            return "Subscription Required"
        case .purchaseFailed(let reason):
            return "Purchase Failed: \(reason)"
        case .receiptValidationFailed:
            return "Receipt Validation Failed"
        case .subscriptionExpired:
            return "Subscription Expired"
        case .insufficientCredits:
            return "Insufficient Credits"
            
        // Storage Errors
        case .saveToPhotosFailed:
            return "Save to Photos Failed"
        case .fileSystemError:
            return "File System Error"
        case .insufficientStorage:
            return "Insufficient Storage"
            
        // Network Errors
        case .networkUnavailable:
            return "Network Unavailable"
        case .apiKeyMissing(let provider):
            return "\(provider) API Key Missing"
        case .rateLimitExceeded:
            return "Rate Limit Exceeded"
        case .serverError(let code):
            return "Server Error (\(code))"
            
        // User Errors
        case .invalidInput:
            return "Invalid Input"
        case .operationCancelled:
            return "Operation Cancelled"
        case .featureNotAvailable:
            return "Feature Not Available"
        }
    }
    
    public var failureReason: String? {
        switch self {
        // Camera Errors
        case .cameraNotAvailable:
            return "The camera is not available on this device or is being used by another app."
        case .cameraPermissionDenied:
            return "PhotoStop needs camera permission to capture photos."
        case .cameraConfigurationFailed:
            return "Failed to configure the camera for photo capture."
        case .captureSessionFailed:
            return "The camera session encountered an error."
        case .photoCaptureFailed:
            return "Failed to capture the photo."
            
        // AI Processing Errors
        case .aiProcessingFailed(let provider):
            return "The \(provider) AI service encountered an error while processing your photo."
        case .providerNotAvailable(let provider):
            return "The \(provider) service is currently unavailable."
        case .invalidImageData:
            return "The image data is corrupted or in an unsupported format."
        case .processingTimeout:
            return "The AI processing took too long and was cancelled."
        case .quotaExceeded:
            return "You've reached your monthly usage limit."
            
        // Subscription Errors
        case .subscriptionRequired:
            return "This feature requires a Pro subscription."
        case .purchaseFailed(let reason):
            return "The purchase could not be completed: \(reason)"
        case .receiptValidationFailed:
            return "Could not verify your purchase with the App Store."
        case .subscriptionExpired:
            return "Your Pro subscription has expired."
        case .insufficientCredits:
            return "You don't have enough credits for this operation."
            
        // Storage Errors
        case .saveToPhotosFailed:
            return "Failed to save the enhanced photo to your Photos library."
        case .fileSystemError:
            return "A file system error occurred."
        case .insufficientStorage:
            return "Not enough storage space available on your device."
            
        // Network Errors
        case .networkUnavailable:
            return "No internet connection is available."
        case .apiKeyMissing(let provider):
            return "The \(provider) API key is not configured."
        case .rateLimitExceeded:
            return "Too many requests. Please try again later."
        case .serverError(let code):
            return "The server returned an error (HTTP \(code))."
            
        // User Errors
        case .invalidInput:
            return "The provided input is invalid."
        case .operationCancelled:
            return "The operation was cancelled by the user."
        case .featureNotAvailable:
            return "This feature is not available on your device."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        // Camera Errors
        case .cameraNotAvailable:
            return "Close other camera apps and try again."
        case .cameraPermissionDenied:
            return "Go to Settings > Privacy & Security > Camera and enable access for PhotoStop."
        case .cameraConfigurationFailed, .captureSessionFailed:
            return "Restart the app and try again."
        case .photoCaptureFailed:
            return "Make sure the camera lens is clean and try again."
            
        // AI Processing Errors
        case .aiProcessingFailed, .providerNotAvailable:
            return "Try again or use a different enhancement option."
        case .invalidImageData:
            return "Try capturing a new photo."
        case .processingTimeout:
            return "Check your internet connection and try again."
        case .quotaExceeded:
            return "Upgrade to Pro for unlimited usage or wait until next month."
            
        // Subscription Errors
        case .subscriptionRequired:
            return "Tap 'Go Pro' to upgrade your subscription."
        case .purchaseFailed:
            return "Check your payment method and try again."
        case .receiptValidationFailed:
            return "Try restoring your purchases or contact support."
        case .subscriptionExpired:
            return "Renew your subscription to continue using Pro features."
        case .insufficientCredits:
            return "Purchase more credits or upgrade to Pro."
            
        // Storage Errors
        case .saveToPhotosFailed:
            return "Check Photos app permissions in Settings."
        case .fileSystemError:
            return "Restart the app and try again."
        case .insufficientStorage:
            return "Free up storage space on your device."
            
        // Network Errors
        case .networkUnavailable:
            return "Connect to Wi-Fi or cellular data and try again."
        case .apiKeyMissing:
            return "Contact support for assistance."
        case .rateLimitExceeded:
            return "Wait a few minutes before trying again."
        case .serverError:
            return "Try again later or contact support if the problem persists."
            
        // User Errors
        case .invalidInput:
            return "Check your input and try again."
        case .operationCancelled:
            return nil
        case .featureNotAvailable:
            return "Update to the latest version of PhotoStop."
        }
    }
}

// MARK: - User-Friendly Extensions

extension PhotoStopError {
    
    /// User-friendly error message for display in UI
    public var userFriendlyMessage: String {
        return errorDescription ?? "An unexpected error occurred"
    }
    
    /// Whether this error should show a retry button
    public var isRetryable: Bool {
        switch self {
        case .cameraNotAvailable, .cameraConfigurationFailed, .captureSessionFailed, .photoCaptureFailed,
             .aiProcessingFailed, .providerNotAvailable, .processingTimeout,
             .networkUnavailable, .rateLimitExceeded, .serverError,
             .fileSystemError:
            return true
        default:
            return false
        }
    }
    
    /// Whether this error should show an upgrade button
    public var requiresUpgrade: Bool {
        switch self {
        case .subscriptionRequired, .quotaExceeded, .subscriptionExpired, .insufficientCredits:
            return true
        default:
            return false
        }
    }
    
    /// Whether this error should show a settings button
    public var requiresSettings: Bool {
        switch self {
        case .cameraPermissionDenied, .saveToPhotosFailed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Categories

extension PhotoStopError {
    
    /// Category of error for analytics and debugging
    public var category: ErrorCategory {
        switch self {
        case .cameraNotAvailable, .cameraPermissionDenied, .cameraConfigurationFailed, .captureSessionFailed, .photoCaptureFailed:
            return .camera
        case .aiProcessingFailed, .providerNotAvailable, .invalidImageData, .processingTimeout, .quotaExceeded:
            return .aiProcessing
        case .subscriptionRequired, .purchaseFailed, .receiptValidationFailed, .subscriptionExpired, .insufficientCredits:
            return .subscription
        case .saveToPhotosFailed, .fileSystemError, .insufficientStorage:
            return .storage
        case .networkUnavailable, .apiKeyMissing, .rateLimitExceeded, .serverError:
            return .network
        case .invalidInput, .operationCancelled, .featureNotAvailable:
            return .user
        }
    }
}

/// Error categories for analytics and debugging
public enum ErrorCategory: String, CaseIterable, Sendable {
    case camera = "camera"
    case aiProcessing = "ai_processing"
    case subscription = "subscription"
    case storage = "storage"
    case network = "network"
    case user = "user"
}

