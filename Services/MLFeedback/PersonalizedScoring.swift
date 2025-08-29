//
//  PersonalizedScoring.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import UIKit
import OSLog

/// User preferences for personalized frame scoring
struct UserScoringPreferences: Codable {
    var exposureWeight: Float = 0.0      // -1.0 to 1.0 (darker to brighter preference)
    var sharpnessWeight: Float = 0.0     // -1.0 to 1.0 (softer to sharper preference)
    var contrastWeight: Float = 0.0      // -1.0 to 1.0 (lower to higher contrast)
    var saturationWeight: Float = 0.0    // -1.0 to 1.0 (muted to vibrant preference)
    var noiseWeight: Float = 0.0         // -1.0 to 1.0 (tolerance for noise)
    
    var totalRatings: Int = 0
    var lastUpdated: Date = Date()
    
    /// Apply learning rate decay as user provides more ratings
    var learningRate: Float {
        let baseRate: Float = 0.1
        let decayFactor: Float = 0.95
        let iterations = Float(totalRatings / 10) // Decay every 10 ratings
        return baseRate * pow(decayFactor, iterations)
    }
}

/// Image features for personalized scoring
struct ImageFeatures {
    let exposure: Float      // 0.0 to 1.0 (dark to bright)
    let sharpness: Float     // 0.0 to 1.0 (blurry to sharp)
    let contrast: Float      // 0.0 to 1.0 (low to high contrast)
    let saturation: Float    // 0.0 to 1.0 (muted to vibrant)
    let noise: Float         // 0.0 to 1.0 (clean to noisy)
}

/// Service for personalized frame scoring based on user preferences
@MainActor
final class PersonalizedScoringService: ObservableObject {
    
    static let shared = PersonalizedScoringService()
    
