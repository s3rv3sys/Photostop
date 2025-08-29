//
//  FrameBundle.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import UIKit
import CoreVideo

/// Collection of frames captured in a single multi-lens burst session
public struct FrameBundle: Sendable {
    
    /// Individual frame with associated data
    public struct Item: Sendable, Identifiable {
        public let id = UUID()
        
        /// Captured image
        public let image: UIImage
        
        /// Optional depth map (CVPixelBuffer with depth data)
        public let depth: CVPixelBuffer?
        
        /// Optional portrait matte (CVPixelBuffer with person segmentation)
        public let matte: CVPixelBuffer?
        
        /// Rich metadata for this frame
        public let metadata: FrameMetadata
        
        /// Computed quality score (set by FrameScoringService)
        public var qualityScore: Float = 0.0
        
        /// Whether this item was selected as the best frame
        public var isSelected: Bool = false
        
        public init(
            image: UIImage,
            depth: CVPixelBuffer? = nil,
            matte: CVPixelBuffer? = nil,
            metadata: FrameMetadata
        ) {
            self.image = image
            self.depth = depth
            self.matte = matte
            self.metadata = metadata
        }
        
        /// Create a basic item for testing
        public static func mock(
            image: UIImage,
            lens: FrameMetadata.Lens = .wide,
            hasDepth: Bool = false
        ) -> Item {
            let metadata = FrameMetadata.fallback(lens: lens, image: image)
            return Item(
                image: image,
                depth: hasDepth ? mockDepthBuffer() : nil,
                metadata: metadata
            )
        }
        
