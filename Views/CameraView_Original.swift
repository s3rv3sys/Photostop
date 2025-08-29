//
//  CameraView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI
import AVFoundation

/// Main camera view with live preview and capture functionality
struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var feedbackService = IQAFeedbackService.shared
    
    @State private var showRatingView = false
    @State private var capturedImage: UIImage?
    @State private var frameScore: FrameScore?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                CameraPreviewView(session: viewModel.captureSession)
                    .ignoresSafeArea()
                    .onAppear {
                        viewModel.startSession()
                    }
                    .onDisappear {
                        viewModel.stopSession()
                    }
                
                // Overlay UI
                VStack {
                    // Top controls
                    HStack {
                        // Flash toggle
                        Button {
                            viewModel.toggleFlash()
                        } label: {
                            Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.black.opacity(0.3), in: Circle())
                        }
                        .accessibilityLabel(viewModel.isFlashOn ? "Turn off flash" : "Turn on flash")
                        
                        Spacer()
                        
                        // Settings button
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.black.opacity(0.3), in: Circle())
                        }
                        .accessibilityLabel("Settings")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Processing overlay
                    if viewModel.isProcessing {
                        ProcessingOverlay(
                            status: viewModel.processingStatus,
                            progress: viewModel.processingProgress
                        )
                        .transition(.opacity)
                    }
                    
                    Spacer()
                    
                    // Bottom controls
                    VStack(spacing: 20) {
                        // Rating view (if enabled and image captured)
                        if feedbackService.isEnabled && showRatingView && capturedImage != nil {
                            RatePickView(
                                onRate: { rating, reason in
                                    handleRating(rating: rating, reason: reason)
                                },
                                onDismiss: {
                                    showRatingView = false
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Capture button
                        CaptureButton(
                            isProcessing: viewModel.isProcessing,
                            onCapture: {
                                Task {
                                    await capturePhoto()
                                }
                            }
                        )
                        .disabled(viewModel.isProcessing)
                        
                        // Gallery button
                        NavigationLink(destination: GalleryView()) {
                            Text("Gallery")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 20))
                        }
                        .accessibilityLabel("View gallery")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Camera Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func capturePhoto() async {
        let result = await viewModel.capturePhoto()
        
        switch result {
        case .success(let enhancedImage):
            // Store for potential rating
            capturedImage = enhancedImage.image
            frameScore = enhancedImage.frameScore
            
            // Show rating UI if feedback is enabled
            if feedbackService.isEnabled {
                withAnimation(.spring()) {
                    showRatingView = true
                }
                
                // Auto-hide after 10 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    if showRatingView {
                        withAnimation(.spring()) {
                            showRatingView = false
                        }
                    }
                }
            }
            
        case .failure(let error):
            print("Capture failed: \(error)")
        }
    }
    
    private func handleRating(rating: Bool, reason: RatingReason?) {
        guard let image = capturedImage,
              let score = frameScore else {
            return
        }
        
        // Process feedback through FrameScoringService
        FrameScoringService.shared.processFeedback(
            selectedImage: image,
            userRating: rating,
            reason: reason,
            feedback: nil,
            modelScore: score.score
        )
        
        withAnimation(.spring()) {
            showRatingView = false
        }
        
        // Clear stored data
        capturedImage = nil
        frameScore = nil
    }
}

/// Camera preview using AVFoundation
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.frame
        }
    }
}

/// Processing status overlay
struct ProcessingOverlay: View {
    let status: String
    let progress: Double
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text(status)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

/// Capture button with processing state
struct CaptureButton: View {
    let isProcessing: Bool
    let onCapture: () -> Void
    
    var body: some View {
        Button(action: onCapture) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(.black.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(1.2)
                } else {
                    Circle()
                        .fill(.black)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .disabled(isProcessing)
        .scaleEffect(isProcessing ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isProcessing)
        .accessibilityLabel("Capture photo")
        .accessibilityAddTraits(isProcessing ? [.notEnabled] : [])
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        CameraView()
    }
}

