//
//  CameraView.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI
import AVFoundation

/// Main camera view with live preview and one-tap capture
struct CameraView: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var showingPermissionAlert = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(viewModel: viewModel)
                .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top status bar
                topStatusBar
                
                Spacer()
                
                // Bottom controls
                bottomControls
            }
            .padding()
            
            // Processing overlay
            if viewModel.isCapturing || viewModel.isProcessing {
                processingOverlay
            }
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("PhotoStop needs camera access to capture and enhance your photos. Please enable camera permission in Settings.")
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            Task {
                await viewModel.startCamera()
                if !viewModel.cameraPermissionGranted {
                    showingPermissionAlert = true
                }
            }
        }
        .onDisappear {
            viewModel.stopCamera()
        }
    }
    
    // MARK: - Top Status Bar
    private var topStatusBar: some View {
        HStack {
            // AI Service Status
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isAIServiceReady() ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.isAIServiceReady() ? "AI Ready" : "AI Unavailable")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())
            
            Spacer()
            
            // Remaining uses
            if viewModel.isAIServiceReady() {
                Text("\(viewModel.getRemainingUses()) uses left")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Status message
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
            
            // Progress bar (when processing)
            if viewModel.isCapturing || viewModel.isProcessing {
                ProgressView(value: viewModel.captureProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(maxWidth: 200)
            }
            
            // Main capture button
            Button(action: {
                Task {
                    await viewModel.captureAndEnhance()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 90, height: 90)
                    
                    if viewModel.isCapturing || viewModel.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundColor(.black)
                    }
                }
            }
            .disabled(viewModel.isCapturing || viewModel.isProcessing || !viewModel.isAIServiceReady())
            .scaleEffect(viewModel.isCapturing || viewModel.isProcessing ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: viewModel.isCapturing || viewModel.isProcessing)
        }
    }
    
    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text(viewModel.statusMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if viewModel.captureProgress > 0 {
                        ProgressView(value: viewModel.captureProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(maxWidth: 200)
                    }
                }
                .padding(32)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            )
    }
    
    // MARK: - Helper Methods
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let viewModel: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        if let previewLayer = viewModel.getPreviewLayer() {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame if needed
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Preview
#Preview {
    CameraView(viewModel: CameraViewModel())
}

