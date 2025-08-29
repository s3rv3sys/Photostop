//
//  SignInView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI
import AuthenticationServices

/// Sign-in view with Apple Sign-In and anonymous options
struct SignInView: View {
    @StateObject private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    let onComplete: (() -> Void)?
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.2, green: 0.1, blue: 0.3),
                        Color(red: 0.1, green: 0.2, blue: 0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        Spacer(minLength: 60)
                        
                        // App branding
                        VStack(spacing: 20) {
                            // App icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.cyan.opacity(0.3), .blue.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "camera.aperture")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Welcome to PhotoStop")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("Sign in to sync your preferences and unlock Pro features")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        
                        // Sign-in options
                        VStack(spacing: 16) {
                            // Sign in with Apple
                            SignInWithAppleButton(.signIn) { request in
                                // This will be handled by AuthService
                            } onCompletion: { result in
                                // This will be handled by AuthService
                            }
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                            .onTapGesture {
                                signInWithApple()
                            }
                            
                            // Custom Apple Sign-In button (fallback)
                            Button(action: signInWithApple) {
                                HStack(spacing: 12) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Text("Sign in with Apple")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 25))
                            }
                            .disabled(authService.isLoading)
                            
                            // Email sign-in (placeholder)
                            Button(action: {}) {
                                HStack(spacing: 12) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 18))
                                    
                                    Text("Sign in with Email")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(.white.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 25))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(true) // Placeholder - not implemented
                            .opacity(0.5)
                            
                            // Anonymous option
                            Button(action: continueAnonymously) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.dashed")
                                        .font(.system(size: 18))
                                    
                                    Text("Continue without account")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Benefits of signing in
                        VStack(spacing: 16) {
                            Text("Why sign in?")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                SignInBenefitRow(
                                    icon: "icloud.fill",
                                    title: "Sync Preferences",
                                    description: "Keep your settings across devices"
                                )
                                
                                SignInBenefitRow(
                                    icon: "crown.fill",
                                    title: "Pro Features",
                                    description: "Access premium AI and unlimited credits"
                                )
                                
                                SignInBenefitRow(
                                    icon: "shield.fill",
                                    title: "Privacy First",
                                    description: "We only store what's necessary"
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Loading indicator
                        if authService.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                
                                Text("Signing you in...")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.top, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .alert("Sign In Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: authService.lastError) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        .onChange(of: authService.isSignedIn) { isSignedIn in
            if isSignedIn {
                onComplete?()
                dismiss()
            }
        }
    }
    
    // MARK: - Actions
    
    private func signInWithApple() {
        Task {
            do {
                _ = try await authService.signInWithApple()
                // Success handled by onChange
            } catch {
                // Error handled by onChange
            }
        }
    }
    
    private func continueAnonymously() {
        onComplete?()
        dismiss()
    }
}

// MARK: - Supporting Views

struct SignInBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.cyan)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

// MARK: - Permission Managers

struct CameraPermissionManager {
    static func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

struct PhotoLibraryPermissionManager {
    static func requestPhotoLibraryPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status == .authorized || status == .limited)
            }
        }
    }
}

#Preview {
    SignInView()
}

