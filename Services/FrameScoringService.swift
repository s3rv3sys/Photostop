//
//  FrameScoringService.swift
//  PhotoStop - Capture v2 with Personalization v1
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import CoreML
import Vision
import UIKit
import OSLog

/// Enhanced frame scoring service that works with FrameBundle architecture and personalization
@MainActor
public final class FrameScoringService: ObservableObject {
    
    static let shared = FrameScoringService()
    
    // MARK: - Published Properties
    
    @Published public var isProcessing = false
    @Published public var lastError: ScoringError?
    @Published public var modelVersion: String = "1.0.0"
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "FrameScoring")
    private let feedbackService = IQAFeedbackService.shared
    private let personalizedScoring = PersonalizedScoring.shared
    
    // NEW: Personalization integration
    private let personalizationEngine = PersonalizationEngine.shared
    
    // Core ML model (loaded lazily)
    private var coreMLModel: MLModel?
    private var isModelLoaded = false
    
    // Vision requests for quality assessment
    private let sharpnessRequest = VNClassifyImageRequest()
    private let aestheticsRequest = VNClassifyImageRequest()
    
    // MARK: - Initialization
    
    private init() {
        setupVisionRequests()
        loadCoreMLModel()
    }
    
    // MARK: - Public Interface
    
    /// Score all frames in a bundle and select the best one
    public func scoreFrameBundle(_ bundle: FrameBundle) async throws -> FrameBundle {
        isProcessing = true
        lastError = nil
        
        defer {
            isProcessing = false
        }
        
        logger.info("Scoring bundle with \(bundle.frameCount) frames")
        
        var scoredBundle = bundle
        var baseScores: [Float] = []
        var personalizedScores: [Float] = []
        
        // Score each frame
        for item in bundle.items {
            let baseScore = try await scoreFrameBase(item, sceneHints: bundle.sceneHints)
            baseScores.append(baseScore)
            
            // Apply personalization bias if enabled
            let features = PersonalizationFeatures.from(item: item)
            let personalizedScore = personalizationEngine.applyBias(
                baseScore: baseScore,
                features: features,
                lens: item.metadata.lens
            )
            personalizedScores.append(personalizedScore)
        }
        
        // Update bundle with both base and personalized scores
        scoredBundle.updateQualityScores(personalizedScores)
        
        // Apply legacy personalized scoring adjustments (if any)
        let legacyAdjustedScores = await personalizedScoring.adjustScores(
            personalizedScores,
            for: bundle.items,
            sceneHints: bundle.sceneHints
        )
        
        scoredBundle.updateQualityScores(legacyAdjustedScores)
        
        // Select best frame
        scoredBundle.selectBestItem()
        
        let bestScore = legacyAdjustedScores.max() ?? 0.0
        let bestIndex = legacyAdjustedScores.firstIndex(of: bestScore) ?? 0
        
        logger.info("Scoring complete - Best score: \(String(format: "%.3f", bestScore)) (base: \(String(format: "%.3f", baseScores[bestIndex])))")
        
        return scoredBundle
    }
    
    /// Score a single frame with comprehensive quality assessment (base score only)
    private func scoreFrameBase(
        _ item: FrameBundle.Item,
        sceneHints: SceneHints
    ) async throws -> Float {
        
        let image = item.image
        let metadata = item.metadata
        
        // Get base quality scores
        let technicalScore = await assessTechnicalQuality(image, metadata: metadata)
        let aestheticScore = await assessAestheticQuality(image)
        let contextualScore = assessContextualQuality(item, sceneHints: sceneHints)
        
        // Use Core ML model if available
        var mlScore: Float = 0.0
        if let model = coreMLModel {
            mlScore = await scoreByCoreML(image, model: model) ?? 0.0
        }
        
        // Combine scores with weights
        let weights = getScoreWeights(for: sceneHints.sceneType)
        
        let baseScore = (
            technicalScore * weights.technical +
            aestheticScore * weights.aesthetic +
            contextualScore * weights.contextual +
            mlScore * weights.ml
        )
        
        logger.debug("Frame base score: technical=\(String(format: "%.3f", technicalScore)), aesthetic=\(String(format: "%.3f", aestheticScore)), contextual=\(String(format: "%.3f", contextualScore)), ml=\(String(format: "%.3f", mlScore)), base=\(String(format: "%.3f", baseScore))")
        
        return min(max(baseScore, 0.0), 1.0)
    }
    
    /// Score a single frame with personalization applied (public interface)
    public func scoreFrame(
        _ item: FrameBundle.Item,
        sceneHints: SceneHints
    ) async throws -> Float {
        
        let baseScore = try await scoreFrameBase(item, sceneHints: sceneHints)
        
        // Apply personalization bias
        let features = PersonalizationFeatures.from(item: item)
        let personalizedScore = personalizationEngine.applyBias(
            baseScore: baseScore,
            features: features,
            lens: item.metadata.lens
        )
        
        return personalizedScore
    }
    
    /// Get scoring explanation for a frame
    public func getScoringExplanation(
        for item: FrameBundle.Item,
        sceneHints: SceneHints
    ) async -> ScoringExplanation {
        
        let technicalScore = await assessTechnicalQuality(item.image, metadata: item.metadata)
        let aestheticScore = await assessAestheticQuality(item.image)
        let contextualScore = assessContextualQuality(item, sceneHints: sceneHints)
        
        // Get personalization info
        let features = PersonalizationFeatures.from(item: item)
        let baseScore = (technicalScore + aestheticScore + contextualScore) / 3.0
        let personalizedScore = personalizationEngine.applyBias(
            baseScore: baseScore,
            features: features,
            lens: item.metadata.lens
        )
        
        let personalizationAdjustment = personalizedScore - baseScore
        
        return ScoringExplanation(
            technicalScore: technicalScore,
            aestheticScore: aestheticScore,
            contextualScore: contextualScore,
            baseScore: baseScore,
            personalizedScore: personalizedScore,
            personalizationAdjustment: personalizationAdjustment,
            lens: item.metadata.lens,
            sceneType: sceneHints.sceneType,
            factors: generateScoringFactors(item, sceneHints: sceneHints),
            personalizationEnabled: personalizationEngine.currentProfile().enabled
        )
    }
    
    // MARK: - Technical Quality Assessment
    
    private func assessTechnicalQuality(
        _ image: UIImage,
        metadata: FrameMetadata
    ) async -> Float {
        
        var score: Float = 0.5 // Base score
        
        // Sharpness/motion blur assessment
        let motionScore = 1.0 - metadata.motionScore // Invert (less motion = better)
        score += motionScore * 0.3
        
        // Exposure assessment
        let exposureScore = assessExposureQuality(metadata)
        score += exposureScore * 0.2
        
        // ISO noise assessment
        let noiseScore = assessNoiseLevel(metadata)
        score += noiseScore * 0.2
        
        // Depth quality (if available)
        if metadata.hasDepth {
            let depthScore = metadata.depthQuality
            score += depthScore * 0.15
        }
        
        // Vision-based sharpness detection
        let visionSharpness = await assessSharpnessWithVision(image)
        score += visionSharpness * 0.15
        
        return min(max(score, 0.0), 1.0)
    }
    
    private func assessExposureQuality(_ metadata: FrameMetadata) -> Float {
        let luma = metadata.meanLuma
        
        // Optimal exposure is around 0.4-0.6 luminance
        if luma >= 0.4 && luma <= 0.6 {
            return 1.0
        } else if luma >= 0.2 && luma <= 0.8 {
            return 0.7
        } else if luma >= 0.1 && luma <= 0.9 {
            return 0.4
        } else {
            return 0.1 // Very under/overexposed
        }
    }
    
    private func assessNoiseLevel(_ metadata: FrameMetadata) -> Float {
        let iso = metadata.iso
        
        // Lower ISO = less noise
        if iso <= 400 {
            return 1.0
        } else if iso <= 800 {
            return 0.8
        } else if iso <= 1600 {
            return 0.6
        } else if iso <= 3200 {
            return 0.4
        } else {
            return 0.2
        }
    }
    
    private func assessSharpnessWithVision(_ image: UIImage) async -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }
        
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    self.logger.error("Vision sharpness assessment failed: \(error.localizedDescription)")
                    continuation.resume(returning: 0.5)
                    return
                }
                
                // This would use a custom sharpness classifier
                // For now, return a placeholder based on image analysis
                let sharpness = self.estimateSharpnessFromImage(cgImage)
                continuation.resume(returning: sharpness)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                self.logger.error("Vision request failed: \(error.localizedDescription)")
                continuation.resume(returning: 0.5)
            }
        }
    }
    
    private func estimateSharpnessFromImage(_ cgImage: CGImage) -> Float {
        // Simplified sharpness estimation using edge detection
        let width = cgImage.width
        let height = cgImage.height
        
        // Sample a smaller region for performance
        let sampleWidth = min(width, 256)
        let sampleHeight = min(height, 256)
        
        guard let context = CGContext(
            data: nil,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return 0.5
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
        
        guard let data = context.data else { return 0.5 }
        
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var edgeStrength: Float = 0.0
        
        // Simple Sobel edge detection
        for y in 1..<(sampleHeight - 1) {
            for x in 1..<(sampleWidth - 1) {
                let idx = y * sampleWidth + x
                
                let gx = Float(pixels[idx - sampleWidth - 1]) * -1 +
                         Float(pixels[idx - sampleWidth + 1]) * 1 +
                         Float(pixels[idx - 1]) * -2 +
                         Float(pixels[idx + 1]) * 2 +
                         Float(pixels[idx + sampleWidth - 1]) * -1 +
                         Float(pixels[idx + sampleWidth + 1]) * 1
                
                let gy = Float(pixels[idx - sampleWidth - 1]) * -1 +
                         Float(pixels[idx - sampleWidth]) * -2 +
                         Float(pixels[idx - sampleWidth + 1]) * -1 +
                         Float(pixels[idx + sampleWidth - 1]) * 1 +
                         Float(pixels[idx + sampleWidth]) * 2 +
                         Float(pixels[idx + sampleWidth + 1]) * 1
                
                edgeStrength += sqrt(gx * gx + gy * gy)
            }
        }
        
        // Normalize edge strength
        let avgEdgeStrength = edgeStrength / Float(sampleWidth * sampleHeight)
        return min(avgEdgeStrength / 100.0, 1.0) // Normalize to 0-1 range
    }
    
    // MARK: - Aesthetic Quality Assessment
    
    private func assessAestheticQuality(_ image: UIImage) async -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }
        
        // Composition analysis
        let compositionScore = assessComposition(cgImage)
        
        // Color harmony analysis
        let colorScore = assessColorHarmony(cgImage)
        
        // Contrast analysis
        let contrastScore = assessContrast(cgImage)
        
        // Vision-based aesthetic assessment (if available)
        let visionScore = await assessAestheticsWithVision(image)
        
        // Combine aesthetic factors
        let aestheticScore = (
            compositionScore * 0.3 +
            colorScore * 0.25 +
            contrastScore * 0.25 +
            visionScore * 0.2
        )
        
        return min(max(aestheticScore, 0.0), 1.0)
    }
    
    private func assessComposition(_ cgImage: CGImage) -> Float {
        // Rule of thirds assessment
        return 0.6 // Placeholder
    }
    
    private func assessColorHarmony(_ cgImage: CGImage) -> Float {
        return 0.6 // Placeholder
    }
    
    private func assessContrast(_ cgImage: CGImage) -> Float {
        return 0.6 // Placeholder
    }
    
    private func assessAestheticsWithVision(_ image: UIImage) async -> Float {
        return 0.6 // Placeholder
    }
    
    // MARK: - Contextual Quality Assessment
    
    private func assessContextualQuality(
        _ item: FrameBundle.Item,
        sceneHints: SceneHints
    ) -> Float {
        
        var score: Float = 0.5
        let metadata = item.metadata
        
        // Scene-specific scoring
        switch sceneHints.sceneType {
        case .portrait:
            if metadata.hasDepth && metadata.depthQuality > 0.5 {
                score += 0.3
            }
            if metadata.lens != .ultraWide {
                score += 0.2
            }
            
        case .landscape:
            if metadata.lens == .ultraWide || metadata.lens == .wide {
                score += 0.2
            }
            if !metadata.isLowLight {
                score += 0.2
            }
            
        case .lowLight:
            if metadata.iso <= 1600 {
                score += 0.3
            }
            if metadata.meanLuma > 0.2 {
                score += 0.2
            }
            
        case .macro:
            if metadata.motionScore < 0.3 {
                score += 0.3
            }
            if metadata.lens == .wide {
                score += 0.2
            }
            
        case .action:
            if metadata.shutterMS < 8.0 {
                score += 0.3
            }
            if metadata.motionScore < 0.4 {
                score += 0.2
            }
            
        case .general:
            if !metadata.hasMotionBlur {
                score += 0.2
            }
            if !metadata.isLowLight {
                score += 0.2
            }
        }
        
        return min(max(score, 0.0), 1.0)
    }
    
    // MARK: - Core ML Scoring
    
    private func scoreByCoreML(_ image: UIImage, model: MLModel) async -> Float? {
        // Core ML implementation placeholder
        return nil
    }
    
    // MARK: - Model Management
    
    private func loadCoreMLModel() {
        // Model loading implementation
    }
    
    // MARK: - Helper Methods
    
    private func setupVisionRequests() {
        sharpnessRequest.revision = VNClassifyImageRequestRevision1
        aestheticsRequest.revision = VNClassifyImageRequestRevision1
    }
    
    private func getScoreWeights(for sceneType: SceneHints.SceneType) -> ScoreWeights {
        switch sceneType {
        case .portrait:
            return ScoreWeights(technical: 0.3, aesthetic: 0.4, contextual: 0.2, ml: 0.1)
        case .landscape:
            return ScoreWeights(technical: 0.2, aesthetic: 0.5, contextual: 0.2, ml: 0.1)
        case .lowLight:
            return ScoreWeights(technical: 0.5, aesthetic: 0.2, contextual: 0.2, ml: 0.1)
        case .macro:
            return ScoreWeights(technical: 0.4, aesthetic: 0.3, contextual: 0.2, ml: 0.1)
        case .action:
            return ScoreWeights(technical: 0.6, aesthetic: 0.1, contextual: 0.2, ml: 0.1)
        case .general:
            return ScoreWeights(technical: 0.3, aesthetic: 0.3, contextual: 0.3, ml: 0.1)
        }
    }
    
    private func generateScoringFactors(
        _ item: FrameBundle.Item,
        sceneHints: SceneHints
    ) -> [String] {
        
        var factors: [String] = []
        let metadata = item.metadata
        
        if metadata.motionScore < 0.3 {
            factors.append("Sharp image")
        } else if metadata.motionScore > 0.7 {
            factors.append("Motion blur detected")
        }
        
        if metadata.isLowLight {
            factors.append("Low light conditions")
        }
        
        if metadata.hasDepth && metadata.depthQuality > 0.5 {
            factors.append("Good depth data")
        }
        
        factors.append("Captured with \(metadata.lens.displayName) lens")
        factors.append("Scene type: \(sceneHints.sceneType.displayName)")
        
        // Add personalization factors
        let profile = personalizationEngine.currentProfile()
        if profile.enabled && !profile.isNeutral {
            factors.append("Personalized for your preferences")
        }
        
        return factors
    }
}

