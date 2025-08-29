//
//  CameraView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI
import AVFoundation

/// Main camera view with live preview and capture controls
struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()
            
            // Processing overlay
            if viewModel.isProcessing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProcessingOverlay(
                    status: viewModel.processingStatus,
                    progress: viewModel.processingProgress
                )
            }
            
            // Camera controls
            VStack {
                // Top controls
                HStack {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(.black.opacity(0.3)))
                    }
                    
                    Spacer()
                    
                    Button(action: viewModel.toggleFlash) {
                        Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.isFlashOn ? .yellow : .white)
                            .padding(12)
                            .background(Circle().fill(.black.opacity(0.3)))
                    }
                    
                    Button(action: viewModel.switchCamera) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(.black.opacity(0.3)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 20) {
                    // Enhancement options (if not processing)
                    if !viewModel.isProcessing {
                        EnhancementOptionsView(
                            selectedTask: $viewModel.selectedTask,
                            customPrompt: $viewModel.customPrompt,
                            useHighQuality: $viewModel.useHighQuality
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Capture button
                    CaptureButton(
                        isProcessing: viewModel.isProcessing,
                        onCapture: viewModel.captureAndEnhance
                    )
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $viewModel.showingResult) {
            if let originalImage = viewModel.originalImage,
               let enhancedImage = viewModel.enhancedImage {
                ResultView(
                    originalImage: originalImage,
                    enhancedImage: enhancedImage
                )
            }
        }
        .sheet(isPresented: $viewModel.showingPaywall) {
            PaywallView(context: .insufficientCredits)
                .onDisappear {
                    // Handle purchase success if needed
                    if !viewModel.showingPaywall {
                        viewModel.handlePurchaseSuccess()
                    }
                }
        }
        .errorOverlay(error: $viewModel.currentError) {
            viewModel.retryEnhancement()
        }
    }
}

/// Enhancement options panel
struct EnhancementOptionsView: View {
    @Binding var selectedTask: EditTask
    @Binding var customPrompt: String
    @Binding var useHighQuality: Bool
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Toggle button
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Enhancement Options")
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black.opacity(0.5))
                )
            }
            
            // Options panel
            if isExpanded {
                VStack(spacing: 16) {
                    // Task selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enhancement Type")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(EditTask.allCases, id: \.self) { task in
                                    TaskButton(
                                        task: task,
                                        isSelected: selectedTask == task,
                                        onTap: { selectedTask = task }
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    
                    // Custom prompt
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Prompt (Optional)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        TextField("Describe your enhancement...", text: $customPrompt)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Quality toggle
                    HStack {
                        Text("High Quality")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Toggle("", isOn: $useHighQuality)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.7))
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
}

/// Task selection button
struct TaskButton: View {
    let task: EditTask
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(task.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? .white : .white.opacity(0.2))
                )
        }
    }
}

#Preview {
    CameraView()
}

