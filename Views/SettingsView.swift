//
//  SettingsView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// Settings view for app configuration and preferences
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()
    @StateObject private var feedbackService = IQAFeedbackService.shared
    @StateObject private var uploadQueue = UploadQueue.shared
    
    @State private var showPaywall = false
    @State private var showManageSubscription = false
    @State private var showCreditsShop = false
    
    var body: some View {
        List {
            // Account section
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
                .padding(.vertical, 4)
            }
            
            // Usage section
            Section("Usage This Month") {
                UsageRow(
                    title: "Budget AI Credits",
                    used: viewModel.budgetCreditsUsed,
                    total: viewModel.budgetCreditsLimit,
                    color: .blue
                )
                
                UsageRow(
                    title: "Premium AI Credits",
                    used: viewModel.premiumCreditsUsed,
                    total: viewModel.premiumCreditsLimit,
                    color: .purple
                )
                
                if viewModel.addonCredits > 0 {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        
                        Text("Addon Credits")
                        
                        Spacer()
                        
                        Text("\(viewModel.addonCredits)")
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                
                if subscriptionViewModel.currentTier == .free {
                    Button("Buy More Credits") {
                        showCreditsShop = true
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // ML Feedback section
            Section {
                NavigationLink(destination: IQASettingsView()) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Improve Auto-Selection")
                                .font(.system(size: 16, weight: .medium))
                            
                            if feedbackService.isEnabled {
                                Text("\(feedbackService.totalRatings) ratings • \(feedbackService.creditsEarned) credits earned")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Help train better AI models")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if feedbackService.isEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            } header: {
                Text("Machine Learning")
            } footer: {
                Text("Rate photo selections to help improve PhotoStop's AI. Earn bonus credits for contributing feedback.")
            }
            
            // AI Providers section
            Section("AI Enhancement") {
                NavigationLink(destination: AIProvidersView()) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text("AI Providers")
                        
                        Spacer()
                        
                        Text(viewModel.activeProvidersCount)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle("Smart Routing", isOn: $viewModel.smartRoutingEnabled)
                    .onChange(of: viewModel.smartRoutingEnabled) { _, newValue in
                        viewModel.updateSmartRouting(newValue)
                    }
                
                Toggle("Cost Optimization", isOn: $viewModel.costOptimizationEnabled)
                    .onChange(of: viewModel.costOptimizationEnabled) { _, newValue in
                        viewModel.updateCostOptimization(newValue)
                    }
            }
            
            // Camera section
            Section("Camera") {
                Toggle("Burst Mode", isOn: $viewModel.burstModeEnabled)
                    .onChange(of: viewModel.burstModeEnabled) { _, newValue in
                        viewModel.updateBurstMode(newValue)
                    }
                
                Toggle("Auto Flash", isOn: $viewModel.autoFlashEnabled)
                    .onChange(of: viewModel.autoFlashEnabled) { _, newValue in
                        viewModel.updateAutoFlash(newValue)
                    }
                
                Picker("Photo Quality", selection: $viewModel.photoQuality) {
                    ForEach(PhotoQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .onChange(of: viewModel.photoQuality) { _, newValue in
                    viewModel.updatePhotoQuality(newValue)
                }
            }
            
            // Privacy section
            Section("Privacy") {
                NavigationLink(destination: PrivacySettingsView()) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Privacy Settings")
                    }
                }
                
                NavigationLink(destination: DataManagementView()) {
                    HStack {
                        Image(systemName: "externaldrive.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        
                        Text("Data Management")
                    }
                }
            }
            
            // Support section
            Section("Support") {
                Link(destination: URL(string: "https://servesys.com/photostop/help")!) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Help & FAQ")
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "mailto:support@servesys.com?subject=PhotoStop%20Support")!) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Contact Support")
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink(destination: AboutView()) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        
                        Text("About PhotoStop")
                    }
                }
            }
            
            // App info section
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
                
                if feedbackService.contributionEnabled && uploadQueue.pendingUploads > 0 {
                    HStack {
                        Text("Pending Uploads")
                        Spacer()
                        Text("\(uploadQueue.pendingUploads)")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .generalUpgrade)
        }
        .sheet(isPresented: $showManageSubscription) {
            ManageSubscriptionView()
        }
        .sheet(isPresented: $showCreditsShop) {
            CreditsShopView()
        }
        .onAppear {
            viewModel.loadSettings()
        }
    }
}

/// Usage row component
struct UsageRow: View {
    let title: String
    let used: Int
    let total: Int
    let color: Color
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
                
                Text("\(used)/\(total)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(progress > 0.8 ? .red : .secondary)
            }
            
            ProgressView(value: progress)
                .tint(progress > 0.8 ? .red : color)
        }
        .padding(.vertical, 4)
    }
}

/// AI Providers configuration view
struct AIProvidersView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        List {
            Section {
                Text("Configure which AI providers are available for photo enhancement. PhotoStop automatically chooses the best provider based on your preferences and credit availability.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Available Providers") {
                ForEach(viewModel.aiProviders, id: \.name) { provider in
                    ProviderRow(provider: provider) { enabled in
                        viewModel.updateProvider(provider.name, enabled: enabled)
                    }
                }
            }
        }
        .navigationTitle("AI Providers")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadProviders()
        }
    }
}

/// Provider configuration row
struct ProviderRow: View {
    let provider: AIProviderInfo
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(.system(size: 16, weight: .medium))
                
                Text(provider.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(provider.costTier.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(provider.costTier.color.opacity(0.2))
                        .foregroundColor(provider.costTier.color)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    if provider.isRecommended {
                        Text("Recommended")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            
            Spacer()
            
            Toggle("", isOn: .constant(provider.isEnabled))
                .onChange(of: provider.isEnabled) { _, newValue in
                    onToggle(newValue)
                }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

struct PrivacySettingsView: View {
    var body: some View {
        List {
            Section {
                Text("PhotoStop is designed with privacy in mind. Your photos are processed securely and we never store your images without permission.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Privacy settings would go here
            Text("Privacy settings coming soon...")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataManagementView: View {
    var body: some View {
        List {
            Section {
                Text("Manage your local data and cloud sync preferences.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Data management options would go here
            Text("Data management coming soon...")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Text("PhotoStop")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("AI-Powered Photo Enhancement")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            Section("About") {
                Text("PhotoStop uses advanced AI to automatically enhance your photos with professional-quality results. Our smart routing system ensures you get the best enhancement while optimizing costs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Developer") {
                Text("Developed by Servesys Corporation")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        SettingsView()
    }
}