// MARK: - Supporting Types

private struct ScoreWeights {
    let technical: Float
    let aesthetic: Float
    let contextual: Float
    let ml: Float
}

public struct ScoringExplanation {
    public let technicalScore: Float
    public let aestheticScore: Float
    public let contextualScore: Float
    public let baseScore: Float
    public let personalizedScore: Float
    public let personalizationAdjustment: Float
    public let lens: FrameMetadata.Lens
    public let sceneType: SceneHints.SceneType
    public let factors: [String]
    public let personalizationEnabled: Bool
    
    public var overallScore: Float {
        return personalizedScore
    }
    
    public var summary: String {
        let scoreText = String(format: "%.1f", overallScore * 100)
        var summary = "Quality Score: \(scoreText)% (\(sceneType.displayName) with \(lens.displayName) lens)"
        
        if personalizationEnabled && abs(personalizationAdjustment) > 0.01 {
            let adjustmentText = personalizationAdjustment > 0 ? "+" : ""
            summary += " [Personalized: \(adjustmentText)\(String(format: "%.1f", personalizationAdjustment * 100))%]"
        }
        
        return summary
    }
    
    public var detailedBreakdown: String {
        let components = [
            "Technical: \(String(format: "%.1f%%", technicalScore * 100))",
            "Aesthetic: \(String(format: "%.1f%%", aestheticScore * 100))",
            "Contextual: \(String(format: "%.1f%%", contextualScore * 100))"
        ]
        
        var breakdown = "Base Score: \(String(format: "%.1f%%", baseScore * 100)) (\(components.joined(separator: ", ")))"
        
        if personalizationEnabled {
            if abs(personalizationAdjustment) > 0.01 {
                let adjustmentText = personalizationAdjustment > 0 ? "+" : ""
                breakdown += "\nPersonalization: \(adjustmentText)\(String(format: "%.1f%%", personalizationAdjustment * 100))"
                breakdown += "\nFinal Score: \(String(format: "%.1f%%", personalizedScore * 100))"
            } else {
                breakdown += "\nPersonalization: No adjustment needed"
            }
        } else {
            breakdown += "\nPersonalization: Disabled"
        }
        
        return breakdown
    }
}

public enum ScoringError: Error, LocalizedError {
    case modelLoadFailed
    case imageProcessingFailed
    case visionRequestFailed
    case invalidInput
    case personalizationFailed
    
    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load ML model"
        case .imageProcessingFailed:
            return "Image processing failed"
        case .visionRequestFailed:
            return "Vision analysis failed"
        case .invalidInput:
            return "Invalid input data"
        case .personalizationFailed:
            return "Personalization processing failed"
        }
    }
}