        private static func mockDepthBuffer() -> CVPixelBuffer? {
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                64, 64,
                kCVPixelFormatType_DepthFloat32,
                nil,
                &pixelBuffer
            )
            return status == kCVReturnSuccess ? pixelBuffer : nil
        }
    }
    
    // MARK: - Properties
    
    /// All captured frames
    public let items: [Item]
    
    /// Scene analysis hints derived from the capture
    public let sceneHints: SceneHints
    
    /// Capture session metadata
    public let sessionMetadata: SessionMetadata
    
    /// Total capture duration in seconds
    public let captureDuration: TimeInterval
    
    /// Timestamp when capture started
    public let captureStartTime: Date
    
    // MARK: - Computed Properties
    
    /// Number of frames in the bundle
    public var frameCount: Int {
        return items.count
    }
    
    /// Number of unique lenses used
    public var lensCount: Int {
        return Set(items.map { $0.metadata.lens }).count
    }
    
    /// Whether any frame has depth data
    public var hasDepthData: Bool {
        return items.contains { $0.depth != nil }
    }
    
    /// Whether any frame has portrait matte
    public var hasPortraitMatte: Bool {
        return items.contains { $0.matte != nil }
    }
    
    /// Best quality frame (highest score)
    public var bestFrame: Item? {
        return items.max { $0.qualityScore < $1.qualityScore }
    }
    
    /// Selected frame (marked as selected)
    public var selectedFrame: Item? {
        return items.first { $0.isSelected }
    }
    
    /// Frames grouped by lens type
    public var framesByLens: [FrameMetadata.Lens: [Item]] {
        return Dictionary(grouping: items) { $0.metadata.lens }
    }
    
    /// Average quality score across all frames
    public var averageQuality: Float {
        guard !items.isEmpty else { return 0.0 }
        return items.map { $0.qualityScore }.reduce(0, +) / Float(items.count)
    }
    
    // MARK: - Initialization
    
    public init(
        items: [Item],
        sceneHints: SceneHints,
        sessionMetadata: SessionMetadata,
        captureDuration: TimeInterval,
        captureStartTime: Date = Date()
    ) {
        self.items = items
        self.sceneHints = sceneHints
        self.sessionMetadata = sessionMetadata
        self.captureDuration = captureDuration
        self.captureStartTime = captureStartTime
    }
    
    // MARK: - Factory Methods
    
    /// Create a bundle from a single frame (fallback for non-burst capture)
    public static func single(
        image: UIImage,
        lens: FrameMetadata.Lens = .wide,
        depth: CVPixelBuffer? = nil,
        matte: CVPixelBuffer? = nil
    ) -> FrameBundle {
        let metadata = FrameMetadata.fallback(lens: lens, image: image)
        let item = Item(image: image, depth: depth, matte: matte, metadata: metadata)
        
        let sceneHints = SceneHints.analyze(from: [item])
        let sessionMetadata = SessionMetadata.fallback()
        
        return FrameBundle(
            items: [item],
            sceneHints: sceneHints,
            sessionMetadata: sessionMetadata,
            captureDuration: 0.1
        )
    }
    
    /// Create a mock bundle for testing
    public static func mock(
        frameCount: Int = 3,
        lenses: [FrameMetadata.Lens] = [.wide, .ultraWide, .tele],
        hasDepth: Bool = true
    ) -> FrameBundle {
        let mockImage = UIImage(systemName: "camera.fill") ?? UIImage()
        
        let items = (0..<frameCount).map { index in
            let lens = lenses[index % lenses.count]
            return Item.mock(image: mockImage, lens: lens, hasDepth: hasDepth && lens != .ultraWide)
        }
        
        let sceneHints = SceneHints.analyze(from: items)
        let sessionMetadata = SessionMetadata.fallback()
        
        return FrameBundle(
            items: items,
            sceneHints: sceneHints,
            sessionMetadata: sessionMetadata,
            captureDuration: 0.8
        )
    }
    
    // MARK: - Mutation Methods
    
    /// Update quality scores for all items
    public mutating func updateQualityScores(_ scores: [Float]) {
        guard scores.count == items.count else { return }
        
        for (index, score) in scores.enumerated() {
            items[index].qualityScore = score
        }
    }
    
    /// Mark a specific item as selected
    public mutating func selectItem(at index: Int) {
        guard index < items.count else { return }
        
        for i in items.indices {
            items[i].isSelected = (i == index)
        }
    }
    
    /// Select the best quality item
    public mutating func selectBestItem() {
        guard let bestIndex = items.indices.max(by: { items[$0].qualityScore < items[$1].qualityScore }) else {
            return
        }
        selectItem(at: bestIndex)
    }
    
    // MARK: - Analysis Methods
    
    /// Get frames suitable for HDR processing
    public func hdrCandidates() -> [Item] {
        return items.filter { item in
            // Look for exposure bracketed frames from the same lens
            let exposureBias = abs(item.metadata.exposureBias)
            return exposureBias > 0.3 // At least ±0.3 EV difference
        }
    }
    
    /// Get frames suitable for portrait processing
    public func portraitCandidates() -> [Item] {
        return items.filter { $0.metadata.isPortraitSuitable }
    }
    
    /// Get frames from a specific lens
    public func frames(from lens: FrameMetadata.Lens) -> [Item] {
        return items.filter { $0.metadata.lens == lens }
    }
    
    /// Get the sharpest frame (lowest motion score)
    public func sharpestFrame() -> Item? {
        return items.min { $0.metadata.motionScore < $1.metadata.motionScore }
    }
    
    /// Get frames captured in low light
    public func lowLightFrames() -> [Item] {
        return items.filter { $0.metadata.isLowLight }
    }
    
    // MARK: - Export Methods
    
    /// Export bundle metadata as dictionary for debugging
    public func exportMetadata() -> [String: Any] {
        return [
            "frameCount": frameCount,
            "lensCount": lensCount,
            "hasDepthData": hasDepthData,
            "hasPortraitMatte": hasPortraitMatte,
            "captureDuration": captureDuration,
            "averageQuality": averageQuality,
            "sceneHints": sceneHints.exportData(),
            "sessionMetadata": sessionMetadata.exportData(),
            "frames": items.map { item in
                [
                    "lens": item.metadata.lens.rawValue,
                    "qualityScore": item.qualityScore,
                    "isSelected": item.isSelected,
                    "hasDepth": item.depth != nil,
                    "hasMatte": item.matte != nil,
                    "metadata": item.metadata.debugDescription
                ]
            }
        ]
    }
}

// MARK: - Supporting Types

/// Scene analysis hints derived from capture
public struct SceneHints: Sendable, Codable {
    /// Low light conditions detected
    public let lowLight: Bool
    
    /// Portrait/depth enhancement recommended
    public let wantsPortrait: Bool
    
    /// HDR processing recommended
    public let wantsHDR: Bool
    
    /// Number of faces detected
    public let facesDetected: Int
    
    /// Dominant scene type
    public let sceneType: SceneType
    
    /// Confidence in scene analysis (0.0 to 1.0)
    public let confidence: Float
    
    public enum SceneType: String, Codable, CaseIterable {
        case portrait = "portrait"
        case landscape = "landscape"
        case macro = "macro"
        case lowLight = "lowLight"
        case action = "action"
        case general = "general"
        
