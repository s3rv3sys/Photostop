//
//  ResultView.swift
//  PhotoStop - Enhanced with Personalization v1
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI
import Photos

/// Result view for displaying enhanced images with personalization feedback
struct ResultView: View {
    let originalImage: UIImage
    let enhancedImage: UIImage
    let processingDetails: ProcessingDetails?
    
    @StateObject private var socialShareService = SocialShareService.shared
    @StateObject private var storageService = StorageService.shared
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    
    @State private var showingComparison = false
    @State private var showingShareSheet = false
    @State private var showingSaveConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    // NEW: Personalization feedback
    @State private var showingRatingPrompt = false
    @State private var ratingPromptTimer: Timer?
    @State private var hasRated = false
    
    // Social sharing states
    @State private var shareItems: [Any] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Image display area
                    imageDisplayArea(geometry: geometry)
                    
                    // Controls area
                    controlsArea
                }
                
                // NEW: Rating prompt overlay
                if showingRatingPrompt && !hasRated && personalizationEngine.currentProfile().enabled {
                    ratingPromptOverlay
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    // Dismiss view
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Saved!", isPresented: $showingSaveConfirmation) {
            Button("OK") { }
        } message: {
            Text("Photo saved to your library")
        }
        .onAppear {
            setupRatingPrompt()
        }
        .onDisappear {
            ratingPromptTimer?.invalidate()
        }
    }
    
    // MARK: - Image Display Area
    
    private func imageDisplayArea(geometry: GeometryProxy) -> some View {
        ZStack {
            // Main image
            Image(uiImage: showingComparison ? originalImage : enhancedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height * 0.7)
                .clipped()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingComparison.toggle()
                    }
                }
            
            // Comparison indicator
            VStack {
                HStack {
                    Spacer()
                    
                    Text(showingComparison ? "Original" : "Enhanced")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding()
                }
                
                Spacer()
            }
            
            // Processing details overlay
            if let details = processingDetails, !showingComparison {
                VStack {
                    Spacer()
                    
                    HStack {
                        processingDetailsView(details)
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Controls Area
    
    private var controlsArea: some View {
        VStack(spacing: 16) {
            // Comparison toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingComparison.toggle()
                }
            }) {
                HStack {
                    Image(systemName: showingComparison ? "eye.slash" : "eye")
                    Text(showingComparison ? "Show Enhanced" : "Show Original")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            
            // Action buttons
            HStack(spacing: 20) {
                // Save button
                Button(action: saveImage) {
                    VStack(spacing: 4) {
                        Image(systemName: isSaving ? "arrow.down.circle" : "square.and.arrow.down")
                            .font(.title2)
                        Text("Save")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                }
                .disabled(isSaving)
                
                // Instagram Stories
                if socialShareService.canShareToInstagramStories {
                    Button(action: shareToInstagramStories) {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.circle")
                                .font(.title2)
                            Text("Stories")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    }
                }
                
                // TikTok
                if socialShareService.canShareToTikTok {
                    Button(action: shareToTikTok) {
                        VStack(spacing: 4) {
                            Image(systemName: "music.note.tv")
                                .font(.title2)
                            Text("TikTok")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    }
                }
                
                // General share
                Button(action: shareGeneral) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                        Text("Share")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(.black.opacity(0.3))
    }
    
    // MARK: - NEW: Rating Prompt Overlay
    
    private var ratingPromptOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Text("How do you like this pick?")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 24) {
                    // Thumbs down
                    Button(action: { submitRating(.negative) }) {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.title)
                                .foregroundColor(.red)
                            Text("Not great")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Thumbs up
                    Button(action: { submitRating(.positive) }) {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            Text("Love it!")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                Button("Skip") {
                    dismissRatingPrompt()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 40)
            .padding(.bottom, 100)
        }
        .background(.black.opacity(0.5))
        .transition(.opacity.combined(with: .scale))
        .onTapGesture {
            dismissRatingPrompt()
        }
    }
    
    // MARK: - Processing Details View
    
    private func processingDetailsView(_ details: ProcessingDetails) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
                Text(details.providerName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.green)
                Text(String(format: "%.1fs", details.processingTime))
                    .font(.caption)
            }
            
            if let qualityScore = details.qualityScore {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(String(format: "%.0f%%", qualityScore * 100))
                        .font(.caption)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Actions
    
    private func saveImage() {
        isSaving = true
        
        Task {
            do {
                try await storageService.saveToPhotosLibrary(enhancedImage)
                
                await MainActor.run {
                    isSaving = false
                    showingSaveConfirmation = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func shareToInstagramStories() {
        Task {
            do {
                try await socialShareService.shareToInstagramStories(
                    image: enhancedImage,
                    attributionURL: URL(string: "https://photostop.app")
                )
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func shareToTikTok() {
        Task {
            do {
                try await socialShareService.shareToTikTok(
                    image: enhancedImage,
                    caption: "Enhanced with PhotoStop! #PhotoStop #AIPhotography"
                )
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func shareGeneral() {
        shareItems = [enhancedImage]
        showingShareSheet = true
    }
    
    // MARK: - NEW: Personalization Rating Methods
    
    private func setupRatingPrompt() {
        // Show rating prompt after 2 seconds if personalization is enabled
        guard personalizationEngine.currentProfile().enabled else { return }
        
        ratingPromptTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation(.spring()) {
                showingRatingPrompt = true
            }
            
            // Auto-dismiss after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if showingRatingPrompt && !hasRated {
                    dismissRatingPrompt()
                }
            }
        }
    }
    
    private func submitRating(_ feedback: PersonalizationEvent.Feedback) {
        hasRated = true
        
        // Create a simulated FrameBundle.Item for the enhanced image
        let simulatedMetadata = FrameMetadata(
            lens: .wide,
            iso: 400,
            shutterMS: 16.0,
            aperture: 2.8,
            meanLuma: 0.5,
            motionScore: 0.2,
            hasDepth: false,
            depthQuality: 0.0,
            timestamp: Date(),
            isLowLight: false,
            hasMotionBlur: false,
            isPortraitSuitable: false
        )
        
        let frameItem = FrameBundle.Item(
            image: enhancedImage,
            metadata: simulatedMetadata,
            qualityScore: processingDetails?.qualityScore ?? 0.8
        )
        
        // Create and submit personalization event
        let event = PersonalizationEvent.from(item: frameItem, feedback: feedback)
        personalizationEngine.update(with: event)
        
        // Show brief confirmation
        withAnimation(.spring()) {
            showingRatingPrompt = false
        }
        
        // Show thank you message
        let message = feedback == .positive ? 
            "Thanks! We'll improve your picks." : 
            "Got it! We'll adjust your preferences."
        
        // This would show a toast notification
        print("Personalization feedback: \(message)")
    }
    
    private func dismissRatingPrompt() {
        ratingPromptTimer?.invalidate()
        withAnimation(.spring()) {
            showingRatingPrompt = false
        }
    }
}

// MARK: - Supporting Types

struct ProcessingDetails {
    let providerName: String
    let processingTime: TimeInterval
    let qualityScore: Float?
    let metadata: [String: Any]?
}

// MARK: - ActivityViewController

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

struct ResultView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ResultView(
                originalImage: UIImage(systemName: "photo")!,
                enhancedImage: UIImage(systemName: "photo.fill")!,
                processingDetails: ProcessingDetails(
                    providerName: "Gemini 2.5 Flash",
                    processingTime: 2.3,
                    qualityScore: 0.87,
                    metadata: nil
                )
            )
        }
        .preferredColorScheme(.dark)
    }
}

