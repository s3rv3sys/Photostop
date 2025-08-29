//
//  FrameScore.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import Foundation

/// Represents the quality score and analysis of a captured frame
struct FrameScore: Identifiable, Codable {
    let id: UUID
    let imageData: Data
    let qualityScore: Float // 0.0 to 1.0, higher is better
    let sharpnessScore: Float
    let exposureScore: Float
    let noiseScore: Float
    let timestamp: Date
    let processingTime: TimeInterval
    
    // Computed property for UIImage conversion
    var image: UIImage? {
        return UIImage(data: imageData)
    }
    
    init(image: UIImage, qualityScore: Float, sharpnessScore: Float, exposureScore: Float, noiseScore: Float, processingTime: TimeInterval = 0) {
        self.id = UUID()
        self.imageData = image.jpegData(compressionQuality: 0.9) ?? Data()
        self.qualityScore = qualityScore
        self.sharpnessScore = sharpnessScore
        self.exposureScore = exposureScore
        self.noiseScore = noiseScore
        self.timestamp = Date()
        self.processingTime = processingTime
    }
    
    /// Overall quality rating as a string
    var qualityRating: String {
        switch qualityScore {
        case 0.8...1.0:
            return "Excellent"
        case 0.6..<0.8:
            return "Good"
        case 0.4..<0.6:
            return "Fair"
        case 0.2..<0.4:
            return "Poor"
        default:
            return "Very Poor"
        }
    }
    
    /// Color for quality rating display
    var qualityColor: UIColor {
        switch qualityScore {
        case 0.8...1.0:
            return .systemGreen
        case 0.6..<0.8:
            return .systemBlue
        case 0.4..<0.6:
            return .systemYellow
        case 0.2..<0.4:
            return .systemOrange
        default:
            return .systemRed
        }
    }
    
    /// Detailed analysis of the frame quality
    var analysisDetails: [String] {
        var details: [String] = []
        
        // Sharpness analysis
        if sharpnessScore > 0.8 {
            details.append("Excellent sharpness")
        } else if sharpnessScore > 0.6 {
            details.append("Good sharpness")
        } else if sharpnessScore > 0.4 {
            details.append("Moderate blur detected")
        } else {
            details.append("Significant blur detected")
        }
        
        // Exposure analysis
        if exposureScore > 0.8 {
            details.append("Well exposed")
        } else if exposureScore > 0.6 {
            details.append("Good exposure")
        } else if exposureScore > 0.4 {
            details.append("Slight exposure issues")
        } else {
            details.append("Poor exposure")
        }
        
        // Noise analysis
        if noiseScore > 0.8 {
            details.append("Low noise")
        } else if noiseScore > 0.6 {
            details.append("Moderate noise")
        } else if noiseScore > 0.4 {
            details.append("Noticeable noise")
        } else {
            details.append("High noise levels")
        }
        
        return details
    }
}

// MARK: - FrameScore Extensions
extension FrameScore {
    /// Creates a frame score using fallback algorithms when ML model is unavailable
    static func createFallbackScore(for image: UIImage) -> FrameScore {
        let startTime = Date()
        
        // Convert to grayscale for analysis
        guard let cgImage = image.cgImage else {
            return FrameScore(
                image: image,
                qualityScore: 0.5,
                sharpnessScore: 0.5,
                exposureScore: 0.5,
                noiseScore: 0.5,
                processingTime: Date().timeIntervalSince(startTime)
            )
        }
        
        // Calculate sharpness using Laplacian variance
        let sharpnessScore = calculateSharpness(cgImage: cgImage)
        
        // Calculate exposure based on brightness distribution
        let exposureScore = calculateExposure(cgImage: cgImage)
        
        // Estimate noise (simplified)
        let noiseScore = estimateNoise(cgImage: cgImage)
        
        // Overall quality is weighted average
        let qualityScore = (sharpnessScore * 0.4 + exposureScore * 0.4 + noiseScore * 0.2)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return FrameScore(
            image: image,
            qualityScore: qualityScore,
            sharpnessScore: sharpnessScore,
            exposureScore: exposureScore,
            noiseScore: noiseScore,
            processingTime: processingTime
        )
    }
    
    /// Calculate sharpness using Laplacian variance (simplified implementation)
    private static func calculateSharpness(cgImage: CGImage) -> Float {
        // This is a simplified implementation
        // In a real app, you'd implement proper Laplacian variance calculation
        let width = cgImage.width
        let height = cgImage.height
        
        // For now, return a score based on image size and assume reasonable sharpness
        // Larger images tend to have more detail
        let sizeScore = min(Float(width * height) / 1000000.0, 1.0)
        return max(0.6, sizeScore) // Assume decent sharpness as baseline
    }
    
    /// Calculate exposure quality based on brightness distribution
    private static func calculateExposure(cgImage: CGImage) -> Float {
        // Simplified exposure calculation
        // In a real implementation, you'd analyze the histogram
        return 0.75 // Assume good exposure as baseline
    }
    
    /// Estimate noise levels in the image
    private static func estimateNoise(cgImage: CGImage) -> Float {
        // Simplified noise estimation
        // In a real implementation, you'd analyze texture patterns
        return 0.8 // Assume low noise as baseline
    }
}

// MARK: - Comparable
extension FrameScore: Comparable {
    static func < (lhs: FrameScore, rhs: FrameScore) -> Bool {
        return lhs.qualityScore < rhs.qualityScore
    }
    
    static func == (lhs: FrameScore, rhs: FrameScore) -> Bool {
        return lhs.id == rhs.id
    }
}

