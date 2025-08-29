//
//  EnhancementOptionsView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// Enhancement options selector for camera capture
struct EnhancementOptionsView: View {
    @Binding var selectedTask: EditTask
    @Binding var customPrompt: String
    @Binding var useHighQuality: Bool
    
    @State private var showingCustomPrompt = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Quick enhancement buttons
            if !isExpanded {
                HStack(spacing: 12) {
                    // Quick options
                    QuickOptionButton(
                        task: .portraitEnhance,
                        selectedTask: $selectedTask,
                        icon: "person.crop.circle",
                        title: "Portrait"
                    )
                    
                    QuickOptionButton(
                        task: .hdrEnhance,
                        selectedTask: $selectedTask,
                        icon: "camera.filters",
                        title: "HDR"
                    )
                    
                    QuickOptionButton(
                        task: .cleanup,
                        selectedTask: $selectedTask,
                        icon: "moon.stars",
                        title: "Cleanup"
                    )
                    
                    // More options button
                    Button(action: { withAnimation(.spring()) { isExpanded = true } }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.3))
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
            } else {
                // Expanded options
                VStack(spacing: 16) {
                    // Close button
                    HStack {
                        Spacer()
                        Button(action: { withAnimation(.spring()) { isExpanded = false } }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Circle().fill(.black.opacity(0.3)))
                        }
                    }
                    
                    // Enhancement type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enhancement Type")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(EditTask.allCases, id: \.self) { task in
                                EnhancementTypeButton(
                                    task: task,
                                    selectedTask: $selectedTask
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    // Custom prompt section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Custom Prompt")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Button(action: { showingCustomPrompt.toggle() }) {
                                Image(systemName: showingCustomPrompt ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        if showingCustomPrompt {
                            TextField("Describe how you want to enhance this photo...", text: $customPrompt, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    // Quality toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("High Quality")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("Uses premium AI for best results")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $useHighQuality)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
}

// MARK: - Quick Option Button

struct QuickOptionButton: View {
    let task: EditTask
    @Binding var selectedTask: EditTask
    let icon: String
    let title: String
    
    private var isSelected: Bool {
        selectedTask == task
    }
    
    var body: some View {
        Button(action: { selectedTask = task }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .white)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .blue : .white)
            }
            .frame(width: 60, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? .white.opacity(0.2) : .black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? .blue : .white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhancement Type Button

struct EnhancementTypeButton: View {
    let task: EditTask
    @Binding var selectedTask: EditTask
    
    private var isSelected: Bool {
        selectedTask == task
    }
    
    private var taskInfo: (icon: String, title: String, color: Color) {
        switch task {
        case .simpleEnhance:
            return ("wand.and.stars", "Auto", .blue)
        case .portraitEnhance:
            return ("person.crop.circle", "Portrait", .green)
        case .hdrEnhance:
            return ("camera.filters", "HDR", .orange)
        case .cleanup:
            return ("moon.stars", "Cleanup", .purple)
        case .backgroundRemoval:
            return ("scissors", "Remove BG", .pink)
        case .creative:
            return ("paintbrush", "Creative", .yellow)
        case .localEdit:
            return ("location", "Local Edit", .red)
        }
    }
    
    var body: some View {
        Button(action: { selectedTask = task }) {
            VStack(spacing: 6) {
                Image(systemName: taskInfo.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? taskInfo.color : .white)
                
                Text(taskInfo.title)
                    .font(.caption2)
                    .foregroundColor(isSelected ? taskInfo.color : .white)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? taskInfo.color.opacity(0.2) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? taskInfo.color : .white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            EnhancementOptionsView(
                selectedTask: .constant(.portraitEnhance),
                customPrompt: .constant(""),
                useHighQuality: .constant(false)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

