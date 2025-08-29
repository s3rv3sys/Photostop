//
//  CameraLens.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import AVFoundation
import UIKit
import OSLog

/// Service for discovering and managing multiple camera lenses
@MainActor
public final class CameraLensService: ObservableObject {
    
    static let shared = CameraLensService()
    
    // MARK: - Published Properties
    
    @Published public var availableLenses: [FrameMetadata.Lens] = []
    @Published public var isMultiCamSupported: Bool = false
    @Published public var currentLens: FrameMetadata.Lens = .wide
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "CameraLens")
    private var discoveredDevices: [AVCaptureDevice] = []
    private var lensToDevice: [FrameMetadata.Lens: AVCaptureDevice] = [:]
    
    // MARK: - Initialization
    
    private init() {
        discoverAvailableLenses()
    }
    
    // MARK: - Public Interface
    
    /// Discover all available camera lenses on the current device
    public func discoverAvailableLenses() {
        guard let deviceTypes = getAvailableDeviceTypes() else {
            logger.warning("No camera device types available")
            return
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        
        discoveredDevices = discoverySession.devices
        availableLenses = []
        lensToDevice = [:]
        
        // Map devices to lens types
        for device in discoveredDevices {
            if let lens = mapDeviceToLens(device) {
                availableLenses.append(lens)
                lensToDevice[lens] = device
                
                logger.info("Discovered lens: \(lens.displayName) - \(device.localizedName)")
            }
        }
        
        // Sort lenses by preference (wide first, then ultra-wide, then tele)
        availableLenses.sort { lhs, rhs in
            let order: [FrameMetadata.Lens] = [.wide, .ultraWide, .tele, .unknown]
            let lhsIndex = order.firstIndex(of: lhs) ?? order.count
            let rhsIndex = order.firstIndex(of: rhs) ?? order.count
            return lhsIndex < rhsIndex
        }
        
        // Check multi-cam support
        isMultiCamSupported = AVCaptureMultiCamSession.isMultiCamSupported && availableLenses.count > 1
        
        // Set default lens
        currentLens = availableLenses.first ?? .wide
        
        logger.info("Camera discovery complete: \(availableLenses.count) lenses, multi-cam: \(isMultiCamSupported)")
    }
    
    /// Get the AVCaptureDevice for a specific lens
    public func device(for lens: FrameMetadata.Lens) -> AVCaptureDevice? {
        return lensToDevice[lens]
    }
    
    /// Get all devices for multi-cam capture
    public func devicesForMultiCam() -> [AVCaptureDevice] {
        guard isMultiCamSupported else { return [] }
        
        // Prefer wide + tele combination, fallback to wide + ultra-wide
        var devices: [AVCaptureDevice] = []
        
        if let wideDevice = lensToDevice[.wide] {
            devices.append(wideDevice)
        }
        
        if let teleDevice = lensToDevice[.tele] {
            devices.append(teleDevice)
        } else if let ultraWideDevice = lensToDevice[.ultraWide] {
            devices.append(ultraWideDevice)
        }
        
        return devices
    }
    
    /// Check if a specific lens supports depth capture
    public func supportsDepthCapture(lens: FrameMetadata.Lens) -> Bool {
        guard let device = lensToDevice[lens] else { return false }
        
        // Check if device supports depth data delivery
        let photoOutput = AVCapturePhotoOutput()
        return photoOutput.isDepthDataDeliverySupported(for: device.activeFormat)
    }
    
    /// Check if a specific lens supports portrait effects
    public func supportsPortraitEffects(lens: FrameMetadata.Lens) -> Bool {
        guard let device = lensToDevice[lens] else { return false }
        
        // Portrait effects typically require depth data and are not available on ultra-wide
        return supportsDepthCapture(lens: lens) && lens != .ultraWide
    }
    
    /// Get optimal lenses for a specific capture scenario
    public func optimalLenses(for scenario: CaptureScenario) -> [FrameMetadata.Lens] {
        switch scenario {
        case .portrait:
            // Prefer wide and tele for portrait (avoid ultra-wide distortion)
            return availableLenses.filter { $0 != .ultraWide }
            
        case .landscape:
            // Include ultra-wide for landscape shots
            return availableLenses
            
        case .lowLight:
            // Prefer wide lens for better light gathering
            return availableLenses.filter { $0 == .wide || $0 == .tele }
            
        case .macro:
            // Use wide lens for macro (closest focus distance)
            return [.wide]
            
        case .general:
            // Use all available lenses
            return availableLenses
        }
    }
    
    /// Get recommended exposure bracket settings for a lens
    public func exposureBracketSettings(for lens: FrameMetadata.Lens) -> [Float] {
        switch lens {
        case .ultraWide:
            // Ultra-wide typically has less dynamic range
            return [-0.5, 0.0, +0.5]
            
        case .wide:
            // Standard bracketing for main lens
            return [-0.7, 0.0, +0.7]
            
        case .tele:
            // Telephoto can handle wider bracketing
            return [-1.0, 0.0, +1.0]
            
        case .unknown:
            // Conservative bracketing
            return [-0.3, 0.0, +0.3]
        }
    }
    
    // MARK: - Private Methods
    
    private func getAvailableDeviceTypes() -> [AVCaptureDevice.DeviceType]? {
        var deviceTypes: [AVCaptureDevice.DeviceType] = []
        
        // Add device types based on iOS version and availability
        if #available(iOS 13.0, *) {
            deviceTypes.append(.builtInTripleCamera)
            deviceTypes.append(.builtInDualWideCamera)
            deviceTypes.append(.builtInUltraWideCamera)
        }
        
        deviceTypes.append(.builtInDualCamera)
        deviceTypes.append(.builtInWideAngleCamera)
        deviceTypes.append(.builtInTelephotoCamera)
        
        return deviceTypes.isEmpty ? nil : deviceTypes
    }
    
    private func mapDeviceToLens(_ device: AVCaptureDevice) -> FrameMetadata.Lens? {
        // Map device type to lens enum
        switch device.deviceType {
        case .builtInWideAngleCamera:
            return .wide
            
        case .builtInUltraWideCamera:
            return .ultraWide
            
        case .builtInTelephotoCamera:
            return .tele
            
        case .builtInDualCamera, .builtInDualWideCamera:
            // Dual camera systems typically expose the wide lens
            return .wide
            
        case .builtInTripleCamera:
            // Triple camera systems expose all lenses, but this method is called per device
            // The discovery session will find individual lenses
            return .wide
            
        default:
            logger.warning("Unknown device type: \(device.deviceType.rawValue)")
            return .unknown
        }
    }
    
    /// Get focal length information for debugging
    public func focalLengthInfo() -> [String: Float] {
        var info: [String: Float] = [:]
        
        for lens in availableLenses {
            if let device = lensToDevice[lens] {
                let focalLength = device.activeFormat.formatDescription.dimensions
                info[lens.displayName] = lens.focalLengthEquivalent
            }
        }
        
        return info
    }
    
    /// Get device capabilities summary
    public func deviceCapabilities() -> [String: Any] {
        var capabilities: [String: Any] = [:]
        
        capabilities["availableLenses"] = availableLenses.map { $0.rawValue }
        capabilities["isMultiCamSupported"] = isMultiCamSupported
        capabilities["deviceCount"] = discoveredDevices.count
        
        var lensCapabilities: [String: [String: Bool]] = [:]
        for lens in availableLenses {
            lensCapabilities[lens.rawValue] = [
                "supportsDepth": supportsDepthCapture(lens: lens),
                "supportsPortrait": supportsPortraitEffects(lens: lens)
            ]
        }
        capabilities["lensCapabilities"] = lensCapabilities
        
        return capabilities
    }
}

