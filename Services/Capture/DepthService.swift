//
//  DepthService.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import AVFoundation
import CoreVideo
import CoreImage
import Vision
import UIKit
import OSLog

/// Service for processing depth data and creating portrait effects
@MainActor
public final class DepthService: ObservableObject {
    
    static let shared = DepthService()
    
    // MARK: - Published Properties
    
    @Published public var isProcessing = false
    @Published public var lastError: DepthError?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "DepthService")
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Process depth data from AVCapturePhoto
    public func processDepthData(
        from photo: AVCapturePhoto
    ) async -> DepthResult? {
        isProcessing = true
        lastError = nil
        
        defer {
            isProcessing = false
        }
        
        guard let depthData = photo.depthData else {
            lastError = .noDepthData
            logger.warning("No depth data available in photo")
            return nil
        }
        
        do {
            let result = try await processDepthData(depthData)
            logger.info("Successfully processed depth data with quality: \(result.quality)")
            return result
        } catch {
            lastError = error as? DepthError ?? .processingFailed
            logger.error("Depth processing failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Process raw AVDepthData
    public func processDepthData(
        _ depthData: AVDepthData
    ) async throws -> DepthResult {
        
        // Convert to disparity if needed
        let disparityData = depthData.depthDataType == kCVPixelFormatType_DisparityFloat32 
            ? depthData 
            : depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        
        // Validate depth map
        let quality = assessDepthQuality(disparityData.depthDataMap)
        guard quality > 0.1 else {
            throw DepthError.lowQuality
        }
        
        // Create normalized depth buffer
        let normalizedDepth = try normalizeDepthMap(disparityData.depthDataMap)
        
        // Generate portrait matte if available
        let portraitMatte = try await generatePortraitMatte(from: disparityData)
        
        // Create depth mask for AI processing
        let depthMask = try createDepthMask(from: normalizedDepth, quality: quality)
        
        return DepthResult(
            depthMap: normalizedDepth,
            portraitMatte: portraitMatte,
            depthMask: depthMask,
            quality: quality,
            originalData: disparityData
        )
    }
    
    /// Create a portrait matte using Vision framework
    public func generatePortraitMatte(
        from image: UIImage
    ) async -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNGeneratePersonSegmentationRequest { request, error in
                if let error = error {
                    self.logger.error("Person segmentation failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let observation = request.results?.first as? VNPixelBufferObservation else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: observation.pixelBuffer)
            }
            
            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                self.logger.error("Vision request failed: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// Apply portrait bokeh effect using depth data
    public func applyPortraitBokeh(
        to image: UIImage,
        using depthResult: DepthResult,
        intensity: Float = 0.7
    ) async -> UIImage? {
        
        guard let inputImage = CIImage(image: image),
              let depthImage = CIImage(cvPixelBuffer: depthResult.depthMap) else {
            return nil
        }
        
        // Create bokeh effect
        let bokehFilter = CIFilter.maskedVariableBlur()
        bokehFilter.inputImage = inputImage
        bokehFilter.mask = depthImage
        bokehFilter.radius = 20.0 * intensity
        
        guard let outputImage = bokehFilter.outputImage else {
            return nil
        }
        
        // Render to UIImage
        let extent = inputImage.extent
        guard let cgImage = ciContext.createCGImage(outputImage, from: extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Create a depth-based mask for AI processing
    public func createAIMask(
        from depthResult: DepthResult,
        focusSubject: Bool = true
    ) -> UIImage? {
        
        let depthMap = depthResult.depthMap
        
        // Create CIImage from depth buffer
        guard let depthImage = CIImage(cvPixelBuffer: depthMap) else {
            return nil
        }
        
        // Apply threshold to create binary mask
        let threshold: Float = focusSubject ? 0.3 : 0.7
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = depthImage
        thresholdFilter.threshold = threshold
        
        guard let maskedImage = thresholdFilter.outputImage else {
            return nil
        }
        
        // Convert to grayscale mask
        let grayscaleFilter = CIFilter.colorMonochrome()
        grayscaleFilter.inputImage = maskedImage
        grayscaleFilter.color = CIColor.white
        grayscaleFilter.intensity = 1.0
        
        guard let finalImage = grayscaleFilter.outputImage else {
            return nil
        }
        
        // Render to UIImage
        let extent = finalImage.extent
        guard let cgImage = ciContext.createCGImage(finalImage, from: extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Private Methods
    
    private func assessDepthQuality(_ depthMap: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return 0.0
        }
        
        var validPixels = 0
        var totalPixels = 0
        var depthSum: Float = 0.0
        var depthSumSquared: Float = 0.0
        
        // Sample every 8th pixel for performance
        for y in stride(from: 0, to: height, by: 8) {
            let rowPtr = baseAddress.advanced(by: y * bytesPerRow)
            
            for x in stride(from: 0, to: width, by: 8) {
                let pixelPtr = rowPtr.advanced(by: x * MemoryLayout<Float32>.size)
                let depth = pixelPtr.assumingMemoryBound(to: Float32.self).pointee
                
                totalPixels += 1
                
                if depth.isFinite && depth > 0 {
                    validPixels += 1
                    depthSum += depth
                    depthSumSquared += depth * depth
                }
            }
        }
        
        guard validPixels > 0 else { return 0.0 }
        
        // Calculate quality metrics
        let validRatio = Float(validPixels) / Float(totalPixels)
        let mean = depthSum / Float(validPixels)
        let variance = (depthSumSquared / Float(validPixels)) - (mean * mean)
        let normalizedVariance = min(variance / 100.0, 1.0)
        
        // Quality score: high valid ratio + reasonable variance
        let quality = validRatio * 0.6 + normalizedVariance * 0.4
        
        return min(max(quality, 0.0), 1.0)
    }
    
    private func normalizeDepthMap(_ depthMap: CVPixelBuffer) throws -> CVPixelBuffer {
        // Create output buffer
        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(depthMap),
            CVPixelBufferGetHeight(depthMap),
            kCVPixelFormatType_OneComponent8,
            nil,
            &outputBuffer
        )
        
        guard status == kCVReturnSuccess, let output = outputBuffer else {
            throw DepthError.bufferCreationFailed
        }
        
        // Lock both buffers
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        CVPixelBufferLockBaseAddress(output, [])
        
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            CVPixelBufferUnlockBaseAddress(output, [])
        }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        guard let inputPtr = CVPixelBufferGetBaseAddress(depthMap),
              let outputPtr = CVPixelBufferGetBaseAddress(output) else {
            throw DepthError.bufferAccessFailed
        }
        
        let inputBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(output)
        
        // Find min/max depth values for normalization
        var minDepth: Float = Float.greatestFiniteMagnitude
        var maxDepth: Float = -Float.greatestFiniteMagnitude
        
        for y in 0..<height {
            let inputRow = inputPtr.advanced(by: y * inputBytesPerRow)
            
            for x in 0..<width {
                let pixelPtr = inputRow.advanced(by: x * MemoryLayout<Float32>.size)
                let depth = pixelPtr.assumingMemoryBound(to: Float32.self).pointee
                
                if depth.isFinite && depth > 0 {
                    minDepth = min(minDepth, depth)
                    maxDepth = max(maxDepth, depth)
                }
            }
        }
        
        let depthRange = maxDepth - minDepth
        guard depthRange > 0 else {
            throw DepthError.invalidDepthRange
        }
        
        // Normalize to 0-255 range
        for y in 0..<height {
            let inputRow = inputPtr.advanced(by: y * inputBytesPerRow)
            let outputRow = outputPtr.advanced(by: y * outputBytesPerRow)
            
            for x in 0..<width {
                let inputPixelPtr = inputRow.advanced(by: x * MemoryLayout<Float32>.size)
                let outputPixelPtr = outputRow.advanced(by: x * MemoryLayout<UInt8>.size)
                
                let depth = inputPixelPtr.assumingMemoryBound(to: Float32.self).pointee
                
                let normalizedValue: UInt8
                if depth.isFinite && depth > 0 {
                    let normalized = (depth - minDepth) / depthRange
                    normalizedValue = UInt8(normalized * 255.0)
                } else {
                    normalizedValue = 0
                }
                
                outputPixelPtr.assumingMemoryBound(to: UInt8.self).pointee = normalizedValue
            }
        }
        
        return output
    }
    
    private func generatePortraitMatte(from depthData: AVDepthData) async throws -> CVPixelBuffer? {
        // Try to get existing portrait matte first
        if let portraitMatte = depthData.portraitEffectsMatte {
            return portraitMatte.mattingImage
        }
        
        // If no existing matte, we would need the original image to generate one
        // This would typically be done with the full image + depth data
        return nil
    }
    
    private func createDepthMask(
        from normalizedDepth: CVPixelBuffer,
        quality: Float
    ) throws -> UIImage {
        
        guard let ciImage = CIImage(cvPixelBuffer: normalizedDepth) else {
            throw DepthError.imageCreationFailed
        }
        
        // Apply quality-based adjustments
        let adjustedImage: CIImage
        if quality > 0.7 {
            // High quality - use as-is
            adjustedImage = ciImage
        } else {
            // Lower quality - apply smoothing
            let smoothFilter = CIFilter.gaussianBlur()
            smoothFilter.inputImage = ciImage
            smoothFilter.radius = 2.0
            adjustedImage = smoothFilter.outputImage ?? ciImage
        }
        
        let extent = adjustedImage.extent
        guard let cgImage = ciContext.createCGImage(adjustedImage, from: extent) else {
            throw DepthError.imageCreationFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Supporting Types

/// Result of depth processing
public struct DepthResult {
    /// Normalized depth map (0-255 grayscale)
    public let depthMap: CVPixelBuffer
    
    /// Portrait matte if available
    public let portraitMatte: CVPixelBuffer?
    
    /// Depth mask for AI processing
    public let depthMask: UIImage
    
    /// Quality score (0.0 to 1.0)
    public let quality: Float
    
    /// Original depth data for advanced processing
    public let originalData: AVDepthData
    
    /// Whether this result is suitable for portrait effects
    public var isPortraitSuitable: Bool {
        return quality > 0.5 && portraitMatte != nil
    }
    
    /// Whether this result is suitable for AI enhancement
    public var isAISuitable: Bool {
        return quality > 0.3
    }
}

/// Depth processing errors
public enum DepthError: Error, LocalizedError {
    case noDepthData
    case lowQuality
    case processingFailed
    case bufferCreationFailed
    case bufferAccessFailed
    case invalidDepthRange
    case imageCreationFailed
    
    public var errorDescription: String? {
        switch self {
        case .noDepthData:
            return "No depth data available"
        case .lowQuality:
            return "Depth data quality too low"
        case .processingFailed:
            return "Depth processing failed"
        case .bufferCreationFailed:
            return "Failed to create pixel buffer"
        case .bufferAccessFailed:
            return "Failed to access pixel buffer"
        case .invalidDepthRange:
            return "Invalid depth value range"
        case .imageCreationFailed:
            return "Failed to create image from depth data"
        }
    }
}

// MARK: - Extensions

extension AVDepthData {
    /// Get portrait effects matte if available
    var portraitEffectsMatte: AVPortraitEffectsMatte? {
        // This would be available if the photo was captured with portrait mode
        return nil // Placeholder - would be populated from AVCapturePhoto
    }
    
    /// Check if depth data is high quality
    var isHighQuality: Bool {
        return depthQuality() > 0.7
    }
    
    /// Get depth data statistics
    func statistics() -> [String: Float] {
        let quality = depthQuality()
        let dimensions = depthDataMap.dimensions
        
        return [
            "quality": quality,
            "width": Float(dimensions.width),
            "height": Float(dimensions.height),
            "type": Float(depthDataType)
        ]
    }
}

extension CVPixelBuffer {
    /// Get pixel buffer dimensions
    var dimensions: (width: Int, height: Int) {
        return (CVPixelBufferGetWidth(self), CVPixelBufferGetHeight(self))
    }
    
    /// Check if pixel buffer is valid for processing
    var isValid: Bool {
        let (width, height) = dimensions
        return width > 0 && height > 0
    }
}

