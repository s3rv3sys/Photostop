//
//  AccessibilityService.swift
//  PhotoStop
//
//  Accessibility and inclusive design service for App Store compliance
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import UIKit
import SwiftUI

/// Service for accessibility features and inclusive design
final class AccessibilityService {
    
    static let shared = AccessibilityService()
    private init() {}
    
    // MARK: - VoiceOver Support
    
    /// Generate accessibility label for camera capture button
    func cameraButtonAccessibilityLabel(isProcessing: Bool) -> String {
        if isProcessing {
            return "Processing photo with AI enhancement. Please wait."
        }
        return "Capture photo for AI enhancement. Double tap to take photo."
    }
    
    /// Generate accessibility label for enhanced image result
    func enhancedImageAccessibilityLabel(originalPrompt: String?, provider: String?) -> String {
        var label = "Enhanced photo result"
        
        if let prompt = originalPrompt {
            label += " using prompt: \(prompt)"
        }
        
        if let provider = provider {
            label += " processed with \(provider)"
        }
        
        label += ". Double tap to view full screen, swipe up for sharing options."
        return label
    }
    
    /// Generate accessibility hint for subscription buttons
    func subscriptionButtonAccessibilityHint(planType: String, price: String) -> String {
        return "Subscribe to \(planType) plan for \(price). Double tap to purchase."
    }
    
    /// Generate accessibility label for credit usage
    func creditUsageAccessibilityLabel(remaining: Int, total: Int, type: String) -> String {
        return "\(remaining) of \(total) \(type) credits remaining this month"
    }
    
    // MARK: - Dynamic Type Support
    
