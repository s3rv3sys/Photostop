//
//  SettingsView.swift
//  PhotoStop - Enhanced with Personalization v1
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// Settings view for app configuration, preferences, and personalization
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()
    @StateObject private var feedbackService = IQAFeedbackService.shared
    @StateObject private var uploadQueue = UploadQueue.shared
    
    // NEW: Personalization integration
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    
    @State private var showPaywall = false
    @State private var showManageSubscription = false
    @State private var showCreditsShop = false
    @State private var showPersonalizationReset = false
    @State private var showAdvancedPersonalization = false
    
    var body: some View {
        List {
            // Account section
            accountSection
            
            // NEW: Personalization section
            personalizationSection
            
            // Usage section
            usageSection
            
            // IQA Feedback section
            iqaFeedbackSection
            
            // Camera settings
            cameraSection
            
            // AI Enhancement settings
            aiEnhancementSection
            
            // Privacy & Data section
            privacySection
            
            // Support section
            supportSection
            
            // About section
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .generalUpgrade)
        }
        .sheet(isPresented: $showManageSubscription) {
            ManageSubscriptionView()
        }
        .sheet(isPresented: $showCreditsShop) {
            CreditsShopView()
        }
        .alert("Reset Personalization", isPresented: $showPersonalizationReset) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                personalizationEngine.reset()
            }
        } message: {
            Text("This will reset all your personalization preferences to neutral. Your photo picks will no longer be customized to your taste.")
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section("Account") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionViewModel.currentTier.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if subscriptionViewModel.currentTier == .pro {
                        Text("Active until \(subscriptionViewModel.subscriptionExpiryDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Upgrade for unlimited AI enhancements")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if subscriptionViewModel.currentTier == .free {
                    Button("Go Pro") {
                        showPaywall = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button("Manage") {
                        showManageSubscription = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            if subscriptionViewModel.currentTier == .free {
                Button("Buy Credits") {
                    showCreditsShop = true
                }
            }
        }
    }
    
    // MARK: - NEW: Personalization Section
    
    private var personalizationSection: some View {
        Section {
            // Main personalization toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personalize My Picks")
                        .font(.headline)
                    
                    Text(personalizationEngine.getStatistics().summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { personalizationEngine.currentProfile().enabled },
                    set: { personalizationEngine.setEnabled($0) }
                ))
            }
            
            if personalizationEngine.currentProfile().enabled {
                // Preference strength indicator
                let stats = personalizationEngine.getStatistics()
                if !stats.isNeutral {
                    HStack {
                        Text("Preference Strength")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        ProgressView(value: stats.preferenceStrength)
                            .frame(width: 100)
                        
                        Text("\(Int(stats.preferenceStrength * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Advanced controls
                DisclosureGroup("Advanced Personalization", isExpanded: $showAdvancedPersonalization) {
                    advancedPersonalizationControls
                }
                
                // Reset button
                Button("Reset Personalization") {
                    showPersonalizationReset = true
                }
                .foregroundColor(.red)
            }
        } header: {
            Label("Personalization", systemImage: "brain.head.profile")
        } footer: {
            if personalizationEngine.currentProfile().enabled {
                Text("PhotoStop learns your preferences from your ratings and automatically improves photo selection over time. All learning happens on your device.")
            } else {
                Text("Enable personalization to let PhotoStop learn your preferences and improve photo selection.")
            }
        }
    }
    
    private var advancedPersonalizationControls: some View {
        Group {
            // Portrait affinity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Portrait Preference")
                        .font(.subheadline)
                    Spacer()
                    Text(formatPreferenceValue(personalizationEngine.currentProfile().portraitAffinity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { personalizationEngine.currentProfile().portraitAffinity },
                        set: { personalizationEngine.updatePreference(\.portraitAffinity, value: $0) }
                    ),
                    in: -1...1,
                    step: 0.1
                )
            }
            
            // HDR affinity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("HDR Preference")
                        .font(.subheadline)
                    Spacer()
                    Text(formatPreferenceValue(personalizationEngine.currentProfile().hdrAffinity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { personalizationEngine.currentProfile().hdrAffinity },
                        set: { personalizationEngine.updatePreference(\.hdrAffinity, value: $0) }
                    ),
                    in: -1...1,
                    step: 0.1
                )
            }
            
            // Tele lens affinity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Telephoto Lens Preference")
                        .font(.subheadline)
                    Spacer()
                    Text(formatPreferenceValue(personalizationEngine.currentProfile().teleAffinity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { personalizationEngine.currentProfile().teleAffinity },
                        set: { personalizationEngine.updatePreference(\.teleAffinity, value: $0) }
                    ),
                    in: -1...1,
                    step: 0.1
                )
            }
            
            // Ultra-wide lens affinity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ultra-Wide Lens Preference")
                        .font(.subheadline)
                    Spacer()
                    Text(formatPreferenceValue(personalizationEngine.currentProfile().ultraWideAffinity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { personalizationEngine.currentProfile().ultraWideAffinity },
                        set: { personalizationEngine.updatePreference(\.ultraWideAffinity, value: $0) }
                    ),
                    in: -1...1,
                    step: 0.1
                )
            }
            
            // Current profile summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Profile")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(personalizationEngine.currentProfile().summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Usage Section
    
    private var usageSection: some View {
        Section {
            // Budget credits
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget AI Credits")
                        .font(.subheadline)
                    
                    Text("\(viewModel.budgetCreditsUsed)/\(viewModel.budgetCreditsLimit) used this month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                CircularProgressView(
                    progress: Double(viewModel.budgetCreditsUsed) / Double(viewModel.budgetCreditsLimit),
                    color: .blue
                )
                .frame(width: 40, height: 40)
            }
            
            // Premium credits
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Premium AI Credits")
                        .font(.subheadline)
                    
                    Text("\(viewModel.premiumCreditsUsed)/\(viewModel.premiumCreditsLimit) used this month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                CircularProgressView(
                    progress: Double(viewModel.premiumCreditsUsed) / Double(viewModel.premiumCreditsLimit),
                    color: .purple
                )
                .frame(width: 40, height: 40)
            }
            
            // Addon credits (if any)
            if viewModel.addonCredits > 0 {
                HStack {
                    Text("Bonus Credits")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(viewModel.addonCredits)")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            
            // Reset date
            HStack {
                Text("Resets")
                    .font(.subheadline)
                
                Spacer()
                
                Text(viewModel.nextResetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        } header: {
            Label("Usage", systemImage: "chart.bar.fill")
        }
    }
    
    // MARK: - IQA Feedback Section
    
    private var iqaFeedbackSection: some View {
        Section {
            Toggle("Contribute to AI Training", isOn: $feedbackService.isEnabled)
            
            if feedbackService.isEnabled {
                HStack {
                    Text("Photos Rated")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(feedbackService.totalRatings)")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Upload Queue")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    if uploadQueue.pendingUploads > 0 {
                        HStack(spacing: 4) {
                            Text("\(uploadQueue.pendingUploads)")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            if uploadQueue.isUploading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    } else {
                        Text("Up to date")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Button("View Feedback Data") {
                    viewModel.showFeedbackData()
                }
            }
            
        } header: {
            Label("AI Training", systemImage: "brain")
        } footer: {
            Text("Help improve PhotoStop's AI by sharing anonymous photo quality ratings. Your photos are never uploaded, only ratings and metadata.")
        }
    }
    
    // MARK: - Camera Section
    
    private var cameraSection: some View {
        Section {
            Toggle("Burst Capture", isOn: $viewModel.burstCaptureEnabled)
            
            if viewModel.burstCaptureEnabled {
                Picker("Burst Count", selection: $viewModel.burstCount) {
                    Text("3 frames").tag(3)
                    Text("5 frames").tag(5)
                    Text("7 frames").tag(7)
                }
                
                Toggle("Exposure Bracketing", isOn: $viewModel.exposureBracketingEnabled)
            }
            
            Toggle("Grid Lines", isOn: $viewModel.gridLinesEnabled)
            Toggle("Level Indicator", isOn: $viewModel.levelIndicatorEnabled)
            
        } header: {
            Label("Camera", systemImage: "camera.fill")
        }
    }
    
    // MARK: - AI Enhancement Section
    
    private var aiEnhancementSection: some View {
        Section {
            Picker("Default Quality", selection: $viewModel.defaultQuality) {
                Text("Standard").tag(EditQuality.standard)
                Text("High").tag(EditQuality.high)
            }
            
            Toggle("Auto-enhance After Capture", isOn: $viewModel.autoEnhanceEnabled)
            Toggle("Show Processing Details", isOn: $viewModel.showProcessingDetails)
            Toggle("AI Watermark", isOn: $viewModel.aiWatermarkEnabled)
            
            if viewModel.aiWatermarkEnabled {
                Picker("Watermark Position", selection: $viewModel.watermarkPosition) {
                    Text("Bottom Right").tag(WatermarkPosition.bottomRight)
                    Text("Bottom Left").tag(WatermarkPosition.bottomLeft)
                    Text("Top Right").tag(WatermarkPosition.topRight)
                    Text("Top Left").tag(WatermarkPosition.topLeft)
                }
            }
            
        } header: {
            Label("AI Enhancement", systemImage: "wand.and.stars")
        } footer: {
            if viewModel.aiWatermarkEnabled {
                Text("AI watermark helps identify enhanced photos and complies with platform policies.")
            }
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        Section {
            Button("Privacy Policy") {
                viewModel.openPrivacyPolicy()
            }
            
            Button("Terms of Service") {
                viewModel.openTermsOfService()
            }
            
            Toggle("Analytics", isOn: $viewModel.analyticsEnabled)
            Toggle("Crash Reports", isOn: $viewModel.crashReportsEnabled)
            
        } header: {
            Label("Privacy & Data", systemImage: "hand.raised.fill")
        } footer: {
            Text("PhotoStop processes all photos on-device. Optional analytics help improve the app.")
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        Section {
            Button("Contact Support") {
                viewModel.contactSupport()
            }
            
            Button("Rate PhotoStop") {
                viewModel.rateApp()
            }
            
            Button("Share PhotoStop") {
                viewModel.shareApp()
            }
            
        } header: {
            Label("Support", systemImage: "questionmark.circle.fill")
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text(viewModel.buildNumber)
                    .foregroundColor(.secondary)
            }
            
            Button("Third-Party Licenses") {
                viewModel.showLicenses()
            }
            
        } header: {
            Label("About", systemImage: "info.circle.fill")
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatPreferenceValue(_ value: Float) -> String {
        if abs(value) < 0.05 {
            return "Neutral"
        } else if value > 0 {
            return "Prefers (+\(String(format: "%.1f", value)))"
        } else {
            return "Avoids (\(String(format: "%.1f", value)))"
        }
    }
}

// MARK: - Supporting Views

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}