// MARK: - Supporting Types

/// Capture scenario for lens optimization
public enum CaptureScenario: String, CaseIterable {
    case portrait = "portrait"
    case landscape = "landscape"
    case lowLight = "lowLight"
    case macro = "macro"
    case general = "general"
    
    public var displayName: String {
        switch self {
        case .portrait: return "Portrait"
        case .landscape: return "Landscape"
        case .lowLight: return "Low Light"
        case .macro: return "Macro"
        case .general: return "General"
        }
    }
    
    public var description: String {
        switch self {
        case .portrait:
            return "Optimized for people and portraits with depth effects"
        case .landscape:
            return "Wide-angle capture for landscapes and architecture"
        case .lowLight:
            return "Enhanced capture for low-light conditions"
        case .macro:
            return "Close-up photography with fine detail"
        case .general:
            return "Balanced capture for everyday photography"
        }
    }
}

// MARK: - Extensions

extension AVCaptureDevice {
    /// Get a human-readable description of the device
    var lensDescription: String {
        let type = deviceType.rawValue
        let position = position == .back ? "Back" : "Front"
        return "\(position) \(type)"
    }
    
    /// Check if this device is suitable for portrait photography
    var isPortraitCapable: Bool {
        return deviceType != .builtInUltraWideCamera && position == .back
    }
    
    /// Get the equivalent focal length for this device
    var equivalentFocalLength: Float {
        // These are approximate values for common iPhone lenses
        switch deviceType {
        case .builtInUltraWideCamera:
            return 13.0
        case .builtInWideAngleCamera:
            return 26.0
        case .builtInTelephotoCamera:
            return 77.0
        default:
            return 26.0
        }
    }
}

extension CMFormatDescription {
    /// Get image dimensions from format description
    var dimensions: CMVideoDimensions {
        return CMVideoFormatDescriptionGetDimensions(self)
    }
    
    /// Get field of view information
    var fieldOfView: Float {
        // This would require more complex calculation based on sensor size
        // For now, return approximate values
        return 60.0 // degrees
    }
}

