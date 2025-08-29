//
//  ErrorView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// Standardized error display component with recovery actions
struct ErrorView: View {
    let error: Error
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    init(
        error: Error,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Error icon
            Image(systemName: errorIcon)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(errorColor)
            
            // Error content
            VStack(spacing: 12) {
                Text(errorTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                if let onRetry = onRetry {
                    Button(action: onRetry) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue)
                        )
                    }
                }
                
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 10)
        )
        .padding(.horizontal, 32)
    }
    
    private var errorIcon: String {
        if let photoStopError = error as? PhotoStopError {
            switch photoStopError {
            case .cameraNotAvailable, .cameraPermissionDenied:
                return "camera.fill.badge.ellipsis"
            case .networkError:
                return "wifi.exclamationmark"
            case .aiProcessingFailed:
                return "brain.head.profile.badge.exclamationmark"
            case .insufficientCredits:
                return "creditcard.trianglebadge.exclamationmark"
            case .subscriptionRequired:
                return "crown.fill"
            default:
                return "exclamationmark.triangle.fill"
            }
        }
        return "exclamationmark.triangle.fill"
    }
    
    private var errorColor: Color {
        if let photoStopError = error as? PhotoStopError {
            switch photoStopError {
            case .insufficientCredits, .subscriptionRequired:
                return .orange
            case .networkError:
                return .blue
            default:
                return .red
            }
        }
        return .red
    }
    
    private var errorTitle: String {
        if let photoStopError = error as? PhotoStopError {
            return photoStopError.title
        }
        return "Something went wrong"
    }
    
    private var errorMessage: String {
        if let photoStopError = error as? PhotoStopError {
            return photoStopError.message
        }
        return error.localizedDescription
    }
}

/// Inline error view for smaller spaces
struct InlineErrorView: View {
    let error: Error
    let onRetry: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if let onRetry = onRetry {
                Button("Retry", action: onRetry)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.red.opacity(0.1))
                .stroke(.red.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Error banner that appears at the top of the screen
struct ErrorBanner: View {
    let error: Error
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .font(.system(size: 16))
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.red)
        .offset(y: isVisible ? 0 : -100)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            isVisible = true
            
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if isVisible {
                    onDismiss()
                }
            }
        }
    }
}

/// PhotoStop-specific error types
enum PhotoStopError: LocalizedError {
    case cameraNotAvailable
    case cameraPermissionDenied
    case networkError(underlying: Error)
    case aiProcessingFailed(provider: String, reason: String)
    case insufficientCredits(required: Int, remaining: Int)
    case subscriptionRequired(feature: String)
    case imageProcessingFailed
    case socialSharingFailed(platform: String)
    case storageError
    case unknown(underlying: Error)
    
    var title: String {
        switch self {
        case .cameraNotAvailable:
            return "Camera Unavailable"
        case .cameraPermissionDenied:
            return "Camera Permission Required"
        case .networkError:
            return "Network Error"
        case .aiProcessingFailed:
            return "AI Enhancement Failed"
        case .insufficientCredits:
            return "Insufficient Credits"
        case .subscriptionRequired:
            return "Premium Feature"
        case .imageProcessingFailed:
            return "Image Processing Failed"
        case .socialSharingFailed:
            return "Sharing Failed"
        case .storageError:
            return "Storage Error"
        case .unknown:
            return "Unexpected Error"
        }
    }
    
    var message: String {
        switch self {
        case .cameraNotAvailable:
            return "The camera is not available on this device. Please try using the photo library instead."
        case .cameraPermissionDenied:
            return "PhotoStop needs camera access to capture photos. Please enable camera permission in Settings."
        case .networkError(let underlying):
            return "Unable to connect to the internet. Please check your connection and try again.\n\n\(underlying.localizedDescription)"
        case .aiProcessingFailed(let provider, let reason):
            return "Enhancement with \(provider) failed: \(reason). We'll try a different provider automatically."
        case .insufficientCredits(let required, let remaining):
            return "This enhancement requires \(required) credits, but you only have \(remaining) remaining. Upgrade to Pro for more credits."
        case .subscriptionRequired(let feature):
            return "\(feature) is a premium feature. Upgrade to PhotoStop Pro to unlock all AI providers and advanced features."
        case .imageProcessingFailed:
            return "Unable to process the image. Please try with a different photo or check that the image isn't corrupted."
        case .socialSharingFailed(let platform):
            return "Unable to share to \(platform). Please make sure the app is installed and try again."
        case .storageError:
            return "Unable to save the photo. Please check your device storage and try again."
        case .unknown(let underlying):
            return "An unexpected error occurred. Please try again.\n\n\(underlying.localizedDescription)"
        }
    }
    
    var errorDescription: String? {
        return message
    }
}

/// Error handling utilities
extension View {
    /// Show error banner at the top of the view
    func errorBanner(error: Binding<Error?>) -> some View {
        ZStack(alignment: .top) {
            self
            
            if let currentError = error.wrappedValue {
                ErrorBanner(error: currentError) {
                    error.wrappedValue = nil
                }
                .zIndex(1000)
            }
        }
    }
    
    /// Show error overlay
    func errorOverlay(error: Binding<Error?>, onRetry: (() -> Void)? = nil) -> some View {
        ZStack {
            self
            
            if let currentError = error.wrappedValue {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        error.wrappedValue = nil
                    }
                
                ErrorView(
                    error: currentError,
                    onRetry: onRetry,
                    onDismiss: {
                        error.wrappedValue = nil
                    }
                )
                .zIndex(1000)
            }
        }
    }
}

#Preview("Standard Error") {
    ErrorView(
        error: PhotoStopError.aiProcessingFailed(provider: "Gemini", reason: "Network timeout"),
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Credit Error") {
    ErrorView(
        error: PhotoStopError.insufficientCredits(required: 5, remaining: 2),
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Inline Error") {
    VStack(spacing: 20) {
        InlineErrorView(
            error: PhotoStopError.networkError(underlying: URLError(.notConnectedToInternet)),
            onRetry: {}
        )
        
        InlineErrorView(
            error: PhotoStopError.cameraPermissionDenied,
            onRetry: nil
        )
    }
    .padding()
}

