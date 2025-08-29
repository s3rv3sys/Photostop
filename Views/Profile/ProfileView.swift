//
//  ProfileView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// User profile view with avatar, preferences, and account management
struct ProfileView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var preferencesStore = PreferencesStore.shared
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()
    
    @State private var showingSignIn = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile header
                profileHeaderSection
                
                // Account section
                accountSection
                
                // Preferences sections
                personalizationSection
                sharingSection
                privacySection
                cameraSection
                
                // Account management
                accountManagementSection
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                // Refresh subscription status
                await subscriptionViewModel.refreshSubscriptionStatus()
            }
        }
        .sheet(isPresented: $showingSignIn) {
            SignInView()
        }
        .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out? Your preferences will be saved locally.")
        }
        .confirmationDialog("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Delete Account", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all data. This action cannot be undone.")
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeaderSection: some View {
        Section {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: authService.profile.isSignedIn ? 
                                    [.blue, .purple] : [.gray, .secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Text(authService.profile.avatarInitials)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(authService.profile.effectiveDisplayName)
                        .font(.system(size: 20, weight: .semibold))
                    
                    if let email = authService.profile.email {
                        Text(email)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: authService.profile.isSignedIn ? "checkmark.shield.fill" : "person.crop.circle.dashed")
                            .font(.system(size: 12))
                            .foregroundColor(authService.profile.isSignedIn ? .green : .orange)
                        
                        Text(authService.profile.authState.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Sign in button for anonymous users
                if !authService.profile.isSignedIn {
                    Button("Sign In") {
                        showingSignIn = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section("Account") {
            // Subscription status
            HStack {
                Image(systemName: authService.profile.isPro ? "crown.fill" : "person.fill")
                    .foregroundColor(authService.profile.isPro ? .yellow : .blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(authService.profile.isPro ? "PhotoStop Pro" : "PhotoStop Free")
                        .font(.system(size: 16, weight: .semibold))
                    
                    if authService.profile.isPro {
                        Text("Premium features unlocked")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Upgrade for unlimited AI credits")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !authService.profile.isPro {
                    Button("Upgrade") {
                        subscriptionViewModel.presentPaywall(context: .generalUpgrade)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            // Usage statistics
            UsageStatsView()
            
            // Manage subscription (if Pro)
            if authService.profile.isPro {
                NavigationLink(destination: ManageSubscriptionView()) {
                    Label("Manage Subscription", systemImage: "creditcard.fill")
                }
            }
        }
    }
    
    // MARK: - Personalization Section
    
    private var personalizationSection: some View {
        Section("Personalization") {
            Toggle("Enable AI Learning", isOn: Binding(
                get: { preferencesStore.prefs.personalizeEnabled },
                set: { preferencesStore.updatePreference(\.personalizeEnabled, value: $0) }
            ))
            
            if preferencesStore.prefs.personalizeEnabled {
                VStack(spacing: 16) {
                    PersonalizationSlider(
                        title: "Portrait Preference",
                        value: Binding(
                            get: { preferencesStore.prefs.portraitAffinity },
                            set: { preferencesStore.updatePersonalization(portraitAffinity: $0) }
                        ),
                        icon: "person.crop.circle.fill"
                    )
                    
                    PersonalizationSlider(
                        title: "HDR Preference",
                        value: Binding(
                            get: { preferencesStore.prefs.hdrAffinity },
                            set: { preferencesStore.updatePersonalization(hdrAffinity: $0) }
                        ),
                        icon: "camera.filters"
                    )
                    
                    PersonalizationSlider(
                        title: "Telephoto Preference",
                        value: Binding(
                            get: { preferencesStore.prefs.teleAffinity },
                            set: { preferencesStore.updatePersonalization(teleAffinity: $0) }
                        ),
                        icon: "camera.macro.circle.fill"
                    )
                    
                    PersonalizationSlider(
                        title: "Ultra-Wide Preference",
                        value: Binding(
                            get: { preferencesStore.prefs.ultraWideAffinity },
                            set: { preferencesStore.updatePersonalization(ultraWideAffinity: $0) }
                        ),
                        icon: "camera.circle.fill"
                    )
                }
                .padding(.vertical, 8)
            }
            
            Button("Reset Personalization") {
                preferencesStore.prefs.resetPersonalization()
                preferencesStore.save()
            }
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Sharing Section
    
    private var sharingSection: some View {
        Section("Sharing & Attribution") {
            Toggle("Show PhotoStop Watermark", isOn: Binding(
                get: { preferencesStore.prefs.watermarkVisible },
                set: { preferencesStore.updateSharing(watermark: $0) }
            ))
            
            Toggle("Include Attribution", isOn: Binding(
                get: { preferencesStore.prefs.shareAttribution },
                set: { preferencesStore.updateSharing(attribution: $0) }
            ))
            
            Toggle("Default to Instagram", isOn: Binding(
                get: { preferencesStore.prefs.shareToInstagramDefault },
                set: { preferencesStore.updateSharing(instagramDefault: $0) }
            ))
            
            Toggle("Default to TikTok", isOn: Binding(
                get: { preferencesStore.prefs.shareToTikTokDefault },
                set: { preferencesStore.updateSharing(tiktokDefault: $0) }
            ))
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        Section("Privacy") {
            Toggle("Anonymous Analytics", isOn: Binding(
                get: { preferencesStore.prefs.analyticsOptIn },
                set: { preferencesStore.updatePrivacy(analytics: $0) }
            ))
            
            Toggle("Crash Reporting", isOn: Binding(
                get: { preferencesStore.prefs.crashReportingEnabled },
                set: { preferencesStore.updatePrivacy(crashReporting: $0) }
            ))
            
            NavigationLink(destination: PrivacyPolicyView()) {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
            
            NavigationLink(destination: TermsOfServiceView()) {
                Label("Terms of Service", systemImage: "doc.text.fill")
            }
        }
    }
    
    // MARK: - Camera Section
    
    private var cameraSection: some View {
        Section("Camera") {
            Toggle("Haptic Feedback", isOn: Binding(
                get: { preferencesStore.prefs.hapticFeedbackEnabled },
                set: { preferencesStore.updatePreference(\.hapticFeedbackEnabled, value: $0) }
            ))
            
            Toggle("Sound Effects", isOn: Binding(
                get: { preferencesStore.prefs.soundEffectsEnabled },
                set: { preferencesStore.updatePreference(\.soundEffectsEnabled, value: $0) }
            ))
            
            Toggle("Auto Flash", isOn: Binding(
                get: { preferencesStore.prefs.autoFlashEnabled },
                set: { preferencesStore.updatePreference(\.autoFlashEnabled, value: $0) }
            ))
            
            Toggle("Save Originals", isOn: Binding(
                get: { preferencesStore.prefs.saveOriginalPhotos },
                set: { preferencesStore.updatePreference(\.saveOriginalPhotos, value: $0) }
            ))
            
            Toggle("Auto-Save Enhanced", isOn: Binding(
                get: { preferencesStore.prefs.autoSaveEnhanced },
                set: { preferencesStore.updatePreference(\.autoSaveEnhanced, value: $0) }
            ))
        }
    }
    
    // MARK: - Account Management Section
    
    private var accountManagementSection: some View {
        Section("Account Management") {
            if authService.profile.isSignedIn {
                Button("Sign Out") {
                    showingSignOutConfirmation = true
                }
                .foregroundColor(.orange)
                
                Button("Delete Account") {
                    showingDeleteConfirmation = true
                }
                .foregroundColor(.red)
            }
            
            Button("Reset All Preferences") {
                preferencesStore.resetToDefaults()
            }
            .foregroundColor(.orange)
            
            // Debug info (in development builds)
            #if DEBUG
            Section("Debug Info") {
                Text("User ID: \(authService.profile.userId.prefix(8))...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text("Created: \(authService.profile.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            #endif
        }
    }
    
    // MARK: - Actions
    
    private func signOut() {
        Task {
            await authService.signOut()
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                try await authService.deleteAccount()
            } catch {
                // Handle error
            }
        }
    }
}

// MARK: - Supporting Views

struct PersonalizationSlider: View {
    let title: String
    @Binding var value: Float
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Text(value == 0 ? "Neutral" : (value > 0 ? "Prefer" : "Avoid"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Avoid")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Slider(value: $value, in: -1.0...1.0, step: 0.1)
                    .accentColor(.blue)
                
                Text("Prefer")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct UsageStatsView: View {
    @StateObject private var usageTracker = UsageTracker.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Month's Usage")
                .font(.system(size: 14, weight: .semibold))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget AI")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("\(usageTracker.currentUsage.budgetCreditsUsed)/\(usageTracker.currentLimits.budgetCreditsPerMonth)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Premium AI")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("\(usageTracker.currentUsage.premiumCreditsUsed)/\(usageTracker.currentLimits.premiumCreditsPerMonth)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)
                }
            }
            
            // Progress bars
            VStack(spacing: 4) {
                ProgressView(value: Float(usageTracker.currentUsage.budgetCreditsUsed), total: Float(usageTracker.currentLimits.budgetCreditsPerMonth))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 0.5)
                
                ProgressView(value: Float(usageTracker.currentUsage.premiumCreditsUsed), total: Float(usageTracker.currentLimits.premiumCreditsPerMonth))
                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                    .scaleEffect(y: 0.5)
            }
        }
        .padding(.vertical, 8)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your privacy is important to us. This policy explains how PhotoStop handles your data.")
                    .font(.body)
                
                // Add privacy policy content here
                Text("Data Collection: We collect minimal data necessary for app functionality...")
                    .font(.body)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("By using PhotoStop, you agree to these terms and conditions.")
                    .font(.body)
                
                // Add terms content here
                Text("Usage: PhotoStop is provided as-is for personal and commercial use...")
                    .font(.body)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
}

