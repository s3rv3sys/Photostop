//
//  ContentView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// Main content view with tab navigation and onboarding integration
struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var selectedTab: Int = 0
    @State private var showingOnboarding = false
    
    var body: some View {
        ZStack {
            if showingOnboarding {
                // Show onboarding flow
                OnboardingFlowView()
                    .transition(.opacity)
            } else {
                // Main app interface
                TabView(selection: $selectedTab) {
                    // Camera tab
                    NavigationView {
                        CameraView()
                    }
                    .tabItem {
                        Image(systemName: "camera.fill")
                        Text("Camera")
                    }
                    .tag(0)
                    
                    // Gallery tab
                    NavigationView {
                        GalleryView()
                    }
                    .tabItem {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Gallery")
                    }
                    .tag(1)
                    
                    // Profile tab
                    NavigationView {
                        ProfileView()
                    }
                    .tabItem {
                        Image(systemName: authViewModel.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                        Text("Profile")
                    }
                    .tag(2)
                    
                    // Settings tab
                    NavigationView {
                        SettingsView()
                    }
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
                    .tag(3)
                }
                .accentColor(.blue)
                .onAppear {
                    // Customize tab bar appearance
                    let appearance = UITabBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = UIColor.systemBackground
                    
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingOnboarding)
        .onAppear {
            checkOnboardingStatus()
        }
        .sheet(isPresented: $authViewModel.showingSignIn) {
            SignInView(onComplete: authViewModel.handleSignInComplete)
        }
        .alert("Authentication Error", isPresented: $authViewModel.showingError) {
            Button("OK") {
                authViewModel.clearError()
            }
        } message: {
            if let error = authViewModel.lastError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.userFriendlyMessage)
                    Text(error.recoverySuggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Check if onboarding should be shown
    private func checkOnboardingStatus() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "OnboardingCompleted")
        showingOnboarding = !hasCompletedOnboarding
        
        // Listen for onboarding completion
        NotificationCenter.default.addObserver(
            forName: .onboardingCompleted,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                showingOnboarding = false
            }
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("OnboardingCompleted")
}

// MARK: - Preview

#Preview {
    ContentView()
}

