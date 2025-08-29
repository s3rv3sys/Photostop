//
//  SocialShareService.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import UniformTypeIdentifiers
import os.log

/// Service for sharing images to social media platforms
final class SocialShareService {
    static let shared = SocialShareService()
    
    private let logger = Logger(subsystem: "PhotoStop", category: "SocialShareService")
    
    private init() {}
    
    // MARK: - Platform Detection
    
    /// Check if Instagram is installed
    func isInstagramInstalled() -> Bool {
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// Check if TikTok is installed
    func isTikTokInstalled() -> Bool {
        guard let url = URL(string: "tiktok://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// Get available platforms
    func getAvailablePlatforms() -> [SocialPlatform] {
        var platforms: [SocialPlatform] = []
        
        if isInstagramInstalled() {
            platforms.append(.instagram)
        }
        
        if isTikTokInstalled() {
            platforms.append(.tiktok)
        }
        
        return platforms
    }
    
    // MARK: - Instagram Sharing
    
    /// Share image to Instagram Stories
    func shareToInstagramStories(
        image: UIImage,
        attributionURL: String? = "https://photostop.app",
        stickerImage: UIImage? = nil
    ) throws {
        guard isInstagramInstalled() else {
            throw SocialShareError.appNotInstalled(.instagram)
        }
        
        // Optimize image for Instagram Stories (9:16 aspect ratio)
        let optimizedImage = optimizeImageForInstagramStories(image)
        
        guard let backgroundImageData = optimizedImage.pngData() else {
            throw SocialShareError.imageProcessingFailed
        }
        
        logger.info("Sharing to Instagram Stories")
        
        var pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": backgroundImageData
        ]
        
        // Add sticker overlay if provided
        if let stickerImage = stickerImage,
           let stickerData = stickerImage.pngData() {
            pasteboardItems["com.instagram.sharedSticker.stickerImage"] = stickerData
        }
        
        // Add attribution URL if provided
        if let attributionURL = attributionURL {
            pasteboardItems["com.instagram.sharedSticker.contentURL"] = attributionURL
        }
        
        // Set pasteboard with expiration
        let options = [UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(60)]
        UIPasteboard.general.setItems([pasteboardItems], options: options)
        
        // Open Instagram
        guard let url = URL(string: "instagram-stories://share") else {
            throw SocialShareError.urlCreationFailed
        }
        
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                self.logger.info("Successfully opened Instagram Stories")
            } else {
                self.logger.error("Failed to open Instagram Stories")
            }
        }
    }
    
