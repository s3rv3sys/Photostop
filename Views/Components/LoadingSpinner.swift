//
//  LoadingSpinner.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// Customizable loading spinner with different styles
struct LoadingSpinner: View {
    let style: LoadingStyle
    let message: String?
    
    @State private var isAnimating = false
    
    init(style: LoadingStyle = .standard, message: String? = nil) {
        self.style = style
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            spinnerView
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @ViewBuilder
    private var spinnerView: some View {
        switch style {
        case .standard:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
        case .dots:
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            .onAppear { isAnimating = true }
            
        case .pulse:
            Circle()
                .fill(Color.blue.opacity(0.6))
                .frame(width: 40, height: 40)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 0.3 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear { isAnimating = true }
            
        case .rotating:
            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 1.0).repeatForever(autoreverses: false),
                    value: isAnimating
                )
                .onAppear { isAnimating = true }
            
        case .brain:
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.blue)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear { isAnimating = true }
        }
    }
}

/// Loading overlay that covers the entire screen
struct LoadingOverlay: View {
    let message: String
    let style: LoadingStyle
    
    init(_ message: String, style: LoadingStyle = .standard) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                LoadingSpinner(style: style)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(radius: 10)
            )
            .padding(.horizontal, 40)
        }
    }
}

/// Inline loading view for smaller spaces
struct InlineLoadingView: View {
    let message: String
    let style: LoadingStyle
    
    init(_ message: String, style: LoadingStyle = .dots) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        HStack(spacing: 12) {
            LoadingSpinner(style: style)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
    }
}

/// Loading button that shows spinner when processing
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    LoadingSpinner(style: .dots)
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .frame(minWidth: 120, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isLoading ? Color.gray : Color.blue)
            )
            .foregroundColor(.white)
        }
        .disabled(isLoading)
    }
}

/// Different loading spinner styles
enum LoadingStyle {
    case standard    // System ProgressView
    case dots        // Animated dots
    case pulse       // Pulsing circle
    case rotating    // Rotating arrow
    case brain       // AI brain icon (for PhotoStop)
}

/// Loading state management
class LoadingState: ObservableObject {
    @Published var isLoading = false
    @Published var message = ""
    @Published var style: LoadingStyle = .standard
    
    func start(_ message: String, style: LoadingStyle = .standard) {
        DispatchQueue.main.async {
            self.message = message
            self.style = style
            self.isLoading = true
        }
    }
    
    func stop() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.message = ""
        }
    }
    
    func update(_ message: String) {
        DispatchQueue.main.async {
            self.message = message
        }
    }
}

#Preview("Styles") {
    VStack(spacing: 30) {
        LoadingSpinner(style: .standard, message: "Loading...")
        LoadingSpinner(style: .dots, message: "Processing...")
        LoadingSpinner(style: .pulse, message: "Analyzing...")
        LoadingSpinner(style: .rotating, message: "Syncing...")
        LoadingSpinner(style: .brain, message: "AI Enhancement...")
    }
    .padding()
}

#Preview("Overlay") {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        LoadingOverlay("Enhancing your photo with AI...", style: .brain)
    }
}

#Preview("Inline") {
    VStack(spacing: 20) {
        InlineLoadingView("Saving to Photos...")
        InlineLoadingView("Uploading to cloud...", style: .rotating)
        InlineLoadingView("Processing feedback...", style: .brain)
    }
    .padding()
}

