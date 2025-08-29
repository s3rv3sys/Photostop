//
//  FrameMetadata.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import AVFoundation

/// Rich metadata captured for each frame in a multi-lens burst
public struct FrameMetadata: Sendable, Codable, Hashable {
    
    /// Camera lens type used for capture
    public enum Lens: String, Codable, CaseIterable {
        case wide = "wide"
        case ultraWide = "ultraWide"
        case tele = "tele"
        case unknown = "unknown"
        
        public var displayName: String {
            switch self {
            case .wide: return "Wide"
            case .ultraWide: return "Ultra Wide"
            case .tele: return "Telephoto"
            case .unknown: return "Unknown"
            }
        }
        
        public var focalLengthEquivalent: Float {
            switch self {
            case .ultraWide: return 13.0
            case .wide: return 26.0
            case .tele: return 77.0
            case .unknown: return 26.0
            }
        }
    }
    
    // MARK: - Core Properties
    
    /// Camera lens used for this frame
    public let lens: Lens
    
    /// Exposure bias applied (-2.0 to +2.0 EV)
    public let exposureBias: Float
    
    /// ISO sensitivity value
    public let iso: Float
    
    /// Shutter speed in milliseconds
    public let shutterMS: Float
    
    /// White balance gains (R, G) if available
    public let whiteBalanceRG: (Float, Float)?
    
    /// Computed mean luminance (0.0 to 1.0)
    public let meanLuma: Float
    
    /// Motion blur score (0.0 = sharp, 1.0 = very blurry)
    public let motionScore: Float
    
    /// Whether depth data is available for this frame
    public let hasDepth: Bool
    
    /// Depth map quality score (0.0 to 1.0)
    public let depthQuality: Float
    
    /// Capture timestamp
    public let timestamp: Date
    
    // MARK: - Additional Metadata
    
    /// Aperture f-number if available
    public let aperture: Float?
    
    /// Focus distance in meters (0 = infinity)
    public let focusDistance: Float?
    
    /// Device orientation during capture
    public let deviceOrientation: String
    
    /// Flash mode used
    public let flashMode: String
    
    /// Image dimensions
    public let imageSize: CGSize
    
    // MARK: - Computed Properties
    
    /// Whether this frame was captured in low light conditions
    public var isLowLight: Bool {
        return meanLuma < 0.3 || iso > 1600
    }
    
    /// Whether this frame likely has motion blur
    public var hasMotionBlur: Bool {
        return motionScore > 0.6
    }
    
    /// Whether this frame is suitable for portrait enhancement
    public var isPortraitSuitable: Bool {
        return hasDepth && depthQuality > 0.5 && lens != .ultraWide
    }
    
    /// Exposure time in seconds
    public var exposureTimeSeconds: Double {
        return Double(shutterMS) / 1000.0
    }
    
    /// Whether this is a telephoto capture
    public var isTelephoto: Bool {
        return lens == .tele
    }
    
    /// Whether this is an ultra-wide capture
    public var isUltraWide: Bool {
        return lens == .ultraWide
    }
    
    // MARK: - Initialization
    
    public init(
        lens: Lens,
        exposureBias: Float,
        iso: Float,
        shutterMS: Float,
        whiteBalanceRG: (Float, Float)? = nil,
        meanLuma: Float,
        motionScore: Float,
        hasDepth: Bool,
        depthQuality: Float,
        timestamp: Date = Date(),
        aperture: Float? = nil,
        focusDistance: Float? = nil,
        deviceOrientation: String = "portrait",
        flashMode: String = "off",
        imageSize: CGSize = CGSize(width: 4032, height: 3024)
    ) {
        self.lens = lens
        self.exposureBias = exposureBias
        self.iso = iso
        self.shutterMS = shutterMS
        self.whiteBalanceRG = whiteBalanceRG
        self.meanLuma = meanLuma
        self.motionScore = motionScore
        self.hasDepth = hasDepth
        self.depthQuality = depthQuality
        self.timestamp = timestamp
        self.aperture = aperture
        self.focusDistance = focusDistance
        self.deviceOrientation = deviceOrientation
        self.flashMode = flashMode
        self.imageSize = imageSize
    }
    
    // MARK: - Factory Methods
    
