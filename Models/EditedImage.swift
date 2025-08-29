//
//  EditedImage.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import Foundation

/// Represents an image that has been processed and enhanced by AI
struct EditedImage: Identifiable, Codable {
    let id: UUID
    let originalImageData: Data
    let enhancedImageData: Data
    let prompt: String
    let timestamp: Date
    let qualityScore: Float?
    let processingTime: TimeInterval
    
    // Computed properties for UIImage conversion
    var originalImage: UIImage? {
        return UIImage(data: originalImageData)
    }
    
    var enhancedImage: UIImage? {
        return UIImage(data: enhancedImageData)
    }
    
    init(originalImage: UIImage, enhancedImage: UIImage, prompt: String, qualityScore: Float? = nil, processingTime: TimeInterval = 0) {
        self.id = UUID()
        self.originalImageData = originalImage.jpegData(compressionQuality: 0.8) ?? Data()
        self.enhancedImageData = enhancedImage.jpegData(compressionQuality: 0.8) ?? Data()
        self.prompt = prompt
        self.timestamp = Date()
        self.qualityScore = qualityScore
        self.processingTime = processingTime
    }
    
    /// File size in bytes for the enhanced image
    var fileSizeBytes: Int {
        return enhancedImageData.count
    }
    
    /// Human readable file size
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSizeBytes))
    }
}

// MARK: - EditedImage Extensions
extension EditedImage {
    /// Creates a preview version with reduced quality for thumbnails
    func createPreview(maxSize: CGSize = CGSize(width: 300, height: 300)) -> EditedImage? {
        guard let enhanced = enhancedImage,
              let original = originalImage else { return nil }
        
        let previewEnhanced = enhanced.resized(to: maxSize)
        let previewOriginal = original.resized(to: maxSize)
        
        return EditedImage(
            originalImage: previewOriginal,
            enhancedImage: previewEnhanced,
            prompt: prompt,
            qualityScore: qualityScore,
            processingTime: processingTime
        )
    }
}

// MARK: - UIImage Extension for Resizing
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

