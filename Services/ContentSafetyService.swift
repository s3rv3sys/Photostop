//
//  ContentSafetyService.swift
//  PhotoStop
//
//  Content filtering and safety compliance for App Store submission
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import UIKit

/// Service for content safety and filtering to ensure App Store compliance
final class ContentSafetyService {
    
    static let shared = ContentSafetyService()
    private init() {}
    
    // MARK: - Content Filtering
    
    /// Inappropriate content keywords to filter
    private let inappropriateKeywords: Set<String> = [
        // Violence
        "violence", "violent", "kill", "murder", "death", "blood", "gore", "weapon",
        "gun", "knife", "bomb", "explosion", "war", "fight", "attack", "assault",
        
        // Adult content
        "nude", "naked", "sex", "sexual", "porn", "adult", "explicit", "erotic",
        "intimate", "seductive", "provocative", "suggestive",
        
        // Hate speech
        "hate", "racist", "discrimination", "offensive", "slur", "bigot",
        
        // Drugs and alcohol
        "drug", "cocaine", "marijuana", "alcohol", "drunk", "high", "smoking",
        "cigarette", "tobacco", "vaping",
        
        // Self-harm
        "suicide", "self-harm", "cutting", "depression", "hurt yourself",
        
        // Illegal activities
        "illegal", "crime", "steal", "robbery", "fraud", "hack", "piracy"
    ]
    
    /// Check if a prompt contains inappropriate content
    func isPromptSafe(_ prompt: String) -> Bool {
        let lowercasePrompt = prompt.lowercased()
        
        // Check for inappropriate keywords
        for keyword in inappropriateKeywords {
            if lowercasePrompt.contains(keyword) {
                return false
            }
        }
        
        // Additional checks for context
        if containsInappropriateContext(lowercasePrompt) {
            return false
        }
        
        return true
    }
    
    /// Filter and sanitize user prompt
    func sanitizePrompt(_ prompt: String) -> String {
        var sanitized = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove excessive punctuation
        sanitized = sanitized.replacingOccurrences(of: "!!!", with: "!")
        sanitized = sanitized.replacingOccurrences(of: "???", with: "?")
        
        // Limit length
        if sanitized.count > 500 {
            sanitized = String(sanitized.prefix(500))
        }
        
        return sanitized
    }
    
    /// Get safe alternative suggestions for inappropriate prompts
    func getSafeAlternatives(for prompt: String) -> [String] {
        let lowercasePrompt = prompt.lowercased()
        
        if lowercasePrompt.contains("violence") || lowercasePrompt.contains("fight") {
            return [
                "Make this photo more dramatic and cinematic",
                "Add action movie style effects",
                "Create an epic adventure scene"
            ]
        }
        
        if lowercasePrompt.contains("adult") || lowercasePrompt.contains("sexy") {
            return [
                "Make this photo more elegant and sophisticated",
                "Add glamorous lighting and style",
                "Create a fashion magazine look"
            ]
        }
        
        if lowercasePrompt.contains("drug") || lowercasePrompt.contains("alcohol") {
            return [
                "Make this photo more vibrant and colorful",
                "Add party atmosphere with confetti",
                "Create a celebration scene"
            ]
        }
        
        return [
            "Enhance the colors and lighting",
            "Make this photo more artistic",
            "Add creative visual effects",
            "Improve the overall composition"
        ]
    }
    
    // MARK: - Image Content Analysis
    
    /// Check if an image might contain inappropriate content
    func analyzeImageContent(_ image: UIImage) -> ContentAnalysisResult {
        // Basic image analysis - in production, you might use Vision framework
        // or cloud-based content moderation APIs
        
        let result = ContentAnalysisResult()
        
        // Check image dimensions (extremely small or large images might be suspicious)
        if image.size.width < 50 || image.size.height < 50 {
            result.flags.append(.suspiciouslySmall)
        }
        
        if image.size.width > 4000 || image.size.height > 4000 {
            result.flags.append(.suspiciouslyLarge)
        }
        
        // Check aspect ratio (extremely wide or tall images might be banners/inappropriate)
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio > 5.0 || aspectRatio < 0.2 {
            result.flags.append(.unusualAspectRatio)
        }
        
        result.isSafe = result.flags.isEmpty || result.flags.allSatisfy { flag in
            switch flag {
            case .suspiciouslySmall, .suspiciouslyLarge, .unusualAspectRatio:
                return true // These are warnings, not blocking issues
            default:
                return false
            }
        }
        
        return result
    }
    
    // MARK: - User Reporting
    
    /// Report inappropriate content
    func reportContent(_ content: ReportableContent, reason: ReportReason) {
        // In production, this would send to your content moderation system
        let report = ContentReport(
            content: content,
            reason: reason,
            timestamp: Date(),
            userID: "anonymous" // Don't collect user IDs for privacy
        )
        
        // Log for review (in production, send to your backend)
        print("Content reported: \(report)")
        
        // Store locally for debugging (remove in production)
        storeReportLocally(report)
    }
    
