//
//  EditPrompt.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import Foundation

/// Represents a prompt for AI image editing with predefined and custom options
struct EditPrompt: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let category: PromptCategory
    let isCustom: Bool
    let usageCount: Int
    let lastUsed: Date?
    
    init(text: String, category: PromptCategory = .general, isCustom: Bool = false, usageCount: Int = 0, lastUsed: Date? = nil) {
        self.id = UUID()
        self.text = text
        self.category = category
        self.isCustom = isCustom
        self.usageCount = usageCount
        self.lastUsed = lastUsed
    }
    
    /// Updates usage statistics
    func withUpdatedUsage() -> EditPrompt {
        return EditPrompt(
            text: self.text,
            category: self.category,
            isCustom: self.isCustom,
            usageCount: self.usageCount + 1,
            lastUsed: Date()
        )
    }
}

/// Categories for organizing prompts
enum PromptCategory: String, CaseIterable, Codable {
    case general = "General"
    case portrait = "Portrait"
    case landscape = "Landscape"
    case artistic = "Artistic"
    case vintage = "Vintage"
    case professional = "Professional"
    case creative = "Creative"
    case custom = "Custom"
    
    var icon: String {
        switch self {
        case .general: return "wand.and.stars"
        case .portrait: return "person.crop.circle"
        case .landscape: return "mountain.2"
        case .artistic: return "paintbrush"
        case .vintage: return "camera.vintage"
        case .professional: return "briefcase"
        case .creative: return "lightbulb"
        case .custom: return "pencil"
        }
    }
}

// MARK: - Predefined Prompts
extension EditPrompt {
    /// Default enhancement prompt used for one-tap capture
    static let defaultEnhancement = EditPrompt(
        text: "Enhance photo for best quality: adjust lighting, sharpness, color, denoise if needed.",
        category: .general
    )
    
    /// Collection of predefined prompts for different use cases
    static let predefinedPrompts: [EditPrompt] = [
        // General
        EditPrompt(text: "Enhance photo for best quality: adjust lighting, sharpness, color, denoise if needed.", category: .general),
        EditPrompt(text: "Make this photo more vibrant and sharp", category: .general),
        EditPrompt(text: "Improve lighting and reduce noise", category: .general),
        
        // Portrait
        EditPrompt(text: "Enhance portrait: smooth skin, brighten eyes, perfect lighting", category: .portrait),
        EditPrompt(text: "Professional headshot enhancement with natural skin tone", category: .portrait),
        EditPrompt(text: "Soften harsh shadows on face, enhance natural beauty", category: .portrait),
        
        // Landscape
        EditPrompt(text: "Enhance landscape: vivid colors, sharp details, dramatic sky", category: .landscape),
        EditPrompt(text: "Make sunset colors more dramatic and vibrant", category: .landscape),
        EditPrompt(text: "Enhance nature photo with rich greens and clear details", category: .landscape),
        
        // Artistic
        EditPrompt(text: "Apply artistic enhancement with creative color grading", category: .artistic),
        EditPrompt(text: "Make this photo look like a painting", category: .artistic),
        EditPrompt(text: "Add cinematic color grading and mood", category: .artistic),
        
        // Vintage
        EditPrompt(text: "Apply vintage film look with warm tones", category: .vintage),
        EditPrompt(text: "Create retro aesthetic with faded colors", category: .vintage),
        EditPrompt(text: "Add film grain and vintage color palette", category: .vintage),
        
        // Professional
        EditPrompt(text: "Professional photo editing: perfect exposure, color correction", category: .professional),
        EditPrompt(text: "Commercial quality enhancement for business use", category: .professional),
        EditPrompt(text: "Studio-quality lighting and color correction", category: .professional)
    ]
    
    /// Get prompts by category
    static func prompts(for category: PromptCategory) -> [EditPrompt] {
        return predefinedPrompts.filter { $0.category == category }
    }
    
    /// Get most recently used prompts
    static func recentPrompts(from prompts: [EditPrompt], limit: Int = 5) -> [EditPrompt] {
        return prompts
            .filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? Date.distantPast) > ($1.lastUsed ?? Date.distantPast) }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Get most popular prompts
    static func popularPrompts(from prompts: [EditPrompt], limit: Int = 5) -> [EditPrompt] {
        return prompts
            .sorted { $0.usageCount > $1.usageCount }
            .prefix(limit)
            .map { $0 }
    }
}

