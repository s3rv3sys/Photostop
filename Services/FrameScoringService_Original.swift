//
//  FrameScoringService.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import CoreML
import Vision
import Foundation

/// Service responsible for scoring image quality using Core ML model
@MainActor
class FrameScoringService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var scoringError: ScoringError?
    
    // MARK: - Private Properties
    private var mlModel: MLModel?
    private var visionModel: VNCoreMLModel?
    
    init() {
        loadModel()
    }
    
    // MARK: - Public Methods
    
    /// Score a single image and return FrameScore
    func scoreImage(_ image: UIImage) async -> FrameScore {
        isProcessing = true
        scoringError = nil
        
        defer {
            isProcessing = false
        }
        
        // Try ML model first, fallback to algorithmic scoring
        if let visionModel = visionModel {
            return await scoreImageWithML(image, model: visionModel)
        } else {
            return FrameScore.createFallbackScore(for: image)
        }
    }
    
    /// Score multiple images and return them sorted by quality (best first)
    func scoreImages(_ images: [UIImage]) async -> [FrameScore] {
        var scores: [FrameScore] = []
        
        for image in images {
            let score = await scoreImage(image)
            scores.append(score)
        }
        
        // Sort by quality score, highest first
        return scores.sorted { $0.qualityScore > $1.qualityScore }
    }
    
    /// Get the best image from a collection
    func getBestImage(from images: [UIImage]) async -> UIImage? {
        guard !images.isEmpty else { return nil }
        
        if images.count == 1 {
            return images.first
        }
        
        let scores = await scoreImages(images)
        return scores.first?.image
    }
    
    /// Get detailed analysis of image quality
    func analyzeImageQuality(_ image: UIImage) async -> ImageQualityAnalysis {
        let score = await scoreImage(image)
        
        return ImageQualityAnalysis(
            frameScore: score,
            recommendations: generateRecommendations(for: score),
            technicalDetails: generateTechnicalDetails(for: score)
        )
    }
    
    // MARK: - Private Methods
    
    private func loadModel() {
        // Try to load the Core ML model
        guard let modelURL = Bundle.main.url(forResource: "FrameScoring", withExtension: "mlmodel") else {
            print("FrameScoring.mlmodel not found in bundle. Using fallback scoring.")
            return
        }
        
        do {
            mlModel = try MLModel(contentsOf: modelURL)
            visionModel = try VNCoreMLModel(for: mlModel!)
            print("Successfully loaded FrameScoring ML model")
        } catch {
            print("Failed to load ML model: \(error). Using fallback scoring.")
            scoringError = .modelLoadError(error.localizedDescription)
        }
    }
    
    private func scoreImageWithML(_ image: UIImage, model: VNCoreMLModel) async -> FrameScore {
        return await withCheckedContinuation { continuation in
            let startTime = Date()
            
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: FrameScore.createFallbackScore(for: image))
                return
            }
            
            let request = VNCoreMLRequest(model: model) { request, error in
                let processingTime = Date().timeIntervalSince(startTime)
                
                if let error = error {
                    print("ML scoring error: \(error)")
                    continuation.resume(returning: FrameScore.createFallbackScore(for: image))
                    return
                }
                
                guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                      let qualityResult = results.first?.featureValue.doubleValue else {
                    continuation.resume(returning: FrameScore.createFallbackScore(for: image))
                    return
                }
                
                let qualityScore = Float(qualityResult)
                
                // For now, use the overall quality score for individual metrics
                // In a real implementation, the ML model would output separate scores
                let frameScore = FrameScore(
                    image: image,
                    qualityScore: qualityScore,
                    sharpnessScore: qualityScore * 0.9, // Approximate sharpness
                    exposureScore: qualityScore * 1.1,  // Approximate exposure
                    noiseScore: qualityScore * 0.8,     // Approximate noise
                    processingTime: processingTime
                )
                
                continuation.resume(returning: frameScore)
            }
            
            // Configure request
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform ML request: \(error)")
                continuation.resume(returning: FrameScore.createFallbackScore(for: image))
            }
        }
    }
    
    private func generateRecommendations(for score: FrameScore) -> [String] {
        var recommendations: [String] = []
        
        if score.sharpnessScore < 0.6 {
            recommendations.append("Try holding the camera steadier or using a tripod")
            recommendations.append("Ensure proper focus before capturing")
        }
        
        if score.exposureScore < 0.6 {
            recommendations.append("Adjust lighting conditions")
            recommendations.append("Try different exposure settings")
        }
        
        if score.noiseScore < 0.6 {
            recommendations.append("Use better lighting to reduce noise")
            recommendations.append("Consider using a lower ISO setting")
        }
        
        if score.qualityScore > 0.8 {
            recommendations.append("Great shot! This image has excellent quality")
        }
        
        return recommendations
    }
    
    private func generateTechnicalDetails(for score: FrameScore) -> [String: String] {
        return [
            "Overall Quality": String(format: "%.1f%%", score.qualityScore * 100),
            "Sharpness": String(format: "%.1f%%", score.sharpnessScore * 100),
            "Exposure": String(format: "%.1f%%", score.exposureScore * 100),
            "Noise Level": String(format: "%.1f%%", (1.0 - score.noiseScore) * 100),
            "Processing Time": String(format: "%.3fs", score.processingTime),
            "Quality Rating": score.qualityRating
        ]
    }
}

// MARK: - Supporting Types

/// Detailed analysis of image quality
struct ImageQualityAnalysis {
    let frameScore: FrameScore
    let recommendations: [String]
    let technicalDetails: [String: String]
}

// MARK: - Scoring Errors
enum ScoringError: LocalizedError {
    case modelLoadError(String)
    case processingError(String)
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .modelLoadError(let message):
            return "Failed to load ML model: \(message)"
        case .processingError(let message):
            return "Processing error: \(message)"
        case .invalidImage:
            return "Invalid image for scoring"
        }
    }
}

