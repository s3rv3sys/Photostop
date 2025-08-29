//
//  AIContentLabeling.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import UIKit
import ImageIO
import UniformTypeIdentifiers
import os.log

/// Service for adding AI content labeling to images and share metadata
final class AIContentLabeling {
    
    static let shared = AIContentLabeling()
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "AIContentLabeling")
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Add AI content metadata to image for sharing
    func addAIContentMetadata(to image: UIImage, provider: String, prompt: String?) -> UIImage {
        logger.info("Adding AI content metadata for provider: \(provider)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            logger.error("Failed to convert image to JPEG data")
            return image
        }
        
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            logger.error("Failed to create CGImageSource")
            return image
        }
        
        // Create mutable metadata
        let mutableMetadata = CGImageMetadataCreateMutable()
        
        // Add AI generation flag
        addAIGenerationFlag(to: mutableMetadata)
        
        // Add provider information
        addProviderInfo(to: mutableMetadata, provider: provider)
        
        // Add prompt if available
        if let prompt = prompt {
            addPromptInfo(to: mutableMetadata, prompt: prompt)
        }
        
        // Add PhotoStop attribution
        addPhotoStopAttribution(to: mutableMetadata)
        
        // Add timestamp
        addTimestamp(to: mutableMetadata)
        
        // Create new image with metadata
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            logger.error("Failed to create image destination")
            return image
        }
        
        // Add image with metadata
        CGImageDestinationAddImageAndMetadata(destination, cgImage, mutableMetadata, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            logger.error("Failed to finalize image destination")
            return image
        }
        
        // Create UIImage from data with metadata
        guard let finalImage = UIImage(data: mutableData as Data) else {
            logger.error("Failed to create final image with metadata")
            return image
        }
        
        logger.info("Successfully added AI content metadata")
        return finalImage
    }
    
    /// Get share text with AI disclosure
    func getShareTextWithDisclosure(originalText: String = "", includeHashtag: Bool = true) -> String {
        var shareText = originalText
        
        // Add AI disclosure
        let disclosure = "✨ Edited with AI"
        if !shareText.isEmpty {
            shareText += "\n\n" + disclosure
        } else {
            shareText = disclosure
        }
        
        // Add PhotoStop hashtag if requested
        if includeHashtag {
            shareText += " #PhotoStop"
        }
        
        return shareText
    }
    
    /// Check if image has AI content metadata
    func hasAIContentMetadata(_ image: UIImage) -> Bool {
        guard let imageData = image.jpegData(compressionQuality: 1.0),
              let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil) else {
            return false
        }
        
        // Check for our AI generation flag
        let aiGeneratedTag = CGImageMetadataTagCreateWithNameAndValue(
            nil,
            "photostop" as CFString,
            "ai_generated" as CFString,
            .string,
            "true" as CFString
        )
        
        return CGImageMetadataContainsTag(metadata, aiGeneratedTag)
    }
    
    // MARK: - Private Methods
    
    /// Add AI generation flag to metadata
    private func addAIGenerationFlag(to metadata: CGMutableImageMetadata) {
        let aiGeneratedTag = CGImageMetadataTagCreateWithNameAndValue(
            nil,
            "photostop" as CFString,
            "ai_generated" as CFString,
            .string,
            "true" as CFString
        )
        
        if let tag = aiGeneratedTag {
            CGImageMetadataSetTagWithPath(metadata, nil, "photostop:ai_generated" as CFString, tag)
        }
    }
    
    /// Add provider information to metadata
    private func addProviderInfo(to metadata: CGMutableImageMetadata, provider: String) {
        let providerTag = CGImageMetadataTagCreateWithNameAndValue(
            nil,
            "photostop" as CFString,
            "ai_provider" as CFString,
            .string,
            provider as CFString
        )
        
        if let tag = providerTag {
            CGImageMetadataSetTagWithPath(metadata, nil, "photostop:ai_provider" as CFString, tag)
        }
    }
    
    /// Add prompt information to metadata
    private func addPromptInfo(to metadata: CGMutableImageMetadata, prompt: String) {
        // Sanitize prompt (remove sensitive information)
        let sanitizedPrompt = sanitizePrompt(prompt)
        
        let promptTag = CGImageMetadataTagCreateWithNameAndValue(
            nil,
            "photostop" as CFString,
            "ai_prompt" as CFString,
            .string,
            sanitizedPrompt as CFString
        )
        
        if let tag = promptTag {
            CGImageMetadataSetTagWithPath(metadata, nil, "photostop:ai_prompt" as CFString, tag)
        }
    }
    
    /// Add PhotoStop attribution to metadata
    private func addPhotoStopAttribution(to metadata: CGMutableImageMetadata) {
        let attributionTag = CGImageMetadataTagCreateWithNameAndValue(
            nil,
            "photostop" as CFString,
            "created_by" as CFString,
            .string,
            "PhotoStop by Servesys Corporation" as CFString
        )
        
        if let tag = attributionTag {
            CGImageMetadataSetTagWithPath(metadata, nil, "photostop:created_by" as CFString, tag)
        }
        
        // Add app version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionTag = CGImageMetadataTagCreateWithNameAndValue(
            nil,
            "photostop" as CFString,
            "app_version" as CFString,
            .string,
            version as CFString
        )
        
        if let tag = versionTag {
            CGImageMetadataSetTagWithPath(metadata, nil, "photostop:app_version" as CFString, tag)
        }
    }
    
    /// Add timestamp to metadata
    private func addTimestamp(to metadata: CGMutableImageMetadata) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        let timestampTag = CGImageMetadataTagCreateWithNameAndValue(
            nil,
            "photostop" as CFString,
            "created_at" as CFString,
            .string,
            timestamp as CFString
        )
        
        if let tag = timestampTag {
            CGImageMetadataSetTagWithPath(metadata, nil, "photostop:created_at" as CFString, tag)
        }
    }
    
    /// Sanitize prompt to remove sensitive information
    private func sanitizePrompt(_ prompt: String) -> String {
        var sanitized = prompt
        
        // Remove potential personal information patterns
        let patterns = [
            "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b", // Email addresses
            "\\b\\d{3}-\\d{3}-\\d{4}\\b", // Phone numbers
            "\\b\\d{4}\\s?\\d{4}\\s?\\d{4}\\s?\\d{4}\\b", // Credit card numbers
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    options: [],
                    range: NSRange(location: 0, length: sanitized.count),
                    withTemplate: "[REDACTED]"
                )
            }
        }
        
        // Limit length
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200)) + "..."
        }
        
        return sanitized
    }
}