    /// Share image to Instagram Feed (handoff to composer)
    func shareToInstagramFeed(image: UIImage, from viewController: UIViewController) throws {
        guard isInstagramInstalled() else {
            throw SocialShareError.appNotInstalled(.instagram)
        }
        
        // Optimize image for Instagram Feed
        let optimizedImage = optimizeImageForInstagramFeed(image)
        
        guard let jpegData = optimizedImage.jpegData(compressionQuality: 0.95) else {
            throw SocialShareError.imageProcessingFailed
        }
        
        logger.info("Sharing to Instagram Feed")
        
        // Create temporary file
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("photostop_instagram_\(UUID().uuidString).jpg")
        
        do {
            try jpegData.write(to: tempURL)
        } catch {
            throw SocialShareError.fileWriteFailed(error)
        }
        
        // Use document interaction controller for handoff
        let documentController = UIDocumentInteractionController(url: tempURL)
        documentController.uti = "com.instagram.exclusivegram"
        documentController.annotation = [
            "InstagramCaption": "Enhanced with PhotoStop ✨ #PhotoStop #AIPhotography"
        ]
        
        // Present the share sheet
        if !documentController.presentOpenInMenu(
            from: viewController.view.bounds,
            in: viewController.view,
            animated: true
        ) {
            // Cleanup temp file if sharing failed
            try? FileManager.default.removeItem(at: tempURL)
            throw SocialShareError.sharingFailed
        }
        
        // Schedule cleanup of temp file
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { // 5 minutes
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
    
    // MARK: - TikTok Sharing
    
    /// Share image to TikTok (requires TikTok OpenSDK)
    func shareToTikTok(
        image: UIImage,
        caption: String? = nil,
        from viewController: UIViewController
    ) throws {
        guard isTikTokInstalled() else {
            throw SocialShareError.appNotInstalled(.tiktok)
        }
        
        // Optimize image for TikTok (9:16 aspect ratio preferred)
        let optimizedImage = optimizeImageForTikTok(image)
        
        guard let jpegData = optimizedImage.jpegData(compressionQuality: 0.95) else {
            throw SocialShareError.imageProcessingFailed
        }
        
        logger.info("Sharing to TikTok")
        
        // Create temporary file
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("photostop_tiktok_\(UUID().uuidString).jpg")
        
        do {
            try jpegData.write(to: tempURL)
        } catch {
            throw SocialShareError.fileWriteFailed(error)
        }
        
        // For now, use URL scheme approach (TikTok OpenSDK would be integrated here)
        let finalCaption = caption ?? "Enhanced with PhotoStop ✨ #PhotoStop #AIPhotography"
        
        // Create TikTok share URL with parameters
        var components = URLComponents(string: "tiktok://share")!
        components.queryItems = [
            URLQueryItem(name: "media_type", value: "image"),
            URLQueryItem(name: "caption", value: finalCaption)
        ]
        
        guard let shareURL = components.url else {
            throw SocialShareError.urlCreationFailed
        }
        
        // Store image path for TikTok to access (this is a simplified approach)
        // In a real implementation, you'd use TikTok OpenSDK properly
        UserDefaults.standard.set(tempURL.path, forKey: "photostop_tiktok_temp_image")
        
        UIApplication.shared.open(shareURL, options: [:]) { success in
            if success {
                self.logger.info("Successfully opened TikTok")
            } else {
                self.logger.error("Failed to open TikTok")
                // Cleanup temp file if sharing failed
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
        
        // Schedule cleanup of temp file
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { // 5 minutes
            try? FileManager.default.removeItem(at: tempURL)
            UserDefaults.standard.removeObject(forKey: "photostop_tiktok_temp_image")
        }
    }
    
    // MARK: - Generic Sharing
    
    /// Share image using system share sheet
    func shareWithSystemSheet(
        image: UIImage,
        text: String? = nil,
        from viewController: UIViewController,
        sourceView: UIView? = nil
    ) {
        var items: [Any] = [image]
        
        if let text = text {
            items.append(text)
        }
        
        let activityController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityController.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
        }
        
        viewController.present(activityController, animated: true)
        
        logger.info("Presented system share sheet")
    }
    
    // MARK: - Image Optimization
    
    private func optimizeImageForInstagramStories(_ image: UIImage) -> UIImage {
        let targetSize = CGSize(width: 1080, height: 1920) // 9:16 aspect ratio
        return resizeImage(image, to: targetSize, contentMode: .scaleAspectFill)
    }
    
    private func optimizeImageForInstagramFeed(_ image: UIImage) -> UIImage {
        // Instagram Feed supports various aspect ratios, but 1:1 is most common
        let maxDimension: CGFloat = 1080
        let size = image.size
        
        if size.width > maxDimension || size.height > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            let newSize = CGSize(
                width: size.width * scale,
                height: size.height * scale
            )
            return resizeImage(image, to: newSize, contentMode: .scaleAspectFit)
        }
        
        return image
    }
    
    private func optimizeImageForTikTok(_ image: UIImage) -> UIImage {
        let targetSize = CGSize(width: 1080, height: 1920) // 9:16 aspect ratio preferred
        return resizeImage(image, to: targetSize, contentMode: .scaleAspectFill)
    }
    
    private func resizeImage(
        _ image: UIImage,
        to targetSize: CGSize,
        contentMode: UIView.ContentMode
    ) -> UIImage {
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: targetSize)
            
            switch contentMode {
            case .scaleAspectFit:
                let aspectRatio = image.size.width / image.size.height
                let targetAspectRatio = targetSize.width / targetSize.height
                
                let drawRect: CGRect
                if aspectRatio > targetAspectRatio {
                    // Image is wider than target
                    let height = targetSize.width / aspectRatio
                    drawRect = CGRect(
                        x: 0,
                        y: (targetSize.height - height) / 2,
                        width: targetSize.width,
                        height: height
                    )
                } else {
                    // Image is taller than target
                    let width = targetSize.height * aspectRatio
                    drawRect = CGRect(
                        x: (targetSize.width - width) / 2,
                        y: 0,
                        width: width,
                        height: targetSize.height
                    )
                }
                
                // Fill background with black for letterboxing
                context.cgContext.setFillColor(UIColor.black.cgColor)
                context.cgContext.fill(rect)
                
                image.draw(in: drawRect)
                
            case .scaleAspectFill:
                let aspectRatio = image.size.width / image.size.height
                let targetAspectRatio = targetSize.width / targetSize.height
                
                let drawRect: CGRect
                if aspectRatio > targetAspectRatio {
                    // Image is wider than target, crop sides
                    let width = targetSize.height * aspectRatio
                    drawRect = CGRect(
                        x: -(width - targetSize.width) / 2,
                        y: 0,
                        width: width,
                        height: targetSize.height
                    )
                } else {
                    // Image is taller than target, crop top/bottom
                    let height = targetSize.width / aspectRatio
                    drawRect = CGRect(
                        x: 0,
                        y: -(height - targetSize.height) / 2,
                        width: targetSize.width,
                        height: height
                    )
                }
                
                image.draw(in: drawRect)
                
            default:
                image.draw(in: rect)
            }
        }
    }
}

