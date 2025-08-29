//
//  OnboardingFlowView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// Complete onboarding flow for new users
struct OnboardingFlowView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
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
            
            VStack(spacing: 0) {
                // Progress indicator
                OnboardingProgressView(
                    currentPage: viewModel.currentPage,
                    totalPages: viewModel.totalPages
                )
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Page content
                TabView(selection: $viewModel.currentPage) {
                    WelcomeScreen()
                        .tag(0)
                    
                    PersonalizationScreen(
                        personalizeEnabled: $viewModel.personalizeEnabled
                    )
                    .tag(1)
                    
                    SharingScreen()
                        .tag(2)
                    
                    PlanScreen(
                        showPaywall: $viewModel.showPaywall
                    )
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentPage)
                
                // Bottom controls
                OnboardingControlsView(
                    currentPage: viewModel.currentPage,
                    totalPages: viewModel.totalPages,
                    isLoading: viewModel.isLoading,
                    onNext: viewModel.nextPage,
                    onSkip: viewModel.skipOnboarding,
                    onComplete: viewModel.completeOnboarding
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView(context: .onboarding)
        }
        .sheet(isPresented: $viewModel.showSignIn) {
            SignInView(onComplete: viewModel.handleSignInComplete)
        }
        .onChange(of: viewModel.isCompleted) { completed in
            if completed {
                dismiss()
            }
        }
    }
}

// MARK: - Welcome Screen

struct WelcomeScreen: View {
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App icon animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateIcon)
                
                Image(systemName: "camera.aperture")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.white)
            }
            .onAppear {
                animateIcon = true
            }
            
            VStack(spacing: 16) {
                Text("One Tap.\nPerfect Photos.")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("We capture smart bursts & pick your best frame automatically using advanced AI.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Feature highlights
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "burst.fill",
                    title: "Smart Burst Capture",
                    description: "Multiple frames with perfect timing"
                )
                
                FeatureRow(
                    icon: "brain.head.profile",
                    title: "AI Frame Selection",
                    description: "Automatically picks your best shot"
                )
                
                FeatureRow(
                    icon: "wand.and.stars",
                    title: "Instant Enhancement",
                    description: "Professional results in one tap"
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

// MARK: - Personalization Screen

struct PersonalizationScreen: View {
    @Binding var personalizeEnabled: Bool
    @State private var animateGears = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated gears
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(animateGears ? 360 : 0))
                    .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: animateGears)
            }
            .onAppear {
                animateGears = true
            }
            
            VStack(spacing: 16) {
                Text("AI that learns\nyour style.")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Give a quick 👍/👎 to teach PhotoStop your preferences. Everything stays on your iPhone.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Personalization toggle
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Personalization")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Learn your photo preferences over time")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $personalizeEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .cyan))
                        .scaleEffect(1.2)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // Privacy note
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    
                    Text("Your preferences never leave your device")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

// MARK: - Sharing Screen

