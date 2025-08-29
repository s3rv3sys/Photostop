//
//  SettingsView.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI

/// Settings and configuration view
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // API Configuration Section
                apiConfigurationSection
                
                // Usage & Subscription Section
                usageSection
                
                // Preferences Section
                preferencesSection
                
                // Permissions Section
                permissionsSection
                
                // Storage Section
                storageSection
                
                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAPIKeyInput) {
            APIKeyInputView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $viewModel.showingAbout) {
            AboutView(viewModel: viewModel)
        }
        .alert("Success", isPresented: $viewModel.showingSuccess) {
            Button("OK") { }
        } message: {
            Text(viewModel.successMessage)
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - API Configuration Section
    private var apiConfigurationSection: some View {
        Section("AI Configuration") {
            HStack {
                Label("Gemini API Key", systemImage: "key")
                Spacer()
                
                if viewModel.isAPIKeyConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Configured")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Not Set")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.showingAPIKeyInput = true
            }
            
            if viewModel.isAPIKeyConfigured {
                Button("Remove API Key", role: .destructive) {
                    viewModel.removeAPIKey()
                }
            }
        }
    }
    
    // MARK: - Usage Section
    private var usageSection: some View {
        Section("Usage & Subscription") {
            HStack {
                Label("Usage This Month", systemImage: "chart.bar")
                Spacer()
                Text("\(viewModel.usageCount) / ∞")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Remaining Free Uses", systemImage: "gift")
                Spacer()
                Text("\(viewModel.remainingFreeUses)")
                    .foregroundColor(viewModel.remainingFreeUses > 5 ? .green : .orange)
            }
            
            if !viewModel.isPremiumUser {
                Button(action: {
                    viewModel.showingSubscription = true
                }) {
                    Label("Upgrade to Premium", systemImage: "crown")
                        .foregroundColor(.orange)
                }
            } else {
                HStack {
                    Label("Premium Active", systemImage: "crown.fill")
                        .foregroundColor(.orange)
                    Spacer()
                    Text("Unlimited")
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Preferences Section
    private var preferencesSection: some View {
        Section("Preferences") {
            Toggle(isOn: $viewModel.autoSaveToPhotos) {
                Label("Auto-save to Photos", systemImage: "photo.on.rectangle")
            }
            .onChange(of: viewModel.autoSaveToPhotos) { _ in
                // Save preference change
            }
            
            Toggle(isOn: $viewModel.enableWatermark) {
                Label("Add Watermark", systemImage: "signature")
            }
            .onChange(of: viewModel.enableWatermark) { _ in
                // Save preference change
            }
            
            Toggle(isOn: $viewModel.enableHapticFeedback) {
                Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
            }
            .onChange(of: viewModel.enableHapticFeedback) { _ in
                // Save preference change
            }
            
            Picker("Image Quality", selection: $viewModel.preferredImageQuality) {
                ForEach(ImageQuality.allCases, id: \.self) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    // MARK: - Permissions Section
    private var permissionsSection: some View {
        Section("Permissions") {
            HStack {
                Label("Camera", systemImage: "camera")
                Spacer()
                Text(viewModel.cameraPermissionStatus)
                    .foregroundColor(viewModel.cameraPermissionStatus == "Authorized" ? .green : .red)
                    .font(.caption)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Task {
                    await viewModel.requestCameraPermission()
                }
            }
            
            HStack {
                Label("Photos", systemImage: "photo.on.rectangle")
                Spacer()
                Text(viewModel.photosPermissionStatus)
                    .foregroundColor(viewModel.photosPermissionStatus.contains("Authorized") ? .green : .red)
                    .font(.caption)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Task {
                    await viewModel.requestPhotosPermission()
                }
            }
        }
    }
    
    // MARK: - Storage Section
    private var storageSection: some View {
        Section("Storage") {
            HStack {
                Label("Storage Used", systemImage: "internaldrive")
                Spacer()
                Text(viewModel.storageUsed)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Edit History", systemImage: "clock.arrow.circlepath")
                Spacer()
                Text("\(viewModel.editHistoryCount) items")
                    .foregroundColor(.secondary)
            }
            
            Button("Clear Edit History", role: .destructive) {
                Task {
                    await viewModel.clearEditHistory()
                }
            }
            
            Button("Cleanup Old Images") {
                Task {
                    await viewModel.cleanupOldImages()
                }
            }
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section("About") {
            Button(action: {
                viewModel.showingAbout = true
            }) {
                Label("About PhotoStop", systemImage: "info.circle")
                    .foregroundColor(.primary)
            }
            
            Button("Privacy Policy") {
                viewModel.showingPrivacyPolicy = true
            }
            
            Button("Terms of Service") {
                viewModel.showingTermsOfService = true
            }
            
            HStack {
                Label("Version", systemImage: "app.badge")
                Spacer()
                Text(viewModel.getAppVersion())
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - API Key Input View
struct APIKeyInputView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Enter your Gemini API key to enable AI image enhancement.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                SecureField("API Key", text: $viewModel.apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("You can get your API key from the Google AI Studio. The key is stored securely in your device's keychain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveAPIKey()
                    }
                    .disabled(viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Subscription View
struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("PhotoStop Premium")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Unlimited AI enhancements")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "infinity", title: "Unlimited AI Enhancements", description: "No monthly limits")
                    FeatureRow(icon: "wand.and.stars", title: "Advanced AI Models", description: "Access to latest AI technology")
                    FeatureRow(icon: "icloud.and.arrow.up", title: "Cloud Sync", description: "Sync your edits across devices")
                    FeatureRow(icon: "person.2", title: "Priority Support", description: "Get help when you need it")
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Pricing
                VStack(spacing: 12) {
                    Text("$4.99/month")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Cancel anytime")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Subscribe button
                Button(action: {
                    // Handle subscription
                }) {
                    Text("Start Free Trial")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App icon and info
                VStack(spacing: 16) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("PhotoStop")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("AI-Powered Photo Enhancement")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // App info
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(viewModel.getAppInfo().keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .fontWeight(.medium)
                            Spacer()
                            Text(viewModel.getAppInfo()[key] ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}

