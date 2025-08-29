//
//  UserProfile.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation

/// User profile supporting both anonymous and signed-in states
public struct UserProfile: Codable, Sendable, Equatable {
    
    /// Authentication state
    public enum AuthState: String, Codable, CaseIterable {
        case anonymous = "anonymous"
        case signedIn = "signedIn"
        
        var displayName: String {
            switch self {
            case .anonymous: return "Anonymous"
            case .signedIn: return "Signed In"
            }
        }
    }
    
    // MARK: - Properties
    
    /// Current authentication state
    public var authState: AuthState
    
    /// Unique user identifier (anonymous UUID or Apple ID)
    public var userId: String
    
    /// Display name from Apple ID or custom
    public var displayName: String?
    
    /// Email from Apple ID
    public var email: String?
    
    /// Avatar URL (future use)
    public var avatarURL: URL?
    
    /// Current subscription tier
    public var tier: String // "free" or "pro"
    
    /// Account creation date
    public var createdAt: Date
    
    /// Last seen date for analytics
    public var lastSeen: Date
    
    // MARK: - Computed Properties
    
    /// Display name with fallback
    public var effectiveDisplayName: String {
        if let displayName = displayName, !displayName.isEmpty {
            return displayName
        }
        
        if let email = email {
            return email.components(separatedBy: "@").first ?? "User"
        }
        
        return authState == .anonymous ? "Anonymous User" : "User"
    }
    
    /// Avatar initials for monogram
    public var avatarInitials: String {
        if let displayName = displayName, !displayName.isEmpty {
            let components = displayName.components(separatedBy: " ")
            if components.count >= 2 {
                return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
            } else {
                return String(displayName.prefix(2)).uppercased()
            }
        }
        
        if let email = email {
            return String(email.prefix(2)).uppercased()
        }
        
        return "AU" // Anonymous User
    }
    
    /// Is user signed in with Apple
    public var isSignedIn: Bool {
        return authState == .signedIn
    }
    
    /// Is user on Pro tier
    public var isPro: Bool {
        return tier == "pro"
    }
    
    // MARK: - Initialization
    
    public init(
        authState: AuthState,
        userId: String,
        displayName: String? = nil,
        email: String? = nil,
        avatarURL: URL? = nil,
        tier: String = "free",
        createdAt: Date = Date(),
        lastSeen: Date = Date()
    ) {
        self.authState = authState
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.avatarURL = avatarURL
        self.tier = tier
        self.createdAt = createdAt
        self.lastSeen = lastSeen
    }
    
    // MARK: - Factory Methods
    
    /// Create anonymous user profile
    public static func anonymous(userId: String) -> UserProfile {
        return UserProfile(
            authState: .anonymous,
            userId: userId,
            tier: "free"
        )
    }
    
    /// Create signed-in user profile
    public static func signedIn(
        userId: String,
        displayName: String?,
        email: String?,
        tier: String = "free"
    ) -> UserProfile {
        return UserProfile(
            authState: .signedIn,
            userId: userId,
            displayName: displayName,
            email: email,
            tier: tier
        )
    }
    
    // MARK: - Mutation Methods
    
    /// Update last seen timestamp
    public mutating func updateLastSeen() {
        lastSeen = Date()
    }
    
    /// Update subscription tier
    public mutating func updateTier(_ newTier: String) {
        tier = newTier
    }
    
    /// Update profile information
    public mutating func updateProfile(displayName: String?, email: String?) {
        self.displayName = displayName
        self.email = email
    }
    
    /// Convert to signed-in state
    public mutating func upgradeToSignedIn(
        newUserId: String,
        displayName: String?,
        email: String?
    ) {
        authState = .signedIn
        userId = newUserId
        self.displayName = displayName
        self.email = email
        updateLastSeen()
    }
    
    /// Convert to anonymous state
    public mutating func downgradeToAnonymous(anonymousId: String) {
        authState = .anonymous
        userId = anonymousId
        displayName = nil
        email = nil
        avatarURL = nil
        tier = "free" // Reset to free tier
        updateLastSeen()
    }
}

