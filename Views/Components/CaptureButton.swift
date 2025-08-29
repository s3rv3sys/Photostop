//
//  CaptureButton.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// Main capture button with processing state and haptic feedback
struct CaptureButton: View {
    let isProcessing: Bool
    let onCapture: () -> Void
    
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    
    private let buttonSize: CGFloat = 80
    private let ringSize: CGFloat = 100
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                .frame(width: ringSize, height: ringSize)
            
            // Processing ring (animated)
            if isProcessing {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(.degrees(pulseScale * 360))
                    .animation(
                        .linear(duration: 1.0).repeatForever(autoreverses: false),
                        value: pulseScale
                    )
            }
            
            // Main button
            Button(action: handleCapture) {
                ZStack {
                    // Button background
                    Circle()
                        .fill(buttonColor)
                        .frame(width: buttonSize, height: buttonSize)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isPressed)
                    
                    // Button content
                    if isProcessing {
                        // Processing state - AI icon
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .scaleEffect(pulseScale)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: pulseScale
                            )
                    } else {
                        // Idle state - camera icon
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(isProcessing)
            .pressEvents(
                onPress: { isPressed = true },
                onRelease: { isPressed = false }
            )
        }
        .onAppear {
            if isProcessing {
                pulseScale = 1.1
            }
        }
        .onChange(of: isProcessing) { processing in
            if processing {
                pulseScale = 1.1
            } else {
                pulseScale = 1.0
            }
        }
    }
    
    private var buttonColor: Color {
        if isProcessing {
            return .blue
        } else {
            return .white
        }
    }
    
    private func handleCapture() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Trigger capture
        onCapture()
    }
}

/// Capture button with different styles
struct CaptureButtonStyle: View {
    let style: CaptureButtonStyleType
    let isProcessing: Bool
    let onCapture: () -> Void
    
    var body: some View {
        switch style {
        case .standard:
            CaptureButton(isProcessing: isProcessing, onCapture: onCapture)
            
        case .compact:
            CompactCaptureButton(isProcessing: isProcessing, onCapture: onCapture)
            
        case .minimal:
            MinimalCaptureButton(isProcessing: isProcessing, onCapture: onCapture)
        }
    }
}

/// Compact version for smaller spaces
struct CompactCaptureButton: View {
    let isProcessing: Bool
    let onCapture: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onCapture) {
            ZStack {
                Circle()
                    .fill(isProcessing ? .blue : .white)
                    .frame(width: 60, height: 60)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
                
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
            }
        }
        .disabled(isProcessing)
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

/// Minimal version for toolbar
struct MinimalCaptureButton: View {
    let isProcessing: Bool
    let onCapture: () -> Void
    
    var body: some View {
        Button(action: onCapture) {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.blue)
                }
                
                Text(isProcessing ? "Processing..." : "Capture")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
            )
        }
        .disabled(isProcessing)
    }
}

/// Button style types
enum CaptureButtonStyleType {
    case standard
    case compact
    case minimal
}

/// Press event modifier for button interactions
struct PressEventModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventModifier(onPress: onPress, onRelease: onRelease))
    }
}

#Preview("Standard") {
    VStack(spacing: 40) {
        CaptureButton(isProcessing: false, onCapture: {})
        CaptureButton(isProcessing: true, onCapture: {})
    }
    .padding()
    .background(Color.black)
}

#Preview("Styles") {
    VStack(spacing: 40) {
        CaptureButtonStyle(style: .standard, isProcessing: false, onCapture: {})
        CaptureButtonStyle(style: .compact, isProcessing: false, onCapture: {})
        CaptureButtonStyle(style: .minimal, isProcessing: false, onCapture: {})
    }
    .padding()
}