        public var displayName: String {
            switch self {
            case .portrait: return "Portrait"
            case .landscape: return "Landscape"
            case .macro: return "Macro"
            case .lowLight: return "Low Light"
            case .action: return "Action"
            case .general: return "General"
            }
        }
    }
    
    public init(
        lowLight: Bool,
        wantsPortrait: Bool,
        wantsHDR: Bool,
        facesDetected: Int,
        sceneType: SceneType = .general,
        confidence: Float = 0.8
    ) {
        self.lowLight = lowLight
        self.wantsPortrait = wantsPortrait
        self.wantsHDR = wantsHDR
        self.facesDetected = facesDetected
        self.sceneType = sceneType
        self.confidence = confidence
    }
    
    /// Analyze scene hints from captured frames
    public static func analyze(from items: [FrameBundle.Item]) -> SceneHints {
        guard !items.isEmpty else {
            return SceneHints(lowLight: false, wantsPortrait: false, wantsHDR: false, facesDetected: 0)
        }
        
        // Analyze lighting conditions
        let avgLuma = items.map { $0.metadata.meanLuma }.reduce(0, +) / Float(items.count)
        let avgISO = items.map { $0.metadata.iso }.reduce(0, +) / Float(items.count)
        let lowLight = avgLuma < 0.3 || avgISO > 1600
        
        // Check for portrait suitability
        let hasDepthFrames = items.contains { $0.depth != nil }
        let hasGoodDepthQuality = items.contains { $0.metadata.depthQuality > 0.5 }
        let wantsPortrait = hasDepthFrames && hasGoodDepthQuality
        
        // Check for HDR opportunity
        let exposureRange = items.map { $0.metadata.exposureBias }
        let minExposure = exposureRange.min() ?? 0.0
        let maxExposure = exposureRange.max() ?? 0.0
        let wantsHDR = (maxExposure - minExposure) > 0.5 // At least 0.5 EV range
        
        // Determine scene type
        let sceneType: SceneType
        if lowLight {
            sceneType = .lowLight
        } else if wantsPortrait {
            sceneType = .portrait
        } else if items.contains(where: { $0.metadata.lens == .ultraWide }) {
            sceneType = .landscape
        } else if items.contains(where: { $0.metadata.motionScore > 0.7 }) {
            sceneType = .action
        } else {
            sceneType = .general
        }
        
        return SceneHints(
            lowLight: lowLight,
            wantsPortrait: wantsPortrait,
            wantsHDR: wantsHDR,
            facesDetected: 0, // Would be populated by Vision face detection
            sceneType: sceneType,
            confidence: 0.8
        )
    }
    
    public func exportData() -> [String: Any] {
        return [
            "lowLight": lowLight,
            "wantsPortrait": wantsPortrait,
            "wantsHDR": wantsHDR,
            "facesDetected": facesDetected,
            "sceneType": sceneType.rawValue,
            "confidence": confidence
        ]
    }
}

/// Capture session metadata
public struct SessionMetadata: Sendable, Codable {
    /// Device model used for capture
    public let deviceModel: String
    
    /// iOS version
    public let iosVersion: String
    
    /// Whether multi-cam was used
    public let usedMultiCam: Bool
    
    /// Available lenses on device
    public let availableLenses: [FrameMetadata.Lens]
    
    /// Capture mode used
    public let captureMode: String
    
    /// App version
    public let appVersion: String
    
    public init(
        deviceModel: String,
        iosVersion: String,
        usedMultiCam: Bool,
        availableLenses: [FrameMetadata.Lens],
        captureMode: String,
        appVersion: String
    ) {
        self.deviceModel = deviceModel
        self.iosVersion = iosVersion
        self.usedMultiCam = usedMultiCam
        self.availableLenses = availableLenses
        self.captureMode = captureMode
        self.appVersion = appVersion
    }
    
    public static func fallback() -> SessionMetadata {
        return SessionMetadata(
            deviceModel: "iPhone",
            iosVersion: "18.0",
            usedMultiCam: false,
            availableLenses: [.wide],
            captureMode: "burst",
            appVersion: "2.0.0"
        )
    }
    
    public func exportData() -> [String: Any] {
        return [
            "deviceModel": deviceModel,
            "iosVersion": iosVersion,
            "usedMultiCam": usedMultiCam,
            "availableLenses": availableLenses.map { $0.rawValue },
            "captureMode": captureMode,
            "appVersion": appVersion
        ]
    }
}

