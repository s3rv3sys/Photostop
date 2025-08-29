//
//  ProcessingOverlay.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// Overlay view showing AI processing status and progress
struct ProcessingOverlay: View {
    let status: String
    let progress: Float
    
    @State private var animationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            // AI Processing Icon
            ZStack {
                // Pulsing background circle
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                
                // AI brain icon
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.blue)
                    .offset(x: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: animationOffset
                    )
            }
            
            // Status text
            VStack(spacing: 8) {
                Text("AI Enhancement")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            // Processing steps indicator
            HStack(spacing: 12) {
                ForEach(0..<3) { index in
                    ProcessingStep(
                        isActive: progress > Float(index) / 3.0,
                        isCompleted: progress > Float(index + 1) / 3.0
                    )
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 10)
        )
        .onAppear {
            pulseScale = 1.2
            animationOffset = 3
        }
    }
}

/// Individual processing step indicator
struct ProcessingStep: View {
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        Circle()
            .fill(stepColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(stepBorderColor, lineWidth: 2)
            )
            .scaleEffect(isActive ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isActive)
    }
    
    private var stepColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    private var stepBorderColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .blue
        } else {
            return .clear
        }
    }
}

/// Processing overlay with different states
struct ProcessingOverlayWithStates: View {
    let processingState: ProcessingState
    
    var body: some View {
        switch processingState {
        case .idle:
            EmptyView()
            
        case .capturing:
            ProcessingOverlay(
                status: "Capturing multiple frames...",
                progress: 0.2
            )
            
        case .analyzing:
            ProcessingOverlay(
                status: "Analyzing image quality...",
                progress: 0.4
            )
            
        case .enhancing(let provider):
            ProcessingOverlay(
                status: "Enhancing with \(provider)...",
                progress: 0.7
            )
            
        case .finalizing:
            ProcessingOverlay(
                status: "Finalizing result...",
                progress: 0.9
            )
            
        case .completed:
            ProcessingOverlay(
                status: "Enhancement complete!",
                progress: 1.0
            )
            
        case .failed(let error):
            ErrorOverlay(error: error)
        }
    }
}

/// Error overlay for failed processing
struct ErrorOverlay: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Enhancement Failed")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 10)
        )
    }
}

/// Processing states enum
enum ProcessingState: Equatable {
    case idle
    case capturing
    case analyzing
    case enhancing(provider: String)
    case finalizing
    case completed
    case failed(error: Error)
    
    static func == (lhs: ProcessingState, rhs: ProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.capturing, .capturing),
             (.analyzing, .analyzing),
             (.finalizing, .finalizing),
             (.completed, .completed):
            return true
        case (.enhancing(let lhsProvider), .enhancing(let rhsProvider)):
            return lhsProvider == rhsProvider
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

#Preview("Processing") {
    ProcessingOverlay(
        status: "Enhancing with AI...",
        progress: 0.6
    )
    .padding()
}

#Preview("Error") {
    ErrorOverlay(error: NSError(domain: "PhotoStop", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network connection failed"]))
        .padding()
}