    // MARK: - Age Rating Compliance
    
    /// Ensure content is appropriate for 12+ age rating
    func isContentAppropriateForAgeRating(_ content: String) -> Bool {
        let lowercaseContent = content.lowercased()
        
        // 12+ rating restrictions
        let restrictedFor12Plus = [
            "violence", "blood", "death", "murder", "weapon", "gun", "knife",
            "adult", "sexual", "nude", "explicit", "drug", "alcohol", "smoking"
        ]
        
        for restricted in restrictedFor12Plus {
            if lowercaseContent.contains(restricted) {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func containsInappropriateContext(_ prompt: String) -> Bool {
        // Check for combinations that might be inappropriate
        let concerningPhrases = [
            "make me look",
            "remove clothes",
            "add weapons",
            "make violent",
            "drug scene",
            "drinking alcohol"
        ]
        
        for phrase in concerningPhrases {
            if prompt.contains(phrase) {
                return true
            }
        }
        
        return false
    }
    
    private func storeReportLocally(_ report: ContentReport) {
        // In development only - remove for production
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsFile = documentsPath.appendingPathComponent("content_reports.json")
        
        var reports: [ContentReport] = []
        
        // Load existing reports
        if let data = try? Data(contentsOf: reportsFile),
           let existingReports = try? JSONDecoder().decode([ContentReport].self, from: data) {
            reports = existingReports
        }
        
        // Add new report
        reports.append(report)
        
        // Save back
        if let data = try? JSONEncoder().encode(reports) {
            try? data.write(to: reportsFile)
        }
    }
}

// MARK: - Supporting Types

struct ContentAnalysisResult {
    var isSafe: Bool = true
    var flags: [ContentFlag] = []
    var confidence: Float = 1.0
}

enum ContentFlag {
    case suspiciouslySmall
    case suspiciouslyLarge
    case unusualAspectRatio
    case potentiallyInappropriate
    case requiresReview
}

enum ReportableContent {
    case prompt(String)
    case image(UIImage)
    case result(UIImage, prompt: String)
}

enum ReportReason: String, CaseIterable {
    case inappropriate = "Inappropriate Content"
    case violence = "Violence"
    case adultContent = "Adult Content"
    case hateSpeech = "Hate Speech"
    case spam = "Spam"
    case other = "Other"
    
    var description: String {
        return self.rawValue
    }
}

struct ContentReport: Codable {
    let id: UUID = UUID()
    let reason: ReportReason
    let timestamp: Date
    let userID: String
    
    // Content details (simplified for JSON encoding)
    let contentType: String
    let contentDescription: String
    
    init(content: ReportableContent, reason: ReportReason, timestamp: Date, userID: String) {
        self.reason = reason
        self.timestamp = timestamp
        self.userID = userID
        
        switch content {
        case .prompt(let prompt):
            self.contentType = "prompt"
            self.contentDescription = prompt
        case .image(_):
            self.contentType = "image"
            self.contentDescription = "User uploaded image"
        case .result(_, let prompt):
            self.contentType = "result"
            self.contentDescription = "Generated result for: \(prompt)"
        }
    }
}

// MARK: - Extensions

extension ContentSafetyService {
    
    /// Get user-friendly message for blocked content
    func getBlockedContentMessage(for prompt: String) -> String {
        let lowercasePrompt = prompt.lowercased()
        
        if lowercasePrompt.contains("violence") || lowercasePrompt.contains("weapon") {
            return "We can't process requests involving violence or weapons. Try asking for dramatic or cinematic effects instead!"
        }
        
        if lowercasePrompt.contains("adult") || lowercasePrompt.contains("explicit") {
            return "We can't process adult or explicit content. Try asking for elegant or glamorous styling instead!"
        }
        
        if lowercasePrompt.contains("drug") || lowercasePrompt.contains("alcohol") {
            return "We can't process requests involving drugs or alcohol. Try asking for party or celebration effects instead!"
        }
        
        return "This request contains content we can't process. Please try a different prompt that focuses on artistic or creative enhancements."
    }
    
    /// Check if app should show content warning
    func shouldShowContentWarning(for prompt: String) -> Bool {
        let borderlineKeywords = ["dark", "scary", "horror", "creepy", "gothic", "dramatic"]
        let lowercasePrompt = prompt.lowercased()
        
        return borderlineKeywords.contains { lowercasePrompt.contains($0) }
    }
    
    /// Get content warning message
    func getContentWarningMessage() -> String {
        return "This enhancement may create dramatic or intense imagery. The result will be appropriate for general audiences."
    }
}