// MARK: - Share Extensions

extension AIContentLabeling {
    
    /// Prepare image for Instagram Stories with AI labeling
    func prepareForInstagramStories(_ image: UIImage, provider: String, prompt: String?) -> UIImage {
        logger.info("Preparing image for Instagram Stories with AI labeling")
        
        // Add AI metadata
        let labeledImage = addAIContentMetadata(to: image, provider: provider, prompt: prompt)
        
        // Resize for Instagram Stories (9:16 aspect ratio)
        let targetSize = CGSize(width: 1080, height: 1920)
        let resizedImage = resizeImageForSharing(labeledImage, targetSize: targetSize)
        
        return resizedImage
    }
    
    /// Prepare image for TikTok with AI labeling
    func prepareForTikTok(_ image: UIImage, provider: String, prompt: String?) -> UIImage {
        logger.info("Preparing image for TikTok with AI labeling")
        
        // Add AI metadata
        let labeledImage = addAIContentMetadata(to: image, provider: provider, prompt: prompt)
        
        // Resize for TikTok (9:16 aspect ratio)
        let targetSize = CGSize(width: 1080, height: 1920)
        let resizedImage = resizeImageForSharing(labeledImage, targetSize: targetSize)
        
        return resizedImage
    }
    
    /// Resize image for sharing while maintaining quality
    private func resizeImageForSharing(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { context in
            // Fill background with black for letterboxing
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            
            // Calculate aspect fit rect
            let imageAspect = image.size.width / image.size.height
            let targetAspect = targetSize.width / targetSize.height
            
            let drawRect: CGRect
            if imageAspect > targetAspect {
                // Image is wider - fit to width
                let height = targetSize.width / imageAspect
                let y = (targetSize.height - height) / 2
                drawRect = CGRect(x: 0, y: y, width: targetSize.width, height: height)
            } else {
                // Image is taller - fit to height
                let width = targetSize.height * imageAspect
                let x = (targetSize.width - width) / 2
                drawRect = CGRect(x: x, y: 0, width: width, height: targetSize.height)
            }
            
            image.draw(in: drawRect)
        }
    }
}

