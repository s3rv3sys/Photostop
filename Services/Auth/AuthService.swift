//
//  AuthService.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import AuthenticationServices
import Foundation
import os.log

/// Authentication service supporting Apple Sign-In and anonymous mode
@MainActor
final class AuthService: NSObject, ObservableObject {
    
    static let shared = AuthService()
    
    // MARK: - Published Properties
    
    /// Current user profile
    @Published private(set) var profile: UserProfile
    
    /// Authentication state
    @Published private(set) var isSignedIn: Bool = false
    
    /// Loading state for sign-in operations
    @Published var isLoading: Bool = false
    
    /// Last authentication error
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "AuthService")
    private let preferencesStore = PreferencesStore.shared
    
    // MARK: - Initialization
    
    private override init() {
        // Initialize with anonymous profile
        let anonymousId = AnonymousId.getOrCreate()
        self.profile = UserProfile.anonymous(userId: anonymousId)
        self.isSignedIn = false
        
        super.init()
        
        // Load preferences for current user
        preferencesStore.load(for: profile.userId)
        
        // Check if user was previously signed in
        checkExistingSignIn()
        
        logger.info("AuthService initialized with user: \(self.profile.userId.prefix(8))...")
    }
    
    // MARK: - Public Interface
    
    /// Get current user profile
    func currentProfile() -> UserProfile {
        return profile
    }
    
    /// Sign in with Apple
    func signInWithApple() async throws -> UserProfile {
        logger.info("Starting Apple Sign-In")
        
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate()
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            
            controller.performRequests()
            
            let result = try await delegate.result()
            logger.info("Apple Sign-In successful for user: \(result.userId.prefix(8))...")
            
            // Store Apple user identifier in keychain
            let saved = KeychainService.shared.save(result.userId, forKey: "APPLE_USER_ID")
            if !saved {
                logger.warning("Failed to save Apple user ID to keychain")
            }
            
            // Migrate anonymous data to signed-in user
            let oldUserId = profile.userId
            let newUserId = result.userId
            
            // Create new signed-in profile
            let signedInProfile = UserProfile.signedIn(
                userId: newUserId,
                displayName: result.displayName,
                email: result.email,
                tier: profile.tier // Preserve current tier
            )
            
            // Migrate preferences and usage data
            try await migrateUserData(from: oldUserId, to: newUserId)
            
            // Update current profile
            profile = signedInProfile
            isSignedIn = true
            
            // Load preferences for new user
            preferencesStore.load(for: newUserId)
            
            logger.info("User data migration completed successfully")
            
            return signedInProfile
            
        } catch {
            logger.error("Apple Sign-In failed: \(error.localizedDescription)")
            lastError = error
            throw error
        }
    }
    
    /// Sign out and return to anonymous mode
    func signOut() async {
        logger.info("Signing out user: \(profile.userId.prefix(8))...")
        
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        // Clear Apple credentials
        _ = KeychainService.shared.delete("APPLE_USER_ID")
        
        // Create new anonymous profile
        let anonymousId = AnonymousId.getOrCreate()
        profile = UserProfile.anonymous(userId: anonymousId)
        isSignedIn = false
        
        // Load anonymous preferences
        preferencesStore.load(for: anonymousId)
        
        logger.info("Sign out completed, now anonymous: \(anonymousId.prefix(8))...")
    }
    
    /// Delete user account and all data
    func deleteAccount() async throws {
        logger.info("Deleting account for user: \(profile.userId.prefix(8))...")
        
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        let currentUserId = profile.userId
        
        // Delete user preferences
        try preferencesStore.deleteUser(currentUserId)
        
        // Clear usage tracking data
        UsageTracker.shared.resetForUser(currentUserId)
        
        // Clear keychain data
        _ = KeychainService.shared.delete("APPLE_USER_ID")
        AnonymousId.delete()
        
        // Create fresh anonymous profile
        let newAnonymousId = AnonymousId.getOrCreate()
        profile = UserProfile.anonymous(userId: newAnonymousId)
        isSignedIn = false
        
        // Load fresh preferences
        preferencesStore.load(for: newAnonymousId)
        
        logger.info("Account deletion completed")
    }
    
    /// Update user profile information
    func updateProfile(displayName: String?, email: String?) async {
        profile.updateProfile(displayName: displayName, email: email)
        profile.updateLastSeen()
        
        logger.info("Profile updated for user: \(profile.userId.prefix(8))...")
    }
    
    /// Update subscription tier
    func updateTier(_ newTier: String) {
        profile.updateTier(newTier)
        logger.info("Tier updated to: \(newTier) for user: \(profile.userId.prefix(8))...")
    }
    
    // MARK: - Private Methods
    
    /// Check if user was previously signed in
    private func checkExistingSignIn() {
        if let appleUserId = KeychainService.shared.get("APPLE_USER_ID") {
            // User was previously signed in, restore signed-in state
            profile.upgradeToSignedIn(
                newUserId: appleUserId,
                displayName: nil, // Will be refreshed on next sign-in
                email: nil
            )
            isSignedIn = true
            
            // Load preferences for signed-in user
            preferencesStore.load(for: appleUserId)
            
            logger.info("Restored signed-in state for user: \(appleUserId.prefix(8))...")
        }
    }
    
    /// Migrate user data from anonymous to signed-in
    private func migrateUserData(from oldUserId: String, to newUserId: String) async throws {
        logger.info("Migrating user data from \(oldUserId.prefix(8))... to \(newUserId.prefix(8))...")
        
        // Migrate preferences
        try preferencesStore.migrate(from: oldUserId, to: newUserId)
        
        // Migrate usage tracking data
        UsageTracker.shared.migrateUser(from: oldUserId, to: newUserId)
        
        // Migrate personalization data if available
        if let personalizationEngine = PersonalizationEngine.shared {
            await personalizationEngine.migrateUser(from: oldUserId, to: newUserId)
        }
        
        logger.info("User data migration completed")
    }
}

// MARK: - Apple Sign-In Delegate

/// Helper delegate to handle Apple Sign-In flow
final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    /// Result structure for Apple Sign-In
    struct AppleResult {
        let userId: String
        let displayName: String?
        let email: String?
    }
    
    private var continuation: CheckedContinuation<AppleResult, Error>?
    
    /// Wait for Apple Sign-In result
    func result() async throws -> AppleResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign-In presentation")
        }
        return window
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthError.invalidCredential)
            return
        }
        
        let userId = credential.user
        
        // Combine first and last name
        let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .nilIfEmpty
        
        let email = credential.email
        
        let result = AppleResult(
            userId: userId,
            displayName: displayName,
            email: email
        )
        
        continuation?.resume(returning: result)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
    }
}

// MARK: - Extensions

private extension String {
    /// Return nil if string is empty
    var nilIfEmpty: String? {
        return isEmpty ? nil : self
    }
}

// MARK: - Auth Errors

/// Authentication-specific errors
enum AuthError: LocalizedError {
    case invalidCredential
    case userCancelled
    case migrationFailed
    case keychainError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple ID credential received"
        case .userCancelled:
            return "Sign-in was cancelled by user"
        case .migrationFailed:
            return "Failed to migrate user data"
        case .keychainError:
            return "Failed to store credentials securely"
        }
    }
}

