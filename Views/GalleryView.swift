//
//  GalleryView.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI

/// Gallery view for browsing edit history and saved images
struct GalleryView: View {
    @StateObject private var editViewModel = EditViewModel()
    @State private var selectedImage: EditedImage?
    @State private var showingImageDetail = false
    @State private var searchText = ""
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                if editViewModel.editHistory.isEmpty {
                    emptyStateView
                } else {
                    // Search bar
                    searchBar
                    
                    // Gallery grid
                    galleryGrid
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sort by Date") {
                            // Sort by date
                        }
                        Button("Sort by Quality") {
                            // Sort by quality score
                        }
                        Divider()
                        Button("Clear All", role: .destructive) {
                            clearAllImages()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingImageDetail) {
            if let selectedImage = selectedImage {
                ImageDetailView(editedImage: selectedImage, editViewModel: editViewModel)
            }
        }
        .onAppear {
            editViewModel.loadEditHistory()
        }
        .refreshable {
            editViewModel.loadEditHistory()
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Enhanced Images")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your AI-enhanced photos will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search by prompt...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
    
    // MARK: - Gallery Grid
    private var galleryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredImages) { editedImage in
                    GalleryThumbnail(editedImage: editedImage) {
                        selectedImage = editedImage
                        showingImageDetail = true
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    private var filteredImages: [EditedImage] {
        if searchText.isEmpty {
            return editViewModel.editHistory
        } else {
            return editViewModel.editHistory.filter { image in
                image.prompt.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func clearAllImages() {
        Task {
            for image in editViewModel.editHistory {
                await editViewModel.deleteFromHistory(image)
            }
        }
    }
}

// MARK: - Gallery Thumbnail
struct GalleryThumbnail: View {
    let editedImage: EditedImage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Image
                if let image = editedImage.enhancedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 110, height: 110)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 110, height: 110)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                // Quality indicator
                VStack {
                    HStack {
                        Spacer()
                        if let score = editedImage.qualityScore {
                            QualityBadge(score: score)
                        }
                    }
                    Spacer()
                }
                .padding(6)
                
                // Date overlay
                VStack {
                    Spacer()
                    HStack {
                        Text(formatDate(editedImage.timestamp))
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Capsule())
                        Spacer()
                    }
                }
                .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Quality Badge
struct QualityBadge: View {
    let score: Float
    
    var body: some View {
        Text(String(format: "%.0f%%", score * 100))
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor)
            .clipShape(Capsule())
    }
    
    private var badgeColor: Color {
        switch score {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .blue
        case 0.4..<0.6:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - Image Detail View
struct ImageDetailView: View {
    let editedImage: EditedImage
    @ObservedObject var editViewModel: EditViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingShareSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingComparison = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    // Image display
                    imageDisplayArea
                    
                    // Image info
                    imageInfoArea
                    
                    // Action buttons
                    actionButtons
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = editedImage.enhancedImage {
                ShareSheet(items: [image])
            }
        }
        .alert("Delete Image", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await editViewModel.deleteFromHistory(editedImage)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this enhanced image?")
        }
    }
    
    // MARK: - Image Display Area
    private var imageDisplayArea: some View {
        GeometryReader { geometry in
            ZStack {
                if showingComparison {
                    // Before/After comparison
                    HStack(spacing: 2) {
                        // Original
                        VStack {
                            Text("Original")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.bottom, 4)
                            
                            if let original = editedImage.originalImage {
                                Image(uiImage: original)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width / 2 - 1)
                            }
                        }
                        
                        // Enhanced
                        VStack {
                            Text("Enhanced")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.bottom, 4)
                            
                            if let enhanced = editedImage.enhancedImage {
                                Image(uiImage: enhanced)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width / 2 - 1)
                            }
                        }
                    }
                } else {
                    // Single enhanced image
                    if let image = editedImage.enhancedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    }
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
    
    // MARK: - Image Info Area
    private var imageInfoArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Prompt
            Text("Prompt:")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(editedImage.prompt)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            // Details
            HStack {
                VStack(alignment: .leading) {
                    Text("Quality Score")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let score = editedImage.qualityScore {
                        Text(String(format: "%.1f%%", score * 100))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    } else {
                        Text("N/A")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("File Size")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(editedImage.fileSizeString)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Date")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(formatDate(editedImage.timestamp))
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 20) {
            // Save to Photos
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
            
            // Share
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
            
            // Delete
            Button(action: {
                showingDeleteAlert = true
            }) {
                VStack {
                    Image(systemName: "trash")
                        .font(.title2)
                    Text("Delete")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.red)
                .clipShape(Circle())
            }
            
            // Close
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
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Helper Methods
    private func saveToPhotos() {
        guard let image = editedImage.enhancedImage else { return }
        
        Task {
            let storageService = StorageService()
            await storageService.saveToPhotos(image)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    GalleryView()
}

