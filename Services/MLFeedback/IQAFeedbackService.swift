//
//  IQAFeedbackService.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import UIKit
import OSLog

/// Service for collecting and managing Image Quality Assessment feedback
@MainActor
final class IQAFeedbackService: ObservableObject {
    
    static let shared = IQAFeedbackService()
    
    @Published var isEnabled: Bool = false
    @Published var contributionEnabled: Bool = false
    @Published var totalRatings: Int = 0
    @Published var creditsEarned: Int = 0
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "IQAFeedback")
    private let fileManager = FileManager.default
    private let installID = UUID().uuidString // Generate once per install
    
    // File paths
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var iqaBaseURL: URL {
        documentsURL.appendingPathComponent("PhotoStopIQA")
    }
    
    private var exportURL: URL {
        iqaBaseURL.appendingPathComponent("export")
    }
    
    private var csvURL: URL {
        exportURL.appendingPathComponent("train.csv")
    }
    
    private var uploadQueueURL: URL {
        iqaBaseURL.appendingPathComponent("upload_queue.json")
    }
    
    private var settingsURL: URL {
        iqaBaseURL.appendingPathComponent("settings.json")
    }
    
    private init() {
        setupDirectories()
        loadSettings()
    }
    
    // MARK: - Setup
    
    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: iqaBaseURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
            logger.info("IQA directories created successfully")
        } catch {
            logger.error("Failed to create IQA directories: \(error.localizedDescription)")
        }
    }
    
    private func loadSettings() {
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            // First time setup
            saveSettings()
            return
        }
        
        do {
            let data = try Data(contentsOf: settingsURL)
            let settings = try JSONDecoder().decode(IQASettings.self, from: data)
            
            self.isEnabled = settings.isEnabled
            self.contributionEnabled = settings.contributionEnabled
            self.totalRatings = settings.totalRatings
            self.creditsEarned = settings.creditsEarned
            
            logger.info("IQA settings loaded: enabled=\(self.isEnabled), ratings=\(self.totalRatings)")
        } catch {
            logger.error("Failed to load IQA settings: \(error.localizedDescription)")
        }
    }
    
    private func saveSettings() {
        let settings = IQASettings(
            isEnabled: isEnabled,
            contributionEnabled: contributionEnabled,
            totalRatings: totalRatings,
            creditsEarned: creditsEarned
        )
        
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL)
            logger.info("IQA settings saved")
        } catch {
            logger.error("Failed to save IQA settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Interface
    
    func enableFeedback(_ enabled: Bool) {
        isEnabled = enabled
        saveSettings()
        logger.info("IQA feedback \(enabled ? "enabled" : "disabled")")
    }
    
    func enableContribution(_ enabled: Bool) {
        contributionEnabled = enabled
        saveSettings()
        logger.info("IQA contribution \(enabled ? "enabled" : "disabled")")
    }
    
    func saveRating(
        image: UIImage,
        score: Float,
        meta: IQAMeta,
        reason: RatingReason? = nil,
        feedback: String? = nil
    ) {
        guard isEnabled else {
            logger.warning("Attempted to save rating but IQA feedback is disabled")
            return
        }
        
        let sample = IQASample(
            relpath: "\(UUID().uuidString).jpg",
            score: score,
            meta: meta,
            reasonCode: reason?.rawValue,
            userFeedback: feedback
        )
        
        // Save image thumbnail
        saveImageThumbnail(image, filename: sample.relpath)
        
        // Append to CSV
        appendToCSV(sample: sample)
        
        // Update counters
        totalRatings += 1
        
        // Award credits (1 per 5 ratings, max 20 per month)
        let newCredits = totalRatings / 5
        if newCredits > creditsEarned && creditsEarned < 20 {
            creditsEarned = min(newCredits, 20)
            // Award the credit through UsageTracker
            Task {
                await UsageTracker.shared.addBonusCredits(1)
            }
            logger.info("Awarded bonus credit for IQA feedback")
        }
        
        saveSettings()
        
        // Queue for upload if contribution is enabled
        if contributionEnabled {
            queueForUpload(sample: sample, imageData: image.jpegData(compressionQuality: 0.6) ?? Data())
        }
        
        logger.info("IQA rating saved: score=\(score), reason=\(reason?.rawValue ?? "none")")
    }
    
    func saveFrameComparison(
        selectedImage: UIImage,
        rejectedImages: [UIImage],
        selectedMeta: IQAMeta,
        rejectedMetas: [IQAMeta]
    ) {
        guard isEnabled else { return }
        
        // Rate selected frame as 0.9 (high quality)
        saveRating(image: selectedImage, score: 0.9, meta: selectedMeta)
        
        // Rate rejected frames as 0.3 (lower quality)
        for (image, meta) in zip(rejectedImages, rejectedMetas) {
            saveRating(image: image, score: 0.3, meta: meta)
        }
        
        logger.info("Frame comparison saved: 1 selected, \(rejectedImages.count) rejected")
    }
    
    // MARK: - Data Export
    
    func exportData() -> URL? {
        guard fileManager.fileExists(atPath: csvURL.path) else {
            logger.warning("No IQA data to export")
            return nil
        }
        
        let exportName = "PhotoStopIQA_\(ISO8601DateFormatter().string(from: Date())).zip"
        let zipURL = documentsURL.appendingPathComponent(exportName)
        
        // Create zip archive (simplified - in production use a proper zip library)
        do {
            let csvData = try Data(contentsOf: csvURL)
            try csvData.write(to: zipURL) // Simplified - should be actual zip
            logger.info("IQA data exported to \(zipURL.lastPathComponent)")
            return zipURL
        } catch {
            logger.error("Failed to export IQA data: \(error.localizedDescription)")
            return nil
        }
    }
    
    func clearLocalData() {
        do {
            if fileManager.fileExists(atPath: exportURL.path) {
                try fileManager.removeItem(at: exportURL)
                try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
            }
            
            totalRatings = 0
            creditsEarned = 0
            saveSettings()
            
            logger.info("IQA local data cleared")
        } catch {
            logger.error("Failed to clear IQA data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveImageThumbnail(_ image: UIImage, filename: String) {
        // Resize to 384px width for privacy and storage efficiency
        let targetWidth: CGFloat = 384
        let aspectRatio = image.size.height / image.size.width
        let targetHeight = targetWidth * aspectRatio
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let thumbnailData = thumbnail?.jpegData(compressionQuality: 0.6) else {
            logger.error("Failed to create thumbnail data")
            return
        }
        
        let imageURL = exportURL.appendingPathComponent(filename)
        do {
            try thumbnailData.write(to: imageURL)
        } catch {
            logger.error("Failed to save thumbnail: \(error.localizedDescription)")
        }
    }
    
    private func appendToCSV(sample: IQASample) {
        let csvExists = fileManager.fileExists(atPath: csvURL.path)
        
        // Create header if file doesn't exist
        if !csvExists {
            let header = "relpath,score,device,iso,shutter_ms,mean_luma,width,height,ts,reason,feedback\n"
            do {
                try header.write(to: csvURL, atomically: true, encoding: .utf8)
            } catch {
                logger.error("Failed to create CSV header: \(error.localizedDescription)")
                return
            }
        }
        
        // Append row
        let formatter = ISO8601DateFormatter()
        let row = "\(sample.relpath),\(sample.score),\(sample.meta.device),\(sample.meta.iso ?? 0),\(sample.meta.shutterMS ?? 0),\(sample.meta.meanLuma),\(sample.meta.imageWidth),\(sample.meta.imageHeight),\(formatter.string(from: sample.meta.timestamp)),\(sample.reasonCode ?? ""),\(sample.userFeedback ?? "")\n"
        
        do {
            let existingContent = try String(contentsOf: csvURL, encoding: .utf8)
            let newContent = existingContent + row
            try newContent.write(to: csvURL, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed to append to CSV: \(error.localizedDescription)")
        }
    }
    
    private func queueForUpload(sample: IQASample, imageData: Data) {
        let uploadItem = IQAUploadItem(sample: sample, imageData: imageData, installID: installID)
        
        // Load existing queue
        var queue: [IQAUploadItem] = []
        if fileManager.fileExists(atPath: uploadQueueURL.path) {
            do {
                let data = try Data(contentsOf: uploadQueueURL)
                queue = try JSONDecoder().decode([IQAUploadItem].self, from: data)
            } catch {
                logger.error("Failed to load upload queue: \(error.localizedDescription)")
            }
        }
        
        // Add new item
        queue.append(uploadItem)
        
        // Save queue
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: uploadQueueURL)
            logger.info("IQA sample queued for upload")
        } catch {
            logger.error("Failed to save upload queue: \(error.localizedDescription)")
        }
        
        // Trigger upload attempt
        Task {
            await processUploadQueue()
        }
    }
    
    private func processUploadQueue() async {
        // Implementation would handle actual uploads to server
        // For now, just log the intent
        logger.info("Processing IQA upload queue (server upload not implemented)")
    }
}

// MARK: - Supporting Types

private struct IQASettings: Codable {
    let isEnabled: Bool
    let contributionEnabled: Bool
    let totalRatings: Int
    let creditsEarned: Int
}

