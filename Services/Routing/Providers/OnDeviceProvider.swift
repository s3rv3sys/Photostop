//
//  OnDeviceProvider.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import CoreImage
import Vision
import os.log

/// On-device image processing using Core Image and Vision frameworks
final class OnDeviceProvider: ImageEditProvider {
    let id: ProviderID = .onDevice
    let costClass: CostClass = .freeLocal
    
    private let ciContext: CIContext
    private let logger = Logger(subsystem: "PhotoStop", category: "OnDeviceProvider")
    
    init() {
        // Create optimized Core Image context
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .useSoftwareRenderer: false // Use GPU when available
        ]
        self.ciContext = CIContext(options: options)
    }
    
    // MARK: - ImageEditProvider Implementation
    
    func supports(_ task: EditTask) -> Bool {
        switch task {
        case .simpleEnhance:
            return true
        case .bgRemove:
            return hasPortraitSegmentation()
        case .cleanup:
            return true // Basic cleanup with median filter
        case .restyle:
            return true // Basic style filters
        case .localObjectEdit, .subjectConsistency, .multiImageFusion:
            return false // Too complex for on-device
        }
    }
    
    func edit(image: UIImage, task: EditTask, options: EditOptions) async throws -> ProviderResult {
        let startTime = Date()
        
        guard let ciImage = CIImage(image: image) else {
            throw ProviderError.invalidInput
        }
        
        logger.info("Starting on-device edit: \(task.rawValue)")
        
        let processedImage: CIImage
        var metadata: [String: Any] = [:]
        
        switch task {
        case .simpleEnhance:
            processedImage = try await autoEnhance(ciImage, options: options)
            metadata["enhancement_type"] = "auto_enhance"
            
        case .bgRemove:
            processedImage = try await removeBackground(ciImage, originalImage: image)
            metadata["segmentation_method"] = "vision_portrait"
            
        case .cleanup:
            processedImage = try await cleanup(ciImage, options: options)
            metadata["cleanup_method"] = "median_filter"
            
        case .restyle:
            processedImage = try await applyStyle(ciImage, options: options)
            metadata["style_method"] = "core_image_filters"
            
        default:
            throw ProviderError.notSupported
        }
        
        // Convert back to UIImage
        guard let cgImage = ciContext.createCGImage(processedImage, from: processedImage.extent) else {
            throw ProviderError.decodeFailed
        }
        
        let resultImage = UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        metadata["processing_time"] = processingTime
        metadata["image_size"] = "\(Int(image.size.width))x\(Int(image.size.height))"
        
        logger.info("On-device edit completed in \(processingTime)s")
        
        return ProviderResult(
            image: resultImage,
            provider: id,
            costClass: costClass,
            processingTime: processingTime,
            metadata: metadata
        )
    }
    
    func validateConfiguration() async throws {
        // On-device provider is always available
        // Just verify Core Image context is working
        let testImage = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard ciContext.createCGImage(testImage, from: testImage.extent) != nil else {
            throw ProviderError.configurationError("Core Image context not working")
        }
    }
    
    // MARK: - Enhancement Methods
    
    private func autoEnhance(_ image: CIImage, options: EditOptions) async throws -> CIImage {
        var result = image
        
        // Apply auto-adjustments based on image analysis
        let filters = await analyzeAndSelectFilters(image, prompt: options.prompt)
        
        for filter in filters {
            result = result.applyingFilter(filter.name, parameters: filter.parameters)
        }
        
        return result
    }
    
    private func removeBackground(_ image: CIImage, originalImage: UIImage) async throws -> CIImage {
        guard hasPortraitSegmentation() else {
            throw ProviderError.notSupported
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGeneratePersonSegmentationRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ProviderError.unknown(error))
                    return
                }
                
                guard let observation = request.results?.first as? VNPixelBufferObservation else {
                    continuation.resume(throwing: ProviderError.decodeFailed)
                    return
                }
                
                do {
                    let maskImage = CIImage(cvPixelBuffer: observation.pixelBuffer)
                    let scaledMask = maskImage.transformed(by: CGAffineTransform(
                        scaleX: image.extent.width / maskImage.extent.width,
                        y: image.extent.height / maskImage.extent.height
                    ))
                    
                    // Apply mask to remove background
                    let maskedImage = image.applyingFilter("CIBlendWithMask", parameters: [
                        kCIInputMaskImageKey: scaledMask,
                        kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: image.extent)
                    ])
                    
                    continuation.resume(returning: maskedImage)
                } catch {
                    continuation.resume(throwing: ProviderError.unknown(error))
                }
            }
            
            request.qualityLevel = .balanced
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8
            
            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ProviderError.unknown(error))
            }
        }
    }
    
    private func cleanup(_ image: CIImage, options: EditOptions) async throws -> CIImage {
        // Basic cleanup using median filter and noise reduction
        var result = image
        
        // Noise reduction
        result = result.applyingFilter("CINoiseReduction", parameters: [
            "inputNoiseLevel": 0.02,
            "inputSharpness": 0.4
        ])
        
        // Median filter for small artifact removal
        result = result.applyingFilter("CIMedianFilter")
        
        // Slight sharpening to compensate for filtering
        result = result.applyingFilter("CIUnsharpMask", parameters: [
            "inputRadius": 1.0,
            "inputIntensity": 0.3
        ])
        
        return result
    }
    
    private func applyStyle(_ image: CIImage, options: EditOptions) async throws -> CIImage {
        guard let prompt = options.prompt?.lowercased() else {
            // Default enhancement
            return try await autoEnhance(image, options: options)
        }
        
        var result = image
        
        // Style-based filters
        if prompt.contains("vintage") || prompt.contains("retro") {
            result = result.applyingFilter("CIPhotoEffectTransfer")
            result = result.applyingFilter("CIVignette", parameters: [
                "inputRadius": 1.0,
                "inputIntensity": 0.3
            ])
            
        } else if prompt.contains("dramatic") || prompt.contains("moody") {
            result = result.applyingFilter("CIPhotoEffectNoir")
            result = result.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 0.5,
                "inputShadowAmount": 1.2
            ])
            
        } else if prompt.contains("bright") || prompt.contains("cheerful") {
            result = result.applyingFilter("CIColorControls", parameters: [
                "inputBrightness": 0.1,
                "inputSaturation": 1.2,
                "inputContrast": 1.1
            ])
            
        } else if prompt.contains("warm") {
            result = result.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: 5500, y: 0)
            ])
            
        } else if prompt.contains("cool") {
            result = result.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: 7500, y: 0)
            ])
            
        } else {
            // Default enhancement
            result = try await autoEnhance(image, options: options)
        }
        
        return result
    }
    
    // MARK: - Analysis and Filter Selection
    
    private struct FilterApplication {
        let name: String
        let parameters: [String: Any]
    }
    
    private func analyzeAndSelectFilters(_ image: CIImage, prompt: String?) async -> [FilterApplication] {
        var filters: [FilterApplication] = []
        
        // Analyze image characteristics
        let stats = await analyzeImageStatistics(image)
        
        // Exposure correction
        if stats.averageBrightness < 0.3 {
            filters.append(FilterApplication(
                name: "CIExposureAdjust",
                parameters: ["inputEV": 0.5]
            ))
        } else if stats.averageBrightness > 0.8 {
            filters.append(FilterApplication(
                name: "CIExposureAdjust",
                parameters: ["inputEV": -0.3]
            ))
        }
        
        // Contrast enhancement
        if stats.contrast < 0.5 {
            filters.append(FilterApplication(
                name: "CIColorControls",
                parameters: ["inputContrast": 1.2]
            ))
        }
        
        // Saturation adjustment
        if stats.saturation < 0.8 {
            filters.append(FilterApplication(
                name: "CIColorControls",
                parameters: ["inputSaturation": 1.1]
            ))
        }
        
        // Noise reduction for high ISO images
        if stats.noiseLevel > 0.1 {
            filters.append(FilterApplication(
                name: "CINoiseReduction",
                parameters: [
                    "inputNoiseLevel": min(0.1, stats.noiseLevel),
                    "inputSharpness": 0.4
                ]
            ))
        }
        
        // Sharpening
        filters.append(FilterApplication(
            name: "CIUnsharpMask",
            parameters: [
                "inputRadius": 1.6,
                "inputIntensity": 0.6
            ]
        ))
        
        return filters
    }
    
    private struct ImageStatistics {
        let averageBrightness: Float
        let contrast: Float
        let saturation: Float
        let noiseLevel: Float
    }
    
    private func analyzeImageStatistics(_ image: CIImage) async -> ImageStatistics {
        // Simplified analysis - in a real implementation, you'd use more sophisticated methods
        
        // Create a small version for analysis
        let analysisSize = CGSize(width: 256, height: 256)
        let scaledImage = image.transformed(by: CGAffineTransform(
            scaleX: analysisSize.width / image.extent.width,
            y: analysisSize.height / image.extent.height
        ))
        
        // Basic histogram analysis would go here
        // For now, return reasonable defaults
        return ImageStatistics(
            averageBrightness: 0.5,
            contrast: 0.6,
            saturation: 0.8,
            noiseLevel: 0.05
        )
    }
    
    // MARK: - Capability Detection
    
    private func hasPortraitSegmentation() -> Bool {
        if #available(iOS 15.0, *) {
            let request = VNGeneratePersonSegmentationRequest()
            return VNRequest.supportedRevisions(for: VNGeneratePersonSegmentationRequest.self).contains(request.revision)
        }
        return false
    }
}