struct SharingScreen: View {
    @State private var animateShare = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated sharing icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .red.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.white)
                    .scaleEffect(animateShare ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateShare)
            }
            .onAppear {
                animateShare = true
            }
            
            VStack(spacing: 16) {
                Text("Share where\nit matters.")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Instagram Stories & TikTok in one tap. Perfect for content creators.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Social platform showcase
            VStack(spacing: 16) {
                SocialPlatformRow(
                    icon: "camera.circle.fill",
                    name: "Instagram Stories",
                    description: "Direct sharing with attribution",
                    color: .purple
                )
                
                SocialPlatformRow(
                    icon: "music.note.tv.fill",
                    name: "TikTok",
                    description: "Seamless handoff with captions",
                    color: .pink
                )
                
                SocialPlatformRow(
                    icon: "square.and.arrow.up.circle.fill",
                    name: "System Share",
                    description: "All your favorite apps",
                    color: .blue
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

// MARK: - Plan Screen

struct PlanScreen: View {
    @Binding var showPaywall: Bool
    @State private var animateCrown = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated crown
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow.opacity(0.3), .orange.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.yellow)
                    .scaleEffect(animateCrown ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateCrown)
            }
            .onAppear {
                animateCrown = true
            }
            
            VStack(spacing: 16) {
                Text("Start free.\nGo Pro when ready.")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Try PhotoStop Pro free for 7 days. More AI credits, premium features, and priority support.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Plan comparison
            VStack(spacing: 16) {
                PlanComparisonRow(
                    feature: "AI Enhancements",
                    free: "50/month",
                    pro: "500/month",
                    highlight: true
                )
                
                PlanComparisonRow(
                    feature: "Premium AI",
                    free: "5/month",
                    pro: "300/month",
                    highlight: true
                )
                
                PlanComparisonRow(
                    feature: "Social Sharing",
                    free: "✓",
                    pro: "✓",
                    highlight: false
                )
                
                PlanComparisonRow(
                    feature: "Personalization",
                    free: "✓",
                    pro: "✓",
                    highlight: false
                )
            }
            .padding(.horizontal, 20)
            
            // Try Pro button
            Button(action: { showPaywall = true }) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Try Pro Free for 7 Days")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 25))
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

// MARK: - Supporting Views

struct OnboardingProgressView: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= currentPage ? .white : .white.opacity(0.3))
                    .frame(width: index == currentPage ? 24 : 8, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
    }
}

struct OnboardingControlsView: View {
    let currentPage: Int
    let totalPages: Int
    let isLoading: Bool
    let onNext: () -> Void
    let onSkip: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        HStack {
            // Skip button
            if currentPage < totalPages - 1 {
                Button("Skip", action: onSkip)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Spacer()
            }
            
            Spacer()
            
            // Next/Complete button
            Button(action: currentPage < totalPages - 1 ? onNext : onComplete) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    }
                    
                    Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                        .font(.system(size: 16, weight: .semibold))
                    
                    if !isLoading && currentPage < totalPages - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .disabled(isLoading)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
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

struct SocialPlatformRow: View {
    let icon: String
    let name: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
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

struct PlanComparisonRow: View {
    let feature: String
    let free: String
    let pro: String
    let highlight: Bool
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(free)
                .font(.system(size: 14, weight: highlight ? .semibold : .regular))
                .foregroundColor(highlight ? .white : .white.opacity(0.7))
            
            Text("→")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 8)
            
            Text(pro)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(highlight ? .yellow : .white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(highlight ? 0.1 : 0.05))
        )
    }
}

// MARK: - ViewModel

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var personalizeEnabled: Bool = true
    @Published var showPaywall: Bool = false
    @Published var showSignIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var isCompleted: Bool = false
    
    let totalPages = 4
    
    func nextPage() {
        if currentPage < totalPages - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        }
    }
    
    func skipOnboarding() {
        completeOnboarding()
    }
    
    func completeOnboarding() {
        isLoading = true
        
        Task {
            // Save onboarding preferences
            let preferences = UserPreferences.onboardingPreferences(
                personalizeEnabled: personalizeEnabled,
                watermarkVisible: true,
                analyticsOptIn: false
            )
            
            // Apply preferences to current user
            let prefsStore = PreferencesStore.shared
            prefsStore.prefs = preferences
            prefsStore.save()
            
            // Mark onboarding as completed
            UserDefaults.standard.set(true, forKey: "OnboardingCompleted")
            
            // Request permissions
            await requestPermissions()
            
            await MainActor.run {
                isLoading = false
                isCompleted = true
            }
        }
    }
    
    func handleSignInComplete() {
        showSignIn = false
        completeOnboarding()
    }
    
    private func requestPermissions() async {
        // Request camera permission
        await CameraPermissionManager.requestCameraPermission()
        
        // Request photo library permission
        await PhotoLibraryPermissionManager.requestPhotoLibraryPermission()
    }
}

#Preview {
    OnboardingFlowView()
}