    @Published var preferences = UserScoringPreferences()
    @Published var isEnabled: Bool = true
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "PersonalizedScoring")
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "PersonalizedScoringPreferences"
    
    private init() {
        loadPreferences()
    }
    
    // MARK: - Public Interface
    
    /// Apply personalized bias to base Core ML score
    func personalizeScore(_ baseScore: Float, for image: UIImage) -> Float {
        guard isEnabled else { return baseScore }
        
        let features = extractFeatures(from: image)
        let personalizedBias = calculatePersonalizedBias(features: features)
        
        let finalScore = min(1.0, max(0.0, baseScore + personalizedBias))
        
        logger.debug("Personalized scoring: base=\(baseScore), bias=\(personalizedBias), final=\(finalScore)")
        
        return finalScore
    }
    
    /// Update preferences based on user rating
    func updatePreferences(
        image: UIImage,
        userRating: Float, // 0.0 to 1.0
        modelScore: Float  // 0.0 to 1.0
    ) {
        let features = extractFeatures(from: image)
        let error = userRating - modelScore
        let learningRate = preferences.learningRate
        
        // Update weights based on error and image features
        preferences.exposureWeight += learningRate * error * (features.exposure - 0.5) * 2.0
        preferences.sharpnessWeight += learningRate * error * (features.sharpness - 0.5) * 2.0
        preferences.contrastWeight += learningRate * error * (features.contrast - 0.5) * 2.0
        preferences.saturationWeight += learningRate * error * (features.saturation - 0.5) * 2.0
        preferences.noiseWeight += learningRate * error * (features.noise - 0.5) * 2.0
        
        // Clamp weights to [-1.0, 1.0]
        preferences.exposureWeight = max(-1.0, min(1.0, preferences.exposureWeight))
        preferences.sharpnessWeight = max(-1.0, min(1.0, preferences.sharpnessWeight))
        preferences.contrastWeight = max(-1.0, min(1.0, preferences.contrastWeight))
        preferences.saturationWeight = max(-1.0, min(1.0, preferences.saturationWeight))
        preferences.noiseWeight = max(-1.0, min(1.0, preferences.noiseWeight))
        
        preferences.totalRatings += 1
        preferences.lastUpdated = Date()
        
        savePreferences()
        
        logger.info("Updated personalized preferences: exposure=\(preferences.exposureWeight), sharpness=\(preferences.sharpnessWeight), ratings=\(preferences.totalRatings)")
    }
    
    /// Reset preferences to default
    func resetPreferences() {
        preferences = UserScoringPreferences()
        savePreferences()
        logger.info("Personalized preferences reset to default")
    }
    
    /// Get user preference summary for display
    func getPreferenceSummary() -> String {
        guard preferences.totalRatings > 0 else {
            return "No personalization data yet"
        }
        
        var summary: [String] = []
        
        if abs(preferences.exposureWeight) > 0.2 {
            summary.append(preferences.exposureWeight > 0 ? "Prefers brighter images" : "Prefers darker images")
        }
        
        if abs(preferences.sharpnessWeight) > 0.2 {
            summary.append(preferences.sharpnessWeight > 0 ? "Prefers sharper images" : "Prefers softer images")
        }
        
        if abs(preferences.contrastWeight) > 0.2 {
            summary.append(preferences.contrastWeight > 0 ? "Prefers high contrast" : "Prefers low contrast")
        }
        
        if abs(preferences.saturationWeight) > 0.2 {
            summary.append(preferences.saturationWeight > 0 ? "Prefers vibrant colors" : "Prefers muted colors")
        }
        
        if summary.isEmpty {
            return "Balanced preferences across all features"
        }
        
        return summary.joined(separator: ", ")
    }
    
    // MARK: - Private Methods
    
    private func calculatePersonalizedBias(features: ImageFeatures) -> Float {
        let exposureBias = preferences.exposureWeight * (features.exposure - 0.5) * 2.0
        let sharpnessBias = preferences.sharpnessWeight * (features.sharpness - 0.5) * 2.0
        let contrastBias = preferences.contrastWeight * (features.contrast - 0.5) * 2.0
        let saturationBias = preferences.saturationWeight * (features.saturation - 0.5) * 2.0
        let noiseBias = preferences.noiseWeight * (features.noise - 0.5) * 2.0
        
        // Weight the bias by 0.15 to keep it subtle
        let totalBias = 0.15 * (exposureBias + sharpnessBias + contrastBias + saturationBias + noiseBias) / 5.0
        
        return totalBias
    }
    
    private func extractFeatures(from image: UIImage) -> ImageFeatures {
        guard let cgImage = image.cgImage else {
            return ImageFeatures(exposure: 0.5, sharpness: 0.5, contrast: 0.5, saturation: 0.5, noise: 0.5)
        }
        
        // Simplified feature extraction - in production, use more sophisticated algorithms
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &pixelData,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            return ImageFeatures(exposure: 0.5, sharpness: 0.5, contrast: 0.5, saturation: 0.5, noise: 0.5)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Calculate basic features
        var totalLuminance: Float = 0.0
        var totalSaturation: Float = 0.0
        var luminanceValues: [Float] = []
        
        let pixelCount = width * height
        
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = Float(pixelData[i]) / 255.0
            let g = Float(pixelData[i + 1]) / 255.0
            let b = Float(pixelData[i + 2]) / 255.0
            
            // Luminance (ITU-R BT.709)
            let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            totalLuminance += luminance
            luminanceValues.append(luminance)
            
            // Saturation (simplified)
            let maxRGB = max(r, max(g, b))
            let minRGB = min(r, min(g, b))
            let saturation = maxRGB > 0 ? (maxRGB - minRGB) / maxRGB : 0
            totalSaturation += saturation
        }
        
        let avgLuminance = totalLuminance / Float(pixelCount)
        let avgSaturation = totalSaturation / Float(pixelCount)
        
        // Calculate contrast (standard deviation of luminance)
        var luminanceVariance: Float = 0.0
        for luminance in luminanceValues {
            let diff = luminance - avgLuminance
            luminanceVariance += diff * diff
        }
        let contrast = sqrt(luminanceVariance / Float(pixelCount))
        
        // Simplified sharpness estimation (edge detection would be better)
        let sharpness = calculateSimpleSharpness(pixelData: pixelData, width: width, height: height)
        
        // Simplified noise estimation
        let noise = calculateSimpleNoise(pixelData: pixelData, width: width, height: height)
        
        return ImageFeatures(
            exposure: avgLuminance,
            sharpness: sharpness,
            contrast: min(1.0, contrast * 4.0), // Scale contrast
            saturation: avgSaturation,
            noise: noise
        )
    }
    
    private func calculateSimpleSharpness(pixelData: [UInt8], width: Int, height: Int) -> Float {
        // Simplified Laplacian edge detection
        var totalEdgeStrength: Float = 0.0
        let bytesPerPixel = 4
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let centerIndex = (y * width + x) * bytesPerPixel
                let centerLuma = Float(pixelData[centerIndex]) * 0.299 + Float(pixelData[centerIndex + 1]) * 0.587 + Float(pixelData[centerIndex + 2]) * 0.114
                
                // Sample neighboring pixels
                let topIndex = ((y - 1) * width + x) * bytesPerPixel
                let bottomIndex = ((y + 1) * width + x) * bytesPerPixel
                let leftIndex = (y * width + (x - 1)) * bytesPerPixel
                let rightIndex = (y * width + (x + 1)) * bytesPerPixel
                
                let topLuma = Float(pixelData[topIndex]) * 0.299 + Float(pixelData[topIndex + 1]) * 0.587 + Float(pixelData[topIndex + 2]) * 0.114
                let bottomLuma = Float(pixelData[bottomIndex]) * 0.299 + Float(pixelData[bottomIndex + 1]) * 0.587 + Float(pixelData[bottomIndex + 2]) * 0.114
                let leftLuma = Float(pixelData[leftIndex]) * 0.299 + Float(pixelData[leftIndex + 1]) * 0.587 + Float(pixelData[leftIndex + 2]) * 0.114
                let rightLuma = Float(pixelData[rightIndex]) * 0.299 + Float(pixelData[rightIndex + 1]) * 0.587 + Float(pixelData[rightIndex + 2]) * 0.114
                
                // Laplacian kernel
                let edgeStrength = abs(4 * centerLuma - topLuma - bottomLuma - leftLuma - rightLuma)
                totalEdgeStrength += edgeStrength
            }
        }
        
        let avgEdgeStrength = totalEdgeStrength / Float((width - 2) * (height - 2))
        return min(1.0, avgEdgeStrength / 100.0) // Normalize
    }
    
    private func calculateSimpleNoise(pixelData: [UInt8], width: Int, height: Int) -> Float {
        // Simplified noise estimation using local variance
        var totalVariance: Float = 0.0
        let bytesPerPixel = 4
        let windowSize = 3
        
        for y in windowSize..<(height - windowSize) {
            for x in windowSize..<(width - windowSize) {
                var localLuminances: [Float] = []
                
                // Sample local window
                for dy in -windowSize...windowSize {
                    for dx in -windowSize...windowSize {
                        let index = ((y + dy) * width + (x + dx)) * bytesPerPixel
                        let luma = Float(pixelData[index]) * 0.299 + Float(pixelData[index + 1]) * 0.587 + Float(pixelData[index + 2]) * 0.114
                        localLuminances.append(luma)
                    }
                }
                
                // Calculate local variance
                let mean = localLuminances.reduce(0, +) / Float(localLuminances.count)
                let variance = localLuminances.map { pow($0 - mean, 2) }.reduce(0, +) / Float(localLuminances.count)
                totalVariance += variance
            }
        }
        
        let avgVariance = totalVariance / Float((width - 2 * windowSize) * (height - 2 * windowSize))
        return min(1.0, avgVariance / 1000.0) // Normalize
    }
    
    private func loadPreferences() {
        guard let data = userDefaults.data(forKey: preferencesKey) else {
            logger.info("No saved personalized preferences found, using defaults")
            return
        }
        
        do {
            preferences = try JSONDecoder().decode(UserScoringPreferences.self, from: data)
            logger.info("Loaded personalized preferences: \(preferences.totalRatings) ratings")
        } catch {
            logger.error("Failed to load personalized preferences: \(error.localizedDescription)")
        }
    }
    
    private func savePreferences() {
        do {
            let data = try JSONEncoder().encode(preferences)
            userDefaults.set(data, forKey: preferencesKey)
            logger.debug("Saved personalized preferences")
        } catch {
            logger.error("Failed to save personalized preferences: \(error.localizedDescription)")
        }
    }
}

