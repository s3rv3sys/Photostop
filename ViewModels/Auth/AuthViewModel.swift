//
//  AuthViewModel.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI
import Combine
import os.log

/// ViewModel for authentication and user management
@MainActor
final class AuthViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current user profile
    @Published var profile: UserProfile
    
    /// Authentication loading state
    @Published var isLoading: Bool = false
    
    /// Sign-in presentation state
    @Published var showingSignIn: Bool = false
    
    /// Profile presentation state
    @Published var showingProfile: Bool = false
    
    /// Last authentication error
    @Published var lastError: AuthError?
    
    /// Error presentation state
    @Published var showingError: Bool = false
    
    // MARK: - Computed Properties
    
    /// Is user signed in
    var isSignedIn: Bool {
        profile.isSignedIn
    }
    
    /// Is user on Pro tier
    var isPro: Bool {
        profile.isPro
    }
    
    /// User display name with fallback
    var displayName: String {
        profile.effectiveDisplayName
    }
    
    /// User avatar initials
    var avatarInitials: String {
        profile.avatarInitials
    }
    
    // MARK: - Private Properties
    
    private let authService: AuthService
    private let preferencesStore: PreferencesStore
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "AuthViewModel")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        authService: AuthService = AuthService.shared,
        preferencesStore: PreferencesStore = PreferencesStore.shared
    ) {
        self.authService = authService
        self.preferencesStore = preferencesStore
        self.profile = authService.currentProfile()
        
        setupBindings()
        logger.info("AuthViewModel initialized")
    }
    
    // MARK: - Public Methods
    
    /// Present sign-in flow
    func presentSignIn() {
        logger.info("Presenting sign-in flow")
        showingSignIn = true
    }
    
    /// Present profile view
    func presentProfile() {
        logger.info("Presenting profile view")
        showingProfile = true
    }
    
    /// Sign in with Apple
    func signInWithApple() async {
        logger.info("Starting Apple Sign-In")
        
        isLoading = true
        lastError = nil
        
        do {
            let newProfile = try await authService.signInWithApple()
            profile = newProfile
            
            logger.info("Apple Sign-In successful")
            
            // Dismiss sign-in sheet
            showingSignIn = false
            
        } catch let error as AuthError {
            logger.error("Apple Sign-In failed: \(error.localizedDescription)")
            lastError = error
            showingError = true
        } catch {
            logger.error("Apple Sign-In failed with unknown error: \(error.localizedDescription)")
            lastError = .invalidCredential
            showingError = true
        }
        
        isLoading = false
    }
    
    /// Sign out
    func signOut() async {
        logger.info("Signing out")
        
        isLoading = true
        
        await authService.signOut()
        profile = authService.currentProfile()
        
        isLoading = false
        
        logger.info("Sign out completed")
    }
    
    /// Delete account
    func deleteAccount() async throws {
        logger.info("Deleting account")
        
        isLoading = true
        
        do {
            try await authService.deleteAccount()
            profile = authService.currentProfile()
            
            logger.info("Account deletion completed")
        } catch {
            logger.error("Account deletion failed: \(error.localizedDescription)")
            throw error
        }
        
        isLoading = false
    }
    
    /// Update profile information
    func updateProfile(displayName: String?, email: String?) async {
        logger.info("Updating profile")
        
        await authService.updateProfile(displayName: displayName, email: email)
        profile = authService.currentProfile()
        
        logger.info("Profile updated")
    }
    
    /// Update subscription tier
    func updateTier(_ newTier: String) {
        logger.info("Updating tier to: \(newTier)")
        
        authService.updateTier(newTier)
        profile = authService.currentProfile()
        
        logger.info("Tier updated")
    }
    
    /// Clear last error
    func clearError() {
        lastError = nil
        showingError = false
    }
    
    /// Handle sign-in completion
    func handleSignInComplete() {
        showingSignIn = false
        profile = authService.currentProfile()
    }
    
    /// Handle profile dismissal
    func handleProfileDismissal() {
        showingProfile = false
        profile = authService.currentProfile()
    }
    
    // MARK: - Private Methods
    
    /// Setup reactive bindings
    private func setupBindings() {
        // Observe auth service changes
        authService.$profile
            .receive(on: DispatchQueue.main)
            .assign(to: &$profile)
        
        authService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        authService.$lastError
            .receive(on: DispatchQueue.main)
            .compactMap { $0 as? AuthError }
            .assign(to: &$lastError)
        
        // Show error when lastError changes
        $lastError
            .map { $0 != nil }
            .assign(to: &$showingError)
    }
}

// MARK: - Auth Error Extension

extension AuthError {
    /// User-friendly error message
    var userFriendlyMessage: String {
        switch self {
        case .invalidCredential:
            return "Unable to verify your Apple ID. Please try again."
        case .userCancelled:
            return "Sign-in was cancelled."
        case .migrationFailed:
            return "Unable to transfer your data. Please contact support."
        case .keychainError:
            return "Unable to securely store your credentials. Please check your device settings."
        }
    }
    
    /// Recovery suggestion
    var recoverySuggestion: String {
        switch self {
        case .invalidCredential:
            return "Make sure you're signed in to iCloud and try again."
        case .userCancelled:
            return "Tap 'Sign In' to try again."
        case .migrationFailed:
            return "Your account was created but some data may not have transferred."
        case .keychainError:
            return "Check that your device passcode is enabled and try again."
        }
    }
}