// MARK: - Extensions

extension UserProfile {
    /// Profile summary for debugging
    var debugDescription: String {
        return """
        UserProfile(
            authState: \(authState.rawValue),
            userId: \(userId.prefix(8))...,
            displayName: \(displayName ?? "nil"),
            email: \(email ?? "nil"),
            tier: \(tier),
            createdAt: \(createdAt),
            lastSeen: \(lastSeen)
        )
        """
    }
}

// MARK: - User Preferences

/// User preferences stored per-user
public struct UserPreferences: Codable, Sendable, Equatable {
    
    // MARK: - Personalization
    
    /// Enable AI personalization learning
    public var personalizeEnabled: Bool = true
    
    /// Portrait mode preference bias (-1.0 to 1.0)
    public var portraitAffinity: Float = 0.0
    
    /// HDR effect preference bias (-1.0 to 1.0)
    public var hdrAffinity: Float = 0.0
    
    /// Telephoto lens preference bias (-1.0 to 1.0)
    public var teleAffinity: Float = 0.0
    
    /// Ultra-wide lens preference bias (-1.0 to 1.0)
    public var ultraWideAffinity: Float = 0.0
    
    // MARK: - Sharing & Attribution
    
    /// Show PhotoStop watermark on enhanced images
    public var watermarkVisible: Bool = true
    
    /// Include PhotoStop attribution in social shares
    public var shareAttribution: Bool = true
    
    /// Default to Instagram sharing
    public var shareToInstagramDefault: Bool = false
    
    /// Default to TikTok sharing
    public var shareToTikTokDefault: Bool = false
    
    // MARK: - Privacy & Analytics
    
    /// Opt-in to anonymous usage analytics
    public var analyticsOptIn: Bool = false
    
    /// Allow crash reporting
    public var crashReportingEnabled: Bool = true
    
    /// Enable haptic feedback
    public var hapticFeedbackEnabled: Bool = true
    
    /// Enable sound effects
    public var soundEffectsEnabled: Bool = true
    
    // MARK: - Camera Settings
    
    /// Default camera position
    public var defaultCameraPosition: String = "back" // "back" or "front"
    
    /// Auto-flash mode
    public var autoFlashEnabled: Bool = true
    
    /// Save original photos to library
    public var saveOriginalPhotos: Bool = false
    
    /// Auto-save enhanced photos to library
    public var autoSaveEnhanced: Bool = true
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Factory Methods
    
    /// Default preferences for new users
    public static func defaultPreferences() -> UserPreferences {
        return UserPreferences()
    }
    
    /// Onboarding preferences based on user choices
    public static func onboardingPreferences(
        personalizeEnabled: Bool = true,
        watermarkVisible: Bool = true,
        analyticsOptIn: Bool = false
    ) -> UserPreferences {
        var prefs = UserPreferences()
        prefs.personalizeEnabled = personalizeEnabled
        prefs.watermarkVisible = watermarkVisible
        prefs.analyticsOptIn = analyticsOptIn
        return prefs
    }
    
    // MARK: - Validation
    
    /// Validate preference values are within acceptable ranges
    public mutating func validate() {
        portraitAffinity = max(-1.0, min(1.0, portraitAffinity))
        hdrAffinity = max(-1.0, min(1.0, hdrAffinity))
        teleAffinity = max(-1.0, min(1.0, teleAffinity))
        ultraWideAffinity = max(-1.0, min(1.0, ultraWideAffinity))
    }
    
    /// Reset all personalization affinities to neutral
    public mutating func resetPersonalization() {
        portraitAffinity = 0.0
        hdrAffinity = 0.0
        teleAffinity = 0.0
        ultraWideAffinity = 0.0
    }
    
    /// Reset all preferences to defaults
    public mutating func resetToDefaults() {
        self = UserPreferences.defaultPreferences()
    }
}

