//
//  ResultView.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI

/// View for displaying enhanced image results with save/share options
struct ResultView: View {
    let image: UIImage
    let originalImage: UIImage?
    
    @StateObject private var editViewModel = EditViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingShareSheet = false
    @State private var showingEditPrompt = false
    @State private var showingComparison = false
    @State private var saveSuccess = false
    @State private var saveError: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Image display area
                    imageDisplayArea
                    
                    // Controls
                    controlsArea
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [image])
        }
        .sheet(isPresented: $showingEditPrompt) {
            EditPromptView(image: image, editViewModel: editViewModel)
        }
        .alert("Saved!", isPresented: $saveSuccess) {
            Button("OK") { }
        } message: {
            Text("Image saved to Photos successfully")
        }
        .alert("Save Error", isPresented: .constant(saveError != nil)) {
            Button("OK") {
                saveError = nil
            }
        } message: {
            if let error = saveError {
                Text(error)
            }
        }
    }
    
    // MARK: - Image Display Area
    private var imageDisplayArea: some View {
        GeometryReader { geometry in
            ZStack {
                if showingComparison, let original = originalImage {
                    // Before/After comparison
                    HStack(spacing: 2) {
                        // Original image
                        VStack {
                            Text("Original")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.bottom, 4)
                            
                            Image(uiImage: original)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geometry.size.width / 2 - 1)
                        }
                        
                        // Enhanced image
                        VStack {
                            Text("Enhanced")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.bottom, 4)
                            
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geometry.size.width / 2 - 1)
                        }
                    }
                } else {
                    // Single enhanced image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingComparison.toggle()
            }
        }
    }
    
    // MARK: - Controls Area
    private var controlsArea: some View {
        VStack(spacing: 16) {
            // Comparison toggle (if original available)
            if originalImage != nil {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingComparison.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: showingComparison ? "eye.slash" : "eye")
                        Text(showingComparison ? "Hide Comparison" : "Show Comparison")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                }
            }
            
            // Action buttons
            HStack(spacing: 20) {
                // Save button
                Button(action: saveToPhotos) {
                    VStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2)
                        Text("Save")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.blue)
                    .clipShape(Circle())
                }
                
                // Share button
                Button(action: {
                    showingShareSheet = true
                }) {
                    VStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                        Text("Share")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.green)
                    .clipShape(Circle())
                }
                
                // Edit more button
                Button(action: {
                    showingEditPrompt = true
                }) {
                    VStack {
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                        Text("Edit More")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.purple)
                    .clipShape(Circle())
                }
                
                // Close button
                Button(action: {
                    dismiss()
                }) {
                    VStack {
                        Image(systemName: "xmark")
                            .font(.title2)
                        Text("Close")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.gray)
                    .clipShape(Circle())
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Helper Methods
    private func saveToPhotos() {
        Task {
            let storageService = StorageService()
            let success = await storageService.saveToPhotos(image)
            
            await MainActor.run {
                if success {
                    saveSuccess = true
                } else {
                    saveError = "Failed to save image to Photos. Please check permissions."
                }
            }
        }
    }
}

// MARK: - Edit Prompt View
struct EditPromptView: View {
    let image: UIImage
    @ObservedObject var editViewModel: EditViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: PromptCategory = .general
    @State private var customPrompt = ""
    @State private var showingCustomInput = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(PromptCategory.allCases, id: \.self) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Prompts list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(editViewModel.getPromptsForCategory(selectedCategory)) { prompt in
                            PromptCard(prompt: prompt) {
                                Task {
                                    await editViewModel.applyPrompt(prompt, to: image)
                                    if editViewModel.editedImage != nil {
                                        dismiss()
                                    }
                                }
                            }
                        }
                        
                        // Custom prompt button
                        if selectedCategory == .custom {
                            Button(action: {
                                showingCustomInput = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text("Add Custom Prompt")
                                }
                                .foregroundColor(.blue)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Edit with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCustomInput) {
            CustomPromptInputView(
                prompt: $customPrompt,
                onApply: {
                    editViewModel.customPrompt = customPrompt
                    Task {
                        await editViewModel.applyCustomPrompt(to: image)
                        if editViewModel.editedImage != nil {
                            dismiss()
                        }
                    }
                }
            )
        }
        .overlay {
            if editViewModel.isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay(
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Enhancing image...")
                                .foregroundColor(.white)
                                .padding(.top)
                        }
                    )
            }
        }
    }
}

// MARK: - Prompt Card
struct PromptCard: View {
    let prompt: EditPrompt
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: prompt.category.icon)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    if prompt.usageCount > 0 {
                        Text("\(prompt.usageCount) uses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(prompt.text)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Custom Prompt Input View
struct CustomPromptInputView: View {
    @Binding var prompt: String
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $prompt)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Custom Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    ResultView(
        image: UIImage(systemName: "photo")!,
        originalImage: UIImage(systemName: "photo.fill")!
    )
}

