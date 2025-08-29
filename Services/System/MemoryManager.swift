//
//  MemoryManager.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import UIKit
import os.log

/// Service for enhanced memory management and low-memory handling
final class MemoryManager {
    
    static let shared = MemoryManager()
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "MemoryManager")
    
    private var memoryWarningObserver: NSObjectProtocol?
    private var isLowMemoryMode = false
    
    private init() {
        setupMemoryWarningObserver()
        logger.info("MemoryManager initialized")
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    /// Execute heavy image operation with memory management
    func executeImageOperation<T>(_ operation: () throws -> T) rethrows -> T {
        return try autoreleasepool {
            let result = try operation()
            
            // Force garbage collection after heavy operations
            if isLowMemoryMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.performMemoryCleanup()
                }
            }
            
            return result
        }
    }
    
    /// Execute async image operation with memory management
    func executeImageOperation<T>(_ operation: () async throws -> T) async rethrows -> T {
        return try await withTaskGroup(of: T.self) { group in
            group.addTask {
                return try await autoreleasepool {
                    let result = try await operation()
                    
                    // Force garbage collection after heavy operations
                    if self.isLowMemoryMode {
                        await MainActor.run {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.performMemoryCleanup()
                            }
                        }
                    }
                    
                    return result
                }
            }
            
            return try await group.next()!
        }
    }
    
    /// Check current memory usage
    func getCurrentMemoryUsage() -> MemoryUsage {
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
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            let usagePercentage = (usedMB / totalMB) * 100.0
            
            return MemoryUsage(
                usedMB: usedMB,
                totalMB: totalMB,
                usagePercentage: usagePercentage,
                isLowMemory: usagePercentage > 80.0
            )
        } else {
            logger.error("Failed to get memory usage info")
            return MemoryUsage(usedMB: 0, totalMB: 0, usagePercentage: 0, isLowMemory: false)
        }
    }
    
    /// Optimize image for memory constraints
    func optimizeImageForMemory(_ image: UIImage) -> UIImage {
        let memoryUsage = getCurrentMemoryUsage()
        
        // If memory usage is high, reduce image quality
        if memoryUsage.isLowMemory {
            logger.info("Optimizing image for low memory conditions")
            return resizeImageForMemory(image, maxDimension: 1024)
        } else if memoryUsage.usagePercentage > 60.0 {
            logger.info("Optimizing image for moderate memory usage")
            return resizeImageForMemory(image, maxDimension: 2048)
        }
        
        // Normal memory conditions - use original or slightly optimized
        if max(image.size.width, image.size.height) > 4096 {
            return resizeImageForMemory(image, maxDimension: 4096)
        }
        
        return image
    }
    
    /// Get recommended image processing quality based on memory
    func getRecommendedImageQuality() -> ImageProcessingQuality {
        let memoryUsage = getCurrentMemoryUsage()
        
        if memoryUsage.isLowMemory {
            return .low
        } else if memoryUsage.usagePercentage > 60.0 {
            return .medium
        } else {
            return .high
        }
    }
    
    /// Force memory cleanup
    func performMemoryCleanup() {
        logger.info("Performing memory cleanup")
        
        // Clear image caches
        URLCache.shared.removeAllCachedResponses()
        
        // Clear any custom caches
        NotificationCenter.default.post(name: .memoryCleanupRequested, object: nil)
        
        // Log memory usage after cleanup
        let usage = getCurrentMemoryUsage()
        logger.info("Memory usage after cleanup: \(String(format: "%.1f", usage.usagePercentage))%")
    }
    
    // MARK: - Private Methods
    
    /// Setup memory warning observer
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    /// Handle memory warning
    private func handleMemoryWarning() {
        logger.warning("Memory warning received")
        isLowMemoryMode = true
        
        // Perform immediate cleanup
        performMemoryCleanup()
        
        // Reset low memory mode after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            self.isLowMemoryMode = false
            self.logger.info("Low memory mode reset")
        }
        
        // Notify other components
        NotificationCenter.default.post(name: .memoryWarningReceived, object: nil)
    }
    
    /// Resize image for memory constraints
    private func resizeImageForMemory(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxCurrentDimension = max(size.width, size.height)
        
        if maxCurrentDimension <= maxDimension {
            return image
        }
        
        let scale = maxDimension / maxCurrentDimension
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Data Models

/// Memory usage information
struct MemoryUsage {
    let usedMB: Double
    let totalMB: Double
    let usagePercentage: Double
    let isLowMemory: Bool
    
    var formattedUsage: String {
        return String(format: "%.1f MB / %.1f MB (%.1f%%)", usedMB, totalMB, usagePercentage)
    }
}

/// Image processing quality levels
enum ImageProcessingQuality {
    case low
    case medium
    case high
    
    var compressionQuality: CGFloat {
        switch self {
        case .low: return 0.6
        case .medium: return 0.8
        case .high: return 0.9
        }
    }
    
    var maxDimension: CGFloat {
        switch self {
        case .low: return 1024
        case .medium: return 2048
        case .high: return 4096
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let memoryWarningReceived = Notification.Name("MemoryWarningReceived")
    static let memoryCleanupRequested = Notification.Name("MemoryCleanupRequested")
}

// MARK: - Extensions

extension MemoryManager {
    
    /// Execute Core Image operation with memory management
    func executeCoreImageOperation<T>(_ operation: () throws -> T) rethrows -> T {
        return try executeImageOperation {
            // Core Image operations can be memory intensive
            let context = CIContext(options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3),
                .cacheIntermediates: false // Don't cache intermediates in low memory
            ])
            
            defer {
                // Clear any temporary resources
                context.clearCaches()
            }
            
            return try operation()
        }
    }
    
    /// Execute ML model operation with memory management
    func executeMLOperation<T>(_ operation: () throws -> T) rethrows -> T {
        return try executeImageOperation {
            // ML operations are very memory intensive
            let result = try operation()
            
            // Force cleanup after ML operations
            if isLowMemoryMode {
                DispatchQueue.main.async {
                    self.performMemoryCleanup()
                }
            }
            
            return result
        }
    }
}

