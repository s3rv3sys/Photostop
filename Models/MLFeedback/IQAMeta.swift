//
//  IQAMeta.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import UIKit
import AVFoundation

/// Metadata for Image Quality Assessment feedback
struct IQAMeta: Codable {
    let device: String
    let iso: Int?
    let shutterMS: Double?
    let meanLuma: Double
    let imageWidth: Int
    let imageHeight: Int
    let timestamp: Date
    
    init(device: String = UIDevice.current.model,
         iso: Int? = nil,
         shutterMS: Double? = nil,
         meanLuma: Double,
         imageWidth: Int,
         imageHeight: Int,
         timestamp: Date = Date()) {
        self.device = device
        self.iso = iso
        self.shutterMS = shutterMS
        self.meanLuma = meanLuma
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.timestamp = timestamp
    }
}

/// Image Quality Assessment sample for training
struct IQASample: Codable {
    let id: String
    let relpath: String
    let score: Float
    let meta: IQAMeta
    let reasonCode: String?
    let userFeedback: String?
    
    init(id: String = UUID().uuidString,
         relpath: String,
         score: Float,
         meta: IQAMeta,
         reasonCode: String? = nil,
         userFeedback: String? = nil) {
        self.id = id
        self.relpath = relpath
        self.score = score
        self.meta = meta
        self.reasonCode = reasonCode
        self.userFeedback = userFeedback
    }
}

/// User rating reasons for feedback
enum RatingReason: String, CaseIterable, Codable {
    case tooDark = "too_dark"
    case blurry = "blurry"
    case noisy = "noisy"
    case wrongSubject = "wrong_subject"
    case poorComposition = "poor_composition"
    case overexposed = "overexposed"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .tooDark: return "Too Dark"
        case .blurry: return "Blurry"
        case .noisy: return "Noisy"
        case .wrongSubject: return "Wrong Subject"
        case .poorComposition: return "Poor Composition"
        case .overexposed: return "Overexposed"
        case .other: return "Other"
        }
    }
    
    var systemImage: String {
        switch self {
        case .tooDark: return "moon.fill"
        case .blurry: return "eye.slash.fill"
        case .noisy: return "waveform"
        case .wrongSubject: return "person.crop.circle.badge.xmark"
        case .poorComposition: return "viewfinder"
        case .overexposed: return "sun.max.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

/// Upload queue item for cloud feedback
struct IQAUploadItem: Codable {
    let sample: IQASample
    let imageData: Data
    let uploadAttempts: Int
    let lastAttempt: Date?
    let installID: String
    
    init(sample: IQASample, imageData: Data, installID: String) {
        self.sample = sample
        self.imageData = imageData
        self.uploadAttempts = 0
        self.lastAttempt = nil
        self.installID = installID
    }
}

extension UIImage {
    /// Calculate mean luminance for IQA metadata
    func meanLuminance() -> Double {
        guard let cgImage = self.cgImage else { return 0.0 }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                               width: width,
                               height: height,
                               bitsPerComponent: bitsPerComponent,
                               bytesPerRow: bytesPerRow,
                               space: colorSpace,
                               bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var totalLuminance: Double = 0.0
        let pixelCount = width * height
        
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = Double(pixelData[i])
            let g = Double(pixelData[i + 1])
            let b = Double(pixelData[i + 2])
            
            // ITU-R BT.709 luma coefficients
            let luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
            totalLuminance += luminance
        }
        
        return totalLuminance / Double(pixelCount)
    }
}

extension AVCaptureDevice {
    /// Extract camera metadata for IQA
    func currentIQAMeta(for image: UIImage) -> IQAMeta {
        let iso = self.iso > 0 ? Int(self.iso) : nil
        let shutterSpeed = self.exposureDuration.seconds > 0 ? self.exposureDuration.seconds * 1000 : nil
        
        return IQAMeta(
            device: UIDevice.current.model,
            iso: iso,
            shutterMS: shutterSpeed,
            meanLuma: image.meanLuminance(),
            imageWidth: Int(image.size.width),
            imageHeight: Int(image.size.height)
        )
    }
}

