//
//  FrameScoringService.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import CoreML
import Vision
import UIKit
import OSLog

/// Service for scoring photo frames using Core ML and personalized preferences
@MainActor
final class FrameScoringService: ObservableObject {
    
    static let shared = FrameScoringService()
    
    @Published var isModelLoaded = false
    @Published var modelVersion: String = "Unknown"
    @Published var isProcessing = false
    @Published var scoringError: ScoringError?
    
    private var model: MLModel?
    private var visionModel: VNCoreMLModel?
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "FrameScoring")
    private let modelVersioning = MLModelVersioning.shared
    private let personalizedScoring = PersonalizedScoringService.shared
    
    private init() {
        Task {
            await loadModel()
            await checkForModelUpdates()
        }
    }
    
    // MARK: - Public Interface
    
    /// Score a single frame for quality assessment
    func scoreFrame(_ image: UIImage) async -> FrameScore {
        let startTime = CFAbsoluteTimeGetCurrent()
        isProcessing = true
        scoringError = nil
        
        defer {
            isProcessing = false
        }
        
        // Get base score from Core ML model
        let baseScore = await getCoreMLScore(for: image)
        
        // Apply personalized scoring if enabled
        let personalizedScore = personalizedScoring.personalizeScore(baseScore, for: image)
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        let frameScore = FrameScore(
            score: personalizedScore,
            confidence: 0.85, // Would come from model in production
            processingTime: processingTime,
            features: extractFeatures(from: image),
            modelVersion: modelVersion,
            isPersonalized: personalizedScoring.isEnabled
        )
        
        logger.debug("Frame scored: base=\(baseScore), personalized=\(personalizedScore), time=\(processingTime)s")
        
        return frameScore
    }
    
    /// Score a single image (legacy method for compatibility)
    func scoreImage(_ image: UIImage) async -> FrameScore {
        return await scoreFrame(image)
    }
    
    /// Score multiple frames and return them sorted by quality
    func scoreFrames(_ images: [UIImage]) async -> [FrameScore] {
        let scores = await withTaskGroup(of: (Int, FrameScore).self, returning: [FrameScore].self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let score = await self.scoreFrame(image)
                    return (index, score)
                }
            }
            
            var results: [(Int, FrameScore)] = []
            for await result in group {
                results.append(result)
            }
            
            // Sort by original index to maintain order
            results.sort { $0.0 < $1.0 }
            return results.map { $0.1 }
        }
        
        logger.info("Scored \(images.count) frames, best score: \(scores.max(by: { $0.score < $1.score })?.score ?? 0.0)")
        
        return scores
    }
    
    /// Score multiple images (legacy method for compatibility)
    func scoreImages(_ images: [UIImage]) async -> [FrameScore] {
        return await scoreFrames(images)
    }
    
    /// Select the best frame from a collection with feedback integration
    func selectBestFrame(
        from images: [UIImage],
        with metadata: [IQAMeta]? = nil
    ) async -> (bestImage: UIImage, bestIndex: Int, allScores: [FrameScore]) {
        let scores = await scoreFrames(images)
        
        guard let bestIndex = scores.indices.max(by: { scores[$0].score < scores[$1].score }) else {
            logger.warning("No frames to score, returning first image")
            return (images[0], 0, scores)
        }
        
        let bestImage = images[bestIndex]
        
        // Store frame comparison for ML feedback if enabled
        if IQAFeedbackService.shared.isEnabled {
            let selectedMeta = metadata?[bestIndex] ?? IQAMeta(
                meanLuma: bestImage.meanLuminance(),
                imageWidth: Int(bestImage.size.width),
                imageHeight: Int(bestImage.size.height)
            )
            
            let rejectedImages = images.enumerated().compactMap { index, image in
                index != bestIndex ? image : nil
            }
            
            let rejectedMetas = metadata?.enumerated().compactMap { index, meta in
                index != bestIndex ? meta : nil
            } ?? rejectedImages.map { image in
                IQAMeta(
                    meanLuma: image.meanLuminance(),
                    imageWidth: Int(image.size.width),
                    imageHeight: Int(image.size.height)
                )
            }
            
            IQAFeedbackService.shared.saveFrameComparison(
                selectedImage: bestImage,
                rejectedImages: rejectedImages,
                selectedMeta: selectedMeta,
                rejectedMetas: rejectedMetas
            )
        }
        
        logger.info("Selected frame \(bestIndex) with score \(scores[bestIndex].score)")
        
        return (bestImage, bestIndex, scores)
    }
    
    /// Process user feedback on frame selection
    func processFeedback(
        selectedImage: UIImage,
        userRating: Bool,
        reason: RatingReason? = nil,
        feedback: String? = nil,
        modelScore: Float
    ) {
        let userScore: Float = userRating ? 1.0 : 0.0
        
        // Update personalized preferences
        personalizedScoring.updatePreferences(
            image: selectedImage,
            userRating: userScore,
            modelScore: modelScore
        )
        
        // Save feedback for ML training
        let meta = IQAMeta(
            meanLuma: selectedImage.meanLuminance(),
            imageWidth: Int(selectedImage.size.width),
            imageHeight: Int(selectedImage.size.height)
        )
        
        IQAFeedbackService.shared.saveRating(
            image: selectedImage,
            score: userScore,
            meta: meta,
            reason: reason,
            feedback: feedback
        )
        
        logger.info("Processed user feedback: rating=\(userRating), reason=\(reason?.rawValue ?? "none")")
    }
    
    // MARK: - Model Management
    
    func checkForModelUpdates() async {
        await modelVersioning.checkForModelUpdates()
        
        if modelVersioning.availableUpdate != nil {
            logger.info("Model update available: \(modelVersioning.currentModelVersion) -> \(modelVersioning.availableUpdate!)")
        }
    }
    
    func updateModel() async -> Bool {
        let success = await modelVersioning.downloadAndInstallUpdate()
        
        if success {
            await loadModel()
            logger.info("Model updated successfully")
        }
        
        return success
    }
    
    // MARK: - Private Methods
    
    private func loadModel() async {
        do {
            model = try modelVersioning.getCurrentModel()
            
            // Create Vision model for easier image processing
            if let model = model {
                visionModel = try VNCoreMLModel(for: model)
            }
            
            modelVersion = modelVersioning.currentModelVersion
            isModelLoaded = true
            
            logger.info("Loaded FrameScoring model version \(modelVersion)")
            
        } catch {
            logger.error("Failed to load FrameScoring model: \(error.localizedDescription)")
            isModelLoaded = false
            scoringError = .modelLoadFailed
            
            // Fall back to algorithmic scoring
            logger.info("Falling back to algorithmic frame scoring")
        }
    }
    
    private func getCoreMLScore(for image: UIImage) async -> Float {
        guard let visionModel = visionModel else {
            // Fallback to algorithmic scoring
            return getAlgorithmicScore(for: image)
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if let error = error {
                    self.logger.error("Vision request failed: \(error.localizedDescription)")
                    continuation.resume(returning: self.getAlgorithmicScore(for: image))
                    return
                }
                
                guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                      let scoreObservation = results.first,
                      let scoreValue = scoreObservation.featureValue.doubleValue else {
                    self.logger.warning("Invalid model output, using algorithmic score")
                    continuation.resume(returning: self.getAlgorithmicScore(for: image))
                    return
                }
                
                continuation.resume(returning: Float(scoreValue))
            }
            
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: getAlgorithmicScore(for: image))
                return
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                logger.error("Failed to perform vision request: \(error.localizedDescription)")
                continuation.resume(returning: getAlgorithmicScore(for: image))
            }
        }
    }
    
    private func getAlgorithmicScore(for image: UIImage) -> Float {
        // Fallback algorithmic scoring based on image analysis
        let features = extractFeatures(from: image)
        
        // Weighted combination of features
        let exposureScore = 1.0 - abs(features.meanLuminance - 0.5) * 2.0 // Prefer mid-range exposure
        let sharpnessScore = features.edgeStrength
        let contrastScore = features.contrast
        let noiseScore = 1.0 - features.noise // Lower noise is better
        
        let algorithmicScore = (
            exposureScore * 0.3 +
            sharpnessScore * 0.4 +
            contrastScore * 0.2 +
            noiseScore * 0.1
        )
        
        return Float(max(0.0, min(1.0, algorithmicScore)))
    }
    
    private func extractFeatures(from image: UIImage) -> FrameScore.Features {
        guard let cgImage = image.cgImage else {
            return FrameScore.Features(
                meanLuminance: 0.5,
                contrast: 0.5,
                sharpness: 0.5,
                edgeStrength: 0.5,
                noise: 0.5,
                colorfulness: 0.5
            )
        }
        
        // Basic feature extraction (simplified for demo)
        let meanLuminance = image.meanLuminance()
        
        // Placeholder values - in production, implement proper feature extraction
        return FrameScore.Features(
            meanLuminance: meanLuminance,
            contrast: 0.6, // Would calculate actual contrast
            sharpness: 0.7, // Would calculate actual sharpness
            edgeStrength: 0.65, // Would calculate actual edge strength
            noise: 0.3, // Would calculate actual noise level
            colorfulness: 0.8 // Would calculate actual colorfulness
        )
    }
}

// MARK: - Error Types

enum ScoringError: Error, LocalizedError {
    case modelLoadFailed
    case processingFailed
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load ML model"
        case .processingFailed:
            return "Image processing failed"
        case .invalidImage:
            return "Invalid image format"
        }
    }
}

// MARK: - FrameScore Extensions

extension FrameScore {
    /// Create a fallback score using algorithmic analysis
    static func createFallbackScore(for image: UIImage) -> FrameScore {
        let meanLuminance = image.meanLuminance()
        
        // Simple algorithmic scoring
        let exposureScore = 1.0 - abs(meanLuminance - 0.5) * 2.0
        let algorithmicScore = Float(max(0.0, min(1.0, exposureScore)))
        
        return FrameScore(
            score: algorithmicScore,
            confidence: 0.6, // Lower confidence for algorithmic scoring
            processingTime: 0.01, // Fast algorithmic processing
            features: Features(
                meanLuminance: meanLuminance,
                contrast: 0.5,
                sharpness: 0.5,
                edgeStrength: 0.5,
                noise: 0.3,
                colorfulness: 0.6
            ),
            modelVersion: "algorithmic_fallback",
            isPersonalized: false
        )
    }
}