// MARK: - Supporting Types

extension SocialShareService {
    
    enum SocialPlatform: String, CaseIterable {
        case instagram = "Instagram"
        case tiktok = "TikTok"
        
        var displayName: String {
            return rawValue
        }
        
        var iconName: String {
            switch self {
            case .instagram: return "camera.circle.fill"
            case .tiktok: return "music.note.tv.fill"
            }
        }
        
        var color: UIColor {
            switch self {
            case .instagram: return UIColor.systemPink
            case .tiktok: return UIColor.systemIndigo
            }
        }
        
        var urlScheme: String {
            switch self {
            case .instagram: return "instagram-stories://share"
            case .tiktok: return "tiktok://"
            }
        }
    }
    
    enum SocialShareError: LocalizedError {
        case appNotInstalled(SocialPlatform)
        case imageProcessingFailed
        case fileWriteFailed(Error)
        case urlCreationFailed
        case sharingFailed
        
        var errorDescription: String? {
            switch self {
            case .appNotInstalled(let platform):
                return "\(platform.displayName) is not installed"
            case .imageProcessingFailed:
                return "Failed to process image for sharing"
            case .fileWriteFailed(let error):
                return "Failed to write temporary file: \(error.localizedDescription)"
            case .urlCreationFailed:
                return "Failed to create sharing URL"
            case .sharingFailed:
                return "Failed to initiate sharing"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .appNotInstalled(let platform):
                return "Install \(platform.displayName) from the App Store to share directly"
            case .imageProcessingFailed:
                return "Try again with a different image"
            case .fileWriteFailed:
                return "Check available storage space and try again"
            case .urlCreationFailed, .sharingFailed:
                return "Try again or use the system share sheet"
            }
        }
    }
}

// MARK: - Convenience Methods

extension SocialShareService {
    
    /// Quick share to Instagram Stories with PhotoStop branding
    func quickShareToInstagramStories(_ image: UIImage) throws {
        try shareToInstagramStories(
            image: image,
            attributionURL: "https://photostop.app"
        )
    }
    
    /// Quick share to TikTok with PhotoStop hashtag
    func quickShareToTikTok(_ image: UIImage, from viewController: UIViewController) throws {
        try shareToTikTok(
            image: image,
            caption: "Enhanced with PhotoStop ✨ #PhotoStop #AIPhotography",
            from: viewController
        )
    }
    
    /// Share to all available platforms (presents options)
    func shareToAvailablePlatforms(
        _ image: UIImage,
        from viewController: UIViewController,
        sourceView: UIView? = nil
    ) {
        let availablePlatforms = getAvailablePlatforms()
        
        if availablePlatforms.isEmpty {
            // No social apps installed, use system share sheet
            shareWithSystemSheet(
                image: image,
                text: "Enhanced with PhotoStop ✨",
                from: viewController,
                sourceView: sourceView
            )
            return
        }
        
        // Present action sheet with available platforms
        let alert = UIAlertController(
            title: "Share Photo",
            message: "Choose where to share your enhanced photo",
            preferredStyle: .actionSheet
        )
        
        for platform in availablePlatforms {
            alert.addAction(UIAlertAction(title: platform.displayName, style: .default) { _ in
                do {
                    switch platform {
                    case .instagram:
                        try self.quickShareToInstagramStories(image)
                    case .tiktok:
                        try self.quickShareToTikTok(image, from: viewController)
                    }
                } catch {
                    self.logger.error("Failed to share to \(platform.displayName): \(error)")
                    
                    // Show error and fallback to system share
                    DispatchQueue.main.async {
                        self.shareWithSystemSheet(
                            image: image,
                            text: "Enhanced with PhotoStop ✨",
                            from: viewController,
                            sourceView: sourceView
                        )
                    }
                }
            })
        }
        
        // Add system share option
        alert.addAction(UIAlertAction(title: "More Options", style: .default) { _ in
            self.shareWithSystemSheet(
                image: image,
                text: "Enhanced with PhotoStop ✨",
                from: viewController,
                sourceView: sourceView
            )
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Configure for iPad
        if let popover = alert.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
        }
        
        viewController.present(alert, animated: true)
    }
}

