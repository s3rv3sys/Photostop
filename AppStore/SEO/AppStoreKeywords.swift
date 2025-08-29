//
//  AppStoreKeywords.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation

/// App Store keyword and metadata configuration
/// Centralized location for all App Store Connect metadata
struct AppStoreKeywords {
    
    // MARK: - App Store Connect Metadata
    
    /// App Name (30 characters max)
    static let appName = "PhotoStop: AI Camera"
    
    /// Subtitle (30 characters max)
    static let subtitle = "One-Tap AI Photo Enhancer"
    
    /// Keywords (100 characters max, comma-separated)
    static let keywords = "AI camera,portrait enhancer,TikTok Instagram photo edit,one tap photo enhancer,smart camera,AI photo"
    
    /// Promotional Text (170 characters max)
    static let promotionalText = "🚀 NEW: Smart AI routing saves you money! PhotoStop automatically chooses the best AI provider for each photo. One tap → professional results → instant share!"
    
    // MARK: - Primary Keywords (High Priority)
    
    static let primaryKeywords = [
        "ai camera",
        "photo enhancer", 
        "portrait editor",
        "instagram photo editor",
        "tiktok photo editor"
    ]
    
    // MARK: - Secondary Keywords (Medium Priority)
    
    static let secondaryKeywords = [
        "one tap photo editor",
        "smart camera app",
        "ai photo filter",
        "automatic photo enhancer",
        "social media photo editor"
    ]
    
    // MARK: - Long-Tail Keywords (Lower Volume, High Intent)
    
    static let longTailKeywords = [
        "ai camera app for instagram",
        "one tap ai photo enhancement", 
        "smart photo editor that learns",
        "multi lens camera app",
        "privacy photo editor ai"
    ]
    
    // MARK: - Competitive Keywords
    
    static let competitiveKeywords = [
        "vsco alternative",
        "lightroom mobile alternative",
        "facetune alternative", 
        "snapseed alternative"
    ]
    
    // MARK: - Category Keywords
    
    static let categoryKeywords = [
        "photography",
        "photo editing",
        "camera app",
        "image enhancement",
        "photo filters"
    ]
    
    // MARK: - Social Media Keywords
    
    static let socialMediaKeywords = [
        "instagram stories",
        "tiktok photo",
        "social media editor",
        "content creator tools",
        "influencer photo editor"
    ]
    
    // MARK: - Feature-Specific Keywords
    
    static let featureKeywords = [
        "ai routing",
        "smart enhancement",
        "personalized photo editor",
        "multi-provider ai",
        "cost-effective ai",
        "on-device personalization"
    ]
    
    // MARK: - Seasonal Keywords (for promotional text updates)
    
    static let seasonalKeywords = [
        "holiday photos": "Perfect your holiday memories with AI enhancement",
        "summer photos": "Make your summer photos shine with smart AI",
        "back to school": "Start the school year with perfect profile pics",
        "new year": "New year, new you - enhance every photo with AI"
    ]
    
    // MARK: - Localization Keywords
    
    static let localizedKeywords = [
        "en-US": keywords,
        "en-GB": "AI camera,portrait enhancer,photo editor,smart camera,one tap enhancer,social media editor",
        "es": "cámara AI,editor fotos,mejorar retratos,editor instagram,cámara inteligente,filtros AI",
        "fr": "appareil photo IA,éditeur photo,améliorer portraits,éditeur instagram,caméra intelligente",
        "de": "KI Kamera,Foto Editor,Portrait Verbesserer,Instagram Editor,intelligente Kamera,KI Filter",
        "ja": "AIカメラ,写真加工,ポートレート編集,インスタ編集,スマートカメラ,AI写真"
    ]
    
    // MARK: - A/B Testing Variations
    
    struct ABTestVariations {
        
        // Subtitle variations for testing
        static let subtitleVariations = [
            "One-Tap AI Photo Enhancer",    // Current
            "AI Photo Editor for Social",    // Social-focused
            "Smart AI Camera & Editor",      // Feature-focused
            "Professional Photo AI"          // Quality-focused
        ]
        
        // Promotional text variations
        static let promotionalTextVariations = [
            // Current (Cost-focused)
            "🚀 NEW: Smart AI routing saves you money! PhotoStop automatically chooses the best AI provider for each photo. One tap → professional results → instant share!",
            
            // Quality-focused
            "✨ Transform any photo into social media gold! Professional AI enhancement with one tap. Perfect for Instagram Stories, TikTok, and more. Try free today!",
            
            // Social-focused
            "📱 The only camera app built for social media! One-tap AI enhancement + instant sharing to Instagram & TikTok. Join thousands of content creators!",
            
            // Privacy-focused
            "🔒 Privacy-first AI photo enhancement! All personalization happens on your device. Smart routing saves money while protecting your photos. Try free!"
        ]
        
        // Keyword variations for testing
        static let keywordVariations = [
            // Current (Balanced)
            "AI camera,portrait enhancer,TikTok Instagram photo edit,one tap photo enhancer,smart camera,AI photo",
            
            // Social-heavy
            "Instagram editor,TikTok photo,social media editor,AI camera,content creator,influencer photo editor",
            
            // Feature-heavy
            "smart AI routing,one tap enhancer,multi provider AI,personalized editor,cost effective AI,privacy camera",
            
            // Competitive
            "VSCO alternative,Lightroom alternative,AI camera,smart photo editor,one tap enhancer,social editor"
        ]
    }
    
