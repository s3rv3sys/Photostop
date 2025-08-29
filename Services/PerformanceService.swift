//
//  PerformanceService.swift
//  PhotoStop
//
//  Performance monitoring and optimization service
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import UIKit
import Network
import os.log

/// Service for performance monitoring and optimization
final class PerformanceService: ObservableObject {
    
    static let shared = PerformanceService()
    private init() {
        setupMemoryWarningObserver()
        setupNetworkMonitoring()
    }
    
    // MARK: - Published Properties
    
    @Published var isLowMemoryWarning = false
    @Published var networkStatus: NetworkStatus = .unknown
    @Published var isOfflineMode = false
    
    // MARK: - Memory Management
    
    private var memoryWarningObserver: NSObjectProtocol?
    
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        isLowMemoryWarning = true
        
        // Clear image caches
        clearImageCaches()
        
        // Clear result cache if needed
        ResultCache.shared.clearOldEntries()
        
        // Log memory warning
        os_log("Memory warning received - clearing caches", log: .performance, type: .info)
        
        // Reset warning after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.isLowMemoryWarning = false
        }
    }
    
    /// Get current memory usage in MB
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        
        return 0
    }
    
    /// Check if device is under memory pressure
    func isUnderMemoryPressure() -> Bool {
        let memoryUsage = getCurrentMemoryUsage()
        let deviceMemory = ProcessInfo.processInfo.physicalMemory / 1024 / 1024 // MB
        let usagePercentage = memoryUsage / Double(deviceMemory) * 100
        
        return usagePercentage > 80 // Consider 80%+ as memory pressure
    }
    
    /// Clear image caches to free memory
    private func clearImageCaches() {
        // Clear URLSession cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear any custom image caches
        // In a real app, you might have SDWebImage or similar
        
        os_log("Cleared image caches due to memory pressure", log: .performance, type: .info)
    }
    
    // MARK: - Network Monitoring
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func updateNetworkStatus(_ path: NWPath) {
        switch path.status {
        case .satisfied:
            if path.usesInterfaceType(.wifi) {
                networkStatus = .wifi
            } else if path.usesInterfaceType(.cellular) {
                networkStatus = .cellular
            } else {
                networkStatus = .other
            }
            isOfflineMode = false
            
        case .unsatisfied:
            networkStatus = .none
            isOfflineMode = true
            
        case .requiresConnection:
            networkStatus = .requiresConnection
            isOfflineMode = true
            
        @unknown default:
            networkStatus = .unknown
            isOfflineMode = true
        }
        
        os_log("Network status changed: %@", log: .performance, type: .info, networkStatus.description)
    }
    
    /// Check if network is suitable for AI processing
    func isNetworkSuitableForAI() -> Bool {
        switch networkStatus {
        case .wifi:
            return true
        case .cellular:
            // Allow cellular but maybe with warnings for large operations
            return true
        case .none, .requiresConnection, .unknown:
            return false
        case .other:
            return true // Assume other connections (like ethernet) are good
        }
    }
    
    /// Get recommended image quality based on network
    func getRecommendedImageQuality() -> ImageQuality {
        switch networkStatus {
        case .wifi:
            return .high
        case .cellular:
            return .medium
        case .none, .requiresConnection, .unknown:
            return .low
        case .other:
            return .high
        }
    }
    
    // MARK: - Performance Metrics
    
    /// Measure execution time of a block
    func measureTime<T>(operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        os_log("Operation '%@' took %.3f seconds", log: .performance, type: .info, operation, timeElapsed)
        
        return result
    }
    
    /// Measure async execution time
    func measureAsyncTime<T>(operation: String, block: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        os_log("Async operation '%@' took %.3f seconds", log: .performance, type: .info, operation, timeElapsed)
        
        return result
    }
    
    // MARK: - Image Optimization
    
    /// Optimize image for processing based on device capabilities
    func optimizeImageForProcessing(_ image: UIImage) -> UIImage {
        let memoryPressure = isUnderMemoryPressure()
        let networkQuality = getRecommendedImageQuality()
        
        var maxDimension: CGFloat
        var compressionQuality: CGFloat
        
        // Adjust based on memory pressure
        if memoryPressure {
            maxDimension = 1024
            compressionQuality = 0.7
        } else {
            switch networkQuality {
            case .high:
                maxDimension = 2048
                compressionQuality = 0.9
            case .medium:
                maxDimension = 1536
                compressionQuality = 0.8
            case .low:
                maxDimension = 1024
                compressionQuality = 0.7
            }
        }
        
        return resizeImage(image, maxDimension: maxDimension, quality: compressionQuality)
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Only resize if the image is actually larger
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    // MARK: - Battery Optimization
    
    /// Check if device is in low power mode
    var isLowPowerModeEnabled: Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    /// Get processing priority based on battery status
    func getProcessingPriority() -> ProcessingPriority {
        if isLowPowerModeEnabled {
            return .low
        } else if isUnderMemoryPressure() {
            return .medium
        } else {
            return .high
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        networkMonitor.cancel()
    }
}

// MARK: - Supporting Types

enum NetworkStatus {
    case wifi
    case cellular
    case other
    case none
    case requiresConnection
    case unknown
    
    var description: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .other: return "Other"
        case .none: return "No Connection"
        case .requiresConnection: return "Requires Connection"
        case .unknown: return "Unknown"
        }
    }
}

enum ImageQuality {
    case high
    case medium
    case low
}

enum ProcessingPriority {
    case high
    case medium
    case low
}

// MARK: - Logging Extension

extension OSLog {
    static let performance = OSLog(subsystem: "com.servesys.photostop", category: "Performance")
}