    /// Get scaled font for accessibility
    func scaledFont(style: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        let font = UIFont.systemFont(ofSize: descriptor.pointSize, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }
    
    /// Check if large text is enabled
    var isLargeTextEnabled: Bool {
        return UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
    }
    
    // MARK: - Motion Reduction
    
    /// Check if reduce motion is enabled
    var isReduceMotionEnabled: Bool {
        return UIAccessibility.isReduceMotionEnabled
    }
    
    /// Get animation duration respecting reduce motion
    func animationDuration(default defaultDuration: TimeInterval) -> TimeInterval {
        return isReduceMotionEnabled ? 0.1 : defaultDuration
    }
    
    /// Get spring animation parameters respecting reduce motion
    func springAnimation(response: Double = 0.5, dampingFraction: Double = 0.8) -> Animation {
        if isReduceMotionEnabled {
            return .easeInOut(duration: 0.2)
        }
        return .spring(response: response, dampingFraction: dampingFraction)
    }
    
    // MARK: - High Contrast Support
    
    /// Check if increase contrast is enabled
    var isIncreaseContrastEnabled: Bool {
        return UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    /// Get color with contrast adjustment
    func contrastAdjustedColor(_ color: Color, darkVariant: Color? = nil) -> Color {
        if isIncreaseContrastEnabled {
            return darkVariant ?? color
        }
        return color
    }
    
    // MARK: - VoiceOver Navigation
    
    /// Configure accessibility elements for camera view
    func configureCameraViewAccessibility() -> [AccessibilityElement] {
        return [
            AccessibilityElement(
                label: "Camera preview",
                hint: "Live camera feed for photo capture",
                traits: [.image, .updatesFrequently]
            ),
            AccessibilityElement(
                label: "Capture button",
                hint: "Double tap to capture photo for AI enhancement",
                traits: [.button]
            ),
            AccessibilityElement(
                label: "Settings button",
                hint: "Double tap to open app settings",
                traits: [.button]
            ),
            AccessibilityElement(
                label: "Gallery button",
                hint: "Double tap to view previous enhancements",
                traits: [.button]
            )
        ]
    }
    
    /// Configure accessibility for result view
    func configureResultViewAccessibility(hasBeforeAfter: Bool) -> [AccessibilityElement] {
        var elements = [
            AccessibilityElement(
                label: "Enhanced photo",
                hint: "Result of AI photo enhancement. Double tap to view full screen.",
                traits: [.image, .button]
            )
        ]
        
        if hasBeforeAfter {
            elements.append(
                AccessibilityElement(
                    label: "Compare toggle",
                    hint: "Double tap to toggle between original and enhanced photo",
                    traits: [.button]
                )
            )
        }
        
        elements.append(contentsOf: [
            AccessibilityElement(
                label: "Save to Photos",
                hint: "Double tap to save enhanced photo to your photo library",
                traits: [.button]
            ),
            AccessibilityElement(
                label: "Share",
                hint: "Double tap to share enhanced photo",
                traits: [.button]
            ),
            AccessibilityElement(
                label: "Instagram Stories",
                hint: "Double tap to share directly to Instagram Stories",
                traits: [.button]
            ),
            AccessibilityElement(
                label: "TikTok",
                hint: "Double tap to share to TikTok",
                traits: [.button]
            )
        ])
        
        return elements
    }
    
    // MARK: - Accessibility Announcements
    
    /// Announce processing status to VoiceOver users
    func announceProcessingStatus(_ status: ProcessingStatus) {
        let announcement: String
        
        switch status {
        case .starting:
            announcement = "Starting AI photo enhancement"
        case .analyzing:
            announcement = "Analyzing photo composition"
        case .enhancing:
            announcement = "Applying AI enhancements"
        case .completed:
            announcement = "Photo enhancement completed successfully"
        case .failed(let error):
            announcement = "Enhancement failed: \(error)"
        }
        
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    /// Announce subscription status changes
    func announceSubscriptionChange(_ change: SubscriptionChange) {
        let announcement: String
        
        switch change {
        case .purchased(let plan):
            announcement = "Successfully subscribed to \(plan). You now have access to premium features."
        case .restored:
            announcement = "Subscription restored successfully"
        case .expired:
            announcement = "Subscription has expired. Some features may be limited."
        case .creditsAdded(let amount):
            announcement = "\(amount) premium credits added to your account"
        }
        
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    // MARK: - Keyboard Navigation
    
    /// Check if full keyboard access is enabled
    var isFullKeyboardAccessEnabled: Bool {
        return UIAccessibility.isFullKeyboardAccessEnabled
    }
    
    /// Configure keyboard shortcuts for main actions
    func configureKeyboardShortcuts() -> [KeyboardShortcut] {
        return [
            KeyboardShortcut(.space, modifiers: [], action: "Capture Photo"),
            KeyboardShortcut(.return, modifiers: [.command], action: "Save Photo"),
            KeyboardShortcut("s", modifiers: [.command], action: "Share Photo"),
            KeyboardShortcut("g", modifiers: [.command], action: "Open Gallery"),
            KeyboardShortcut(",", modifiers: [.command], action: "Open Settings")
        ]
    }
    
    // MARK: - Screen Reader Support
    
    /// Format credit information for screen readers
    func formatCreditsForScreenReader(budget: Int, premium: Int, tier: String) -> String {
        return "Current plan: \(tier). Budget credits: \(budget) remaining. Premium credits: \(premium) remaining."
    }
    
    /// Format processing time for screen readers
    func formatProcessingTimeForScreenReader(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return "Processing completed in less than one second"
        } else if seconds < 60 {
            return "Processing completed in \(Int(seconds)) seconds"
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "Processing completed in \(minutes) minutes and \(remainingSeconds) seconds"
        }
    }
}

// MARK: - Supporting Types

struct AccessibilityElement {
    let label: String
    let hint: String
    let traits: UIAccessibilityTraits
}

enum ProcessingStatus {
    case starting
    case analyzing
    case enhancing
    case completed
    case failed(String)
}

enum SubscriptionChange {
    case purchased(String)
    case restored
    case expired
    case creditsAdded(Int)
}

struct KeyboardShortcut {
    let key: String
    let modifiers: [KeyModifier]
    let action: String
    
    init(_ key: String, modifiers: [KeyModifier], action: String) {
        self.key = key
        self.modifiers = modifiers
        self.action = action
    }
}

enum KeyModifier {
    case command
    case option
    case control
    case shift
}

// MARK: - SwiftUI Extensions

extension AccessibilityService {
    
    /// Create accessible button with proper labels and hints
    func accessibleButton<Content: View>(
        label: String,
        hint: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }
    
    /// Create accessible image with description
    func accessibleImage(
        image: Image,
        description: String,
        isDecorative: Bool = false
    ) -> some View {
        image
            .accessibilityLabel(isDecorative ? "" : description)
            .accessibilityAddTraits(isDecorative ? [] : .isImage)
            .accessibilityHidden(isDecorative)
    }
    
    /// Create accessible progress indicator
    func accessibleProgressView(
        progress: Double,
        label: String
    ) -> some View {
        ProgressView(value: progress)
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}