    // MARK: - Keyword Density Analysis
    
    /// Analyze keyword density in app description
    static func analyzeKeywordDensity(in text: String) -> [String: Int] {
        let allKeywords = primaryKeywords + secondaryKeywords + longTailKeywords
        var density: [String: Int] = [:]
        
        let lowercaseText = text.lowercased()
        
        for keyword in allKeywords {
            let count = lowercaseText.components(separatedBy: keyword.lowercased()).count - 1
            if count > 0 {
                density[keyword] = count
            }
        }
        
        return density
    }
    
    // MARK: - Validation Methods
    
    /// Validate that metadata fits App Store requirements
    static func validateMetadata() -> [String] {
        var issues: [String] = []
        
        if appName.count > 30 {
            issues.append("App name exceeds 30 characters: \(appName.count)")
        }
        
        if subtitle.count > 30 {
            issues.append("Subtitle exceeds 30 characters: \(subtitle.count)")
        }
        
        if keywords.count > 100 {
            issues.append("Keywords exceed 100 characters: \(keywords.count)")
        }
        
        if promotionalText.count > 170 {
            issues.append("Promotional text exceeds 170 characters: \(promotionalText.count)")
        }
        
        // Check for keyword repetition
        let keywordArray = keywords.components(separatedBy: ",")
        let uniqueKeywords = Set(keywordArray)
        if keywordArray.count != uniqueKeywords.count {
            issues.append("Duplicate keywords found in keyword string")
        }
        
        return issues
    }
    
    // MARK: - Optimization Suggestions
    
    /// Get optimization suggestions based on current metadata
    static func getOptimizationSuggestions() -> [String] {
        var suggestions: [String] = []
        
        // Character count optimization
        let remainingAppName = 30 - appName.count
        let remainingSubtitle = 30 - subtitle.count
        let remainingKeywords = 100 - keywords.count
        let remainingPromo = 170 - promotionalText.count
        
        if remainingAppName > 5 {
            suggestions.append("App name has \(remainingAppName) characters remaining - consider adding descriptive words")
        }
        
        if remainingSubtitle > 5 {
            suggestions.append("Subtitle has \(remainingSubtitle) characters remaining - consider adding value proposition")
        }
        
        if remainingKeywords > 10 {
            suggestions.append("Keywords have \(remainingKeywords) characters remaining - consider adding more relevant terms")
        }
        
        if remainingPromo > 20 {
            suggestions.append("Promotional text has \(remainingPromo) characters remaining - consider adding more compelling copy")
        }
        
        // Keyword coverage analysis
        let keywordArray = keywords.components(separatedBy: ",")
        if !keywordArray.contains(where: { $0.contains("social") }) {
            suggestions.append("Consider adding social media focused keywords")
        }
        
        if !keywordArray.contains(where: { $0.contains("ai") || $0.contains("AI") }) {
            suggestions.append("Ensure AI keywords are prominent for discoverability")
        }
        
        return suggestions
    }
    
    // MARK: - Seasonal Updates
    
    /// Get seasonal promotional text for current time of year
    static func getSeasonalPromotionalText() -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        
        switch month {
        case 12, 1, 2: // Winter/Holiday
            return "🎄 Perfect your holiday memories with AI! PhotoStop's smart routing saves money while delivering professional results. One tap → stunning photos → instant share!"
            
        case 3, 4, 5: // Spring
            return "🌸 Spring into better photos with AI! PhotoStop automatically chooses the best enhancement for each shot. One tap → professional results → social media ready!"
            
        case 6, 7, 8: // Summer
            return "☀️ Make your summer photos shine! Smart AI routing saves money while delivering Instagram-worthy results. Perfect for vacation memories and social sharing!"
            
        case 9, 10, 11: // Fall/Back to School
            return "🍂 Start the season with perfect photos! PhotoStop's AI enhancement makes every shot social media ready. Smart routing saves money while delivering pro results!"
            
        default:
            return promotionalText
        }
    }
}

// MARK: - Usage Examples

/*
// Example usage in App Store Connect:

// Basic metadata
let metadata = AppStoreKeywords.self
print("App Name: \(metadata.appName)")
print("Subtitle: \(metadata.subtitle)")
print("Keywords: \(metadata.keywords)")

// Validation
let issues = AppStoreKeywords.validateMetadata()
if issues.isEmpty {
    print("✅ All metadata validates correctly")
} else {
    print("⚠️ Issues found:")
    issues.forEach { print("  - \($0)") }
}

// Optimization suggestions
let suggestions = AppStoreKeywords.getOptimizationSuggestions()
suggestions.forEach { print("💡 \($0)") }

// Seasonal updates
let seasonalPromo = AppStoreKeywords.getSeasonalPromotionalText()
print("Seasonal Promo: \(seasonalPromo)")

// A/B testing
let testVariation = AppStoreKeywords.ABTestVariations.subtitleVariations.randomElement()
print("Test Subtitle: \(testVariation ?? "")")
*/

