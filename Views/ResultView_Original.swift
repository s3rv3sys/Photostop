//
//  ResultView.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI
import Photos

/// View for displaying enhanced images with save and share options
struct ResultView: View {
    let originalImage: UIImage
    let enhancedImage: UIImage
    let provider: String
    let processingTime: TimeInterval
    let metadata: [String: String]
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()
    
    @State private var showingBeforeAfter = false
    @State private var showingSaveAlert = false
    @State private var showingShareSheet = false
    @State private var showingPaywall = false
    @State private var showingSocialShare = false
    @State private var saveError: String?
    @State private var shareSourceView: UIView?
    
    // Social sharing
    private let socialShareService = SocialShareService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Enhanced Image Display
                    imageDisplaySection
                    
                    // Before/After Toggle
                    beforeAfterToggleSection
                    
                    // Processing Info
                    processingInfoSection
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    // Social Sharing Buttons
                    socialSharingSection
                    
                    // Metadata (if available)
                    if !metadata.isEmpty {
                        metadataSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Enhanced Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Save to Photos") {
                            saveToPhotos()
                        }
                        
                        Button("Share") {
                            showingShareSheet = true
                        }
                        
                        Button("Edit Again") {
                            // Navigate back to edit view
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Photo Saved", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text("Your enhanced photo has been saved to Photos.")
        }
        .alert("Save Error", isPresented: .constant(saveError != nil)) {
            Button("OK") {
                saveError = nil
            }
        } message: {
            Text(saveError ?? "")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [enhancedImage, "Enhanced with PhotoStop ✨"])
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(context: .general)
        }
        .actionSheet(isPresented: $showingSocialShare) {
            socialShareActionSheet
        }
    }
    
    // MARK: - Image Display Section
    
    private var imageDisplaySection: some View {
        VStack(spacing: 16) {
            // Main Image
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .aspectRatio(enhancedImage.size.width / enhancedImage.size.height, contentMode: .fit)
                
                Image(uiImage: showingBeforeAfter ? originalImage : enhancedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .animation(.easeInOut(duration: 0.3), value: showingBeforeAfter)
            }
            .onTapGesture {
                withAnimation {
                    showingBeforeAfter.toggle()
                }
            }
            
            // Image Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(showingBeforeAfter ? "Original" : "Enhanced")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Tap to compare")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(enhancedImage.size.width)) × \(Int(enhancedImage.size.height))")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("Enhanced by \(provider)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Before/After Toggle Section
    
    private var beforeAfterToggleSection: some View {
        HStack(spacing: 16) {
            Button(action: {
                withAnimation {
                    showingBeforeAfter = false
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    Text("Enhanced")
                        .font(.subheadline)
                        .fontWeight(showingBeforeAfter ? .regular : .semibold)
                }
                .foregroundColor(showingBeforeAfter ? .secondary : .blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(showingBeforeAfter ? Color.clear : Color.blue.opacity(0.1))
                )
            }
            
            Button(action: {
                withAnimation {
                    showingBeforeAfter = true
                }
            }) {
                HStack {
                    Image(systemName: "photo")
                        .font(.caption)
                    Text("Original")
                        .font(.subheadline)
                        .fontWeight(showingBeforeAfter ? .semibold : .regular)
                }
                .foregroundColor(showingBeforeAfter ? .blue : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(showingBeforeAfter ? Color.blue.opacity(0.1) : Color.clear)
                )
            }
            
            Spacer()
        }
    }
    
    // MARK: - Processing Info Section
    
    private var processingInfoSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Processing Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f seconds", processingTime))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("AI Provider")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(provider)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary Actions
            HStack(spacing: 12) {
                Button(action: saveToPhotos) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save to Photos")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: { showingShareSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Edit Again Button
            Button(action: {
                dismiss()
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Edit Again")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemBackground))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Social Sharing Section
    
    private var socialSharingSection: some View {
        VStack(spacing: 16) {
            Text("Share to Social Media")
                .font(.headline)
            
            HStack(spacing: 16) {
                // Instagram Button
                if socialShareService.isInstagramInstalled() {
                    SocialShareButton(
                        platform: .instagram,
                        action: shareToInstagram
                    )
                }
                
                // TikTok Button
                if socialShareService.isTikTokInstalled() {
                    SocialShareButton(
                        platform: .tiktok,
                        action: shareToTikTok
                    )
                }
                
                // More Options Button
                SocialShareButton(
                    platform: nil,
                    action: { showingSocialShare = true }
                )
            }
            
            if !socialShareService.isInstagramInstalled() && !socialShareService.isTikTokInstalled() {
                Text("Install Instagram or TikTok to share directly")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Details")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(Array(metadata.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(metadata[key] ?? "")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    // MARK: - Social Share Action Sheet
    
    private var socialShareActionSheet: ActionSheet {
        var buttons: [ActionSheet.Button] = []
        
        if socialShareService.isInstagramInstalled() {
            buttons.append(.default(Text("Instagram Stories")) {
                shareToInstagram()
            })
            
            buttons.append(.default(Text("Instagram Feed")) {
                shareToInstagramFeed()
            })
        }
        
        if socialShareService.isTikTokInstalled() {
            buttons.append(.default(Text("TikTok")) {
                shareToTikTok()
            })
        }
        
        buttons.append(.default(Text("More Options")) {
            showingShareSheet = true
        })
        
        buttons.append(.cancel())
        
        return ActionSheet(
            title: Text("Share Enhanced Photo"),
            message: Text("Choose where to share your enhanced photo"),
            buttons: buttons
        )
    }
    
    // MARK: - Actions
    
    private func saveToPhotos() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    UIImageWriteToSavedPhotosAlbum(enhancedImage, nil, nil, nil)
                    showingSaveAlert = true
                    
                case .denied, .restricted:
                    saveError = "Photos access is required to save images. Please enable it in Settings."
                    
                case .notDetermined:
                    saveError = "Photos access permission is required."
                    
                @unknown default:
                    saveError = "Unable to save photo."
                }
            }
        }
    }
    
    private func shareToInstagram() {
        do {
            try socialShareService.quickShareToInstagramStories(enhancedImage)
        } catch {
            print("Failed to share to Instagram: \(error)")
            showingShareSheet = true
        }
    }
    
    private func shareToInstagramFeed() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            showingShareSheet = true
            return
        }
        
        do {
            try socialShareService.shareToInstagramFeed(image: enhancedImage, from: rootViewController)
        } catch {
            print("Failed to share to Instagram Feed: \(error)")
            showingShareSheet = true
        }
    }
    
    private func shareToTikTok() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            showingShareSheet = true
            return
        }
        
        do {
            try socialShareService.quickShareToTikTok(enhancedImage, from: rootViewController)
        } catch {
            print("Failed to share to TikTok: \(error)")
            showingShareSheet = true
        }
    }
}

// MARK: - Supporting Views

private struct SocialShareButton: View {
    let platform: SocialShareService.SocialPlatform?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(iconColor)
                
                Text(displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        guard let platform = platform else { return "ellipsis" }
        return platform.iconName
    }
    
    private var iconColor: Color {
        guard let platform = platform else { return .secondary }
        return Color(platform.color)
    }
    
    private var displayName: String {
        guard let platform = platform else { return "More" }
        return platform.displayName
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ResultView(
        originalImage: UIImage(systemName: "photo")!,
        enhancedImage: UIImage(systemName: "sparkles")!,
        provider: "Gemini 2.5 Flash Image",
        processingTime: 3.2,
        metadata: [
            "model": "gemini-2.5-flash-image",
            "strength": "0.8",
            "seed": "12345"
        ]
    )
}