    /// Create metadata from AVFoundation capture settings
    public static func from(
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        lens: Lens,
        image: UIImage,
        depthData: AVDepthData? = nil
    ) -> FrameMetadata {
        
        // Extract EXIF data
        let iso = Float(resolvedSettings.photoSettings.format?[kCVPixelBufferPixelFormatTypeKey] as? UInt32 ?? 0)
        let exposureDuration = resolvedSettings.photoSettings.format?["ExposureDuration"] as? Double ?? 0.0
        let shutterMS = Float(exposureDuration * 1000.0)
        
        // Compute mean luminance
        let meanLuma = image.meanLuminance()
        
        // Estimate motion score from exposure time
        let motionScore = estimateMotionScore(shutterMS: shutterMS, iso: iso)
        
        // Depth quality assessment
        let depthQuality = depthData?.depthQuality() ?? 0.0
        
        return FrameMetadata(
            lens: lens,
            exposureBias: 0.0, // Would extract from bracket settings
            iso: iso,
            shutterMS: shutterMS,
            whiteBalanceRG: nil, // Would extract from settings
            meanLuma: meanLuma,
            motionScore: motionScore,
            hasDepth: depthData != nil,
            depthQuality: depthQuality,
            timestamp: Date(),
            aperture: nil, // Would extract from EXIF
            focusDistance: nil, // Would extract from settings
            deviceOrientation: "portrait",
            flashMode: resolvedSettings.flashEnabled ? "on" : "off",
            imageSize: image.size
        )
    }
    
    /// Create fallback metadata for testing or when capture data is unavailable
    public static func fallback(
        lens: Lens = .wide,
        image: UIImage
    ) -> FrameMetadata {
        return FrameMetadata(
            lens: lens,
            exposureBias: 0.0,
            iso: 400,
            shutterMS: 16.67, // 1/60s
            meanLuma: image.meanLuminance(),
            motionScore: 0.2,
            hasDepth: false,
            depthQuality: 0.0,
            imageSize: image.size
        )
    }
    
    // MARK: - Helper Methods
    
    /// Estimate motion blur score from technical parameters
    private static func estimateMotionScore(shutterMS: Float, iso: Float) -> Float {
        // Longer exposure times increase motion blur risk
        let exposureScore = min(shutterMS / 100.0, 1.0) // Normalize to 100ms max
        
        // Higher ISO might indicate camera shake compensation
        let isoScore = iso > 1600 ? 0.3 : 0.0
        
        return min(exposureScore + isoScore, 1.0)
    }
    
    /// Generate a summary string for debugging
    public var debugDescription: String {
        return """
        FrameMetadata(
          lens: \(lens.displayName),
          exposure: \(exposureBias)EV,
          iso: \(Int(iso)),
          shutter: \(shutterMS)ms,
          luma: \(String(format: "%.2f", meanLuma)),
          motion: \(String(format: "%.2f", motionScore)),
          depth: \(hasDepth ? String(format: "%.2f", depthQuality) : "none")
        )
        """
    }
}

// MARK: - Extensions

extension AVDepthData {
    /// Assess depth map quality based on valid pixels and variance
    func depthQuality() -> Float {
        let depthMap = self.depthDataMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return 0.0
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let totalPixels = width * height
        var validPixels = 0
        var depthSum: Float = 0.0
        var depthSumSquared: Float = 0.0
        
        // Sample every 4th pixel for performance
        for y in stride(from: 0, to: height, by: 4) {
            let rowPtr = baseAddress.advanced(by: y * bytesPerRow)
            
            for x in stride(from: 0, to: width, by: 4) {
                let pixelPtr = rowPtr.advanced(by: x * MemoryLayout<Float32>.size)
                let depth = pixelPtr.assumingMemoryBound(to: Float32.self).pointee
                
                // Check if depth value is valid (not NaN or infinity)
                if depth.isFinite && depth > 0 {
                    validPixels += 1
                    depthSum += depth
                    depthSumSquared += depth * depth
                }
            }
        }
        
        guard validPixels > 0 else { return 0.0 }
        
        // Calculate quality based on valid pixel ratio and depth variance
        let validRatio = Float(validPixels) / Float(totalPixels / 16) // Account for sampling
        let mean = depthSum / Float(validPixels)
        let variance = (depthSumSquared / Float(validPixels)) - (mean * mean)
        let normalizedVariance = min(variance / 10.0, 1.0) // Normalize variance
        
        // Quality score: high valid ratio + reasonable variance
        return validRatio * 0.7 + normalizedVariance * 0.3
    }
}

extension UIImage {
    /// Calculate mean luminance of the image
    func meanLuminance() -> Float {
        guard let cgImage = self.cgImage else { return 0.5 }
        
        let width = 64 // Downsample for performance
        let height = 64
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        guard let context = context else { return 0.5 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return 0.5 }
        
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var sum: Int = 0
        
        for i in 0..<(width * height) {
            sum += Int(pixels[i])
        }
        
        return Float(sum) / Float(width * height * 255)
    }
}

