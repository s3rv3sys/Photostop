//
//  CrashMonitoringService.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import OSLog
import UIKit

/// Comprehensive crash monitoring and stability service for production apps
/// Uses OSLog for privacy-compliant logging without third-party dependencies
final class CrashMonitoringService: ObservableObject {
    
    static let shared = CrashMonitoringService()
    
    // MARK: - Logging Categories
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "CrashMonitoring")
    private let performanceLogger = Logger(subsystem: "com.servesys.photostop", category: "Performance")
    private let aiLogger = Logger(subsystem: "com.servesys.photostop", category: "AIProcessing")
    private let userLogger = Logger(subsystem: "com.servesys.photostop", category: "UserActions")
    
    // MARK: - Performance Tracking
    
    private var performanceMetrics: [String: PerformanceMetric] = [:]
    private let metricsQueue = DispatchQueue(label: "com.photostop.metrics", qos: .utility)
    
    // MARK: - Memory Monitoring
    
    private var memoryWarningCount = 0
    private var lastMemoryWarning: Date?
    
    // MARK: - Crash Detection
    
    private var isMonitoring = false
    private var appLaunchTime: Date?
    private var lastCrashReport: CrashReport?
    
    private init() {
        setupCrashMonitoring()
        setupMemoryMonitoring()
        setupPerformanceMonitoring()
    }
    
    // MARK: - Setup Methods
    
    private func setupCrashMonitoring() {
        appLaunchTime = Date()
        
        // Check for previous crashes
        checkForPreviousCrash()
        
        // Monitor app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        isMonitoring = true
        logger.info("Crash monitoring initialized")
    }
    
    private func setupMemoryMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(memoryWarningReceived),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    private func setupPerformanceMonitoring() {
        // Monitor main thread blocking
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.monitorMainThreadBlocking()
        }
    }
    
    // MARK: - Public Logging Methods
    
    /// Log general application events
    func logEvent(_ event: String, metadata: [String: Any] = [:]) {
        let metadataString = formatMetadata(metadata)
        logger.info("EVENT: \(event) \(metadataString)")
    }
    
    /// Log errors with context
    func logError(_ error: Error, context: String, metadata: [String: Any] = [:]) {
        let metadataString = formatMetadata(metadata)
        logger.error("ERROR in \(context): \(error.localizedDescription) \(metadataString)")
        
        // Track error patterns
        trackErrorPattern(error: error, context: context)
    }
    
    /// Log AI processing events
    func logAIProcessing(provider: String, operation: String, duration: TimeInterval, success: Bool, metadata: [String: Any] = [:]) {
        let metadataString = formatMetadata(metadata)
        let status = success ? "SUCCESS" : "FAILURE"
        aiLogger.info("AI_\(status): \(provider) \(operation) (\(String(format: "%.2f", duration))s) \(metadataString)")
    }
    
    /// Log user actions for analytics
    func logUserAction(_ action: String, metadata: [String: Any] = [:]) {
        let metadataString = formatMetadata(metadata)
        userLogger.info("USER_ACTION: \(action) \(metadataString)")
    }
    
    /// Log performance metrics
    func logPerformance(operation: String, duration: TimeInterval, memoryUsage: UInt64? = nil, metadata: [String: Any] = [:]) {
        let metadataString = formatMetadata(metadata)
        let memoryString = memoryUsage.map { "memory: \($0)MB" } ?? ""
        performanceLogger.info("PERFORMANCE: \(operation) (\(String(format: "%.2f", duration))s) \(memoryString) \(metadataString)")
    }
    
    // MARK: - Performance Tracking
    
    /// Start tracking performance for an operation
    func startPerformanceTracking(for operation: String) -> PerformanceTracker {
        let tracker = PerformanceTracker(operation: operation, startTime: Date())
        metricsQueue.async { [weak self] in
            self?.performanceMetrics[operation] = PerformanceMetric(
                operation: operation,
                startTime: tracker.startTime,
                memoryAtStart: self?.getCurrentMemoryUsage() ?? 0
            )
        }
        return tracker
    }
    
    /// End performance tracking and log results
    func endPerformanceTracking(_ tracker: PerformanceTracker, success: Bool = true, metadata: [String: Any] = [:]) {
        let duration = Date().timeIntervalSince(tracker.startTime)
        let currentMemory = getCurrentMemoryUsage()
        
        metricsQueue.async { [weak self] in
            guard let self = self,
                  let metric = self.performanceMetrics[tracker.operation] else { return }
            
            let memoryDelta = currentMemory - metric.memoryAtStart
            var enhancedMetadata = metadata
            enhancedMetadata["memory_delta"] = memoryDelta
            enhancedMetadata["success"] = success
            
            self.logPerformance(
                operation: tracker.operation,
                duration: duration,
                memoryUsage: currentMemory,
                metadata: enhancedMetadata
            )
            
            self.performanceMetrics.removeValue(forKey: tracker.operation)
        }
    }
    
    // MARK: - Memory Monitoring
    
    @objc private func memoryWarningReceived() {
        memoryWarningCount += 1
        lastMemoryWarning = Date()
        
        let currentMemory = getCurrentMemoryUsage()
        logger.warning("MEMORY_WARNING: Count \(self.memoryWarningCount), Usage: \(currentMemory)MB")
        
        // Log memory-intensive operations
        logMemoryIntensiveOperations()
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
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
            return info.resident_size / 1024 / 1024 // Convert to MB
        } else {
            return 0
        }
    }
    
    private func logMemoryIntensiveOperations() {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let activeOperations = self.performanceMetrics.keys.joined(separator: ", ")
            if !activeOperations.isEmpty {
                self.logger.warning("MEMORY_WARNING_CONTEXT: Active operations: \(activeOperations)")
            }
        }
    }
    
    // MARK: - Crash Detection
    
    private func checkForPreviousCrash() {
        let userDefaults = UserDefaults.standard
        let lastLaunchKey = "PhotoStop_LastLaunch"
        let cleanShutdownKey = "PhotoStop_CleanShutdown"
        
        let lastLaunch = userDefaults.object(forKey: lastLaunchKey) as? Date
        let cleanShutdown = userDefaults.bool(forKey: cleanShutdownKey)
        
        if let lastLaunch = lastLaunch, !cleanShutdown {
            // Potential crash detected
            let crashReport = CrashReport(
                timestamp: lastLaunch,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                osVersion: UIDevice.current.systemVersion,
                deviceModel: UIDevice.current.model,
                memoryWarnings: memoryWarningCount
            )
            
            lastCrashReport = crashReport
            logger.error("POTENTIAL_CRASH_DETECTED: Last launch \(lastLaunch), no clean shutdown")
        }
        
        // Mark this launch
        userDefaults.set(Date(), forKey: lastLaunchKey)
        userDefaults.set(false, forKey: cleanShutdownKey)
    }
    
    @objc private func appWillTerminate() {
        UserDefaults.standard.set(true, forKey: "PhotoStop_CleanShutdown")
        logger.info("APP_TERMINATING: Clean shutdown recorded")
    }
    
    @objc private func appDidEnterBackground() {
        UserDefaults.standard.set(true, forKey: "PhotoStop_CleanShutdown")
        logger.info("APP_BACKGROUNDED: Clean state recorded")
    }
    
    @objc private func appWillEnterForeground() {
        UserDefaults.standard.set(false, forKey: "PhotoStop_CleanShutdown")
        logger.info("APP_FOREGROUNDED: Monitoring resumed")
    }
    
    // MARK: - Main Thread Monitoring
    
    private func monitorMainThreadBlocking() {
        while isMonitoring {
            let startTime = Date()
            
            DispatchQueue.main.async { [weak self] in
                let responseTime = Date().timeIntervalSince(startTime)
                
                if responseTime > 0.1 { // 100ms threshold
                    self?.logger.warning("MAIN_THREAD_BLOCKING: Response time \(String(format: "%.2f", responseTime))s")
                }
            }
            
            Thread.sleep(forTimeInterval: 1.0) // Check every second
        }
    }
    
    // MARK: - Error Pattern Tracking
    
    private var errorPatterns: [String: ErrorPattern] = [:]
    
    private func trackErrorPattern(error: Error, context: String) {
        let key = "\(context):\(type(of: error))"
        
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            if var pattern = self.errorPatterns[key] {
                pattern.count += 1
                pattern.lastOccurrence = Date()
                self.errorPatterns[key] = pattern
            } else {
                self.errorPatterns[key] = ErrorPattern(
                    errorType: String(describing: type(of: error)),
                    context: context,
                    count: 1,
                    firstOccurrence: Date(),
                    lastOccurrence: Date()
                )
            }
            
            // Log if error is becoming frequent
            if let pattern = self.errorPatterns[key], pattern.count >= 5 {
                self.logger.error("ERROR_PATTERN: \(key) occurred \(pattern.count) times")
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func formatMetadata(_ metadata: [String: Any]) -> String {
        guard !metadata.isEmpty else { return "" }
        
        let pairs = metadata.map { key, value in
            "\(key): \(value)"
        }
        return "[\(pairs.joined(separator: ", "))]"
    }
    
    // MARK: - Public Diagnostic Methods
    
    /// Get current app health status
    func getHealthStatus() -> AppHealthStatus {
        let currentMemory = getCurrentMemoryUsage()
        let uptime = Date().timeIntervalSince(appLaunchTime ?? Date())
        
        return AppHealthStatus(
            memoryUsage: currentMemory,
            memoryWarnings: memoryWarningCount,
            uptime: uptime,
            lastCrash: lastCrashReport,
            activeOperations: performanceMetrics.keys.count
        )
    }
    
    /// Export diagnostic data for support
    func exportDiagnosticData() -> DiagnosticData {
        let healthStatus = getHealthStatus()
        
        return DiagnosticData(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            osVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model,
            healthStatus: healthStatus,
            errorPatterns: Array(errorPatterns.values)
        )
    }
    
    deinit {
        isMonitoring = false
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

struct PerformanceTracker {
    let operation: String
    let startTime: Date
}

struct PerformanceMetric {
    let operation: String
    let startTime: Date
    let memoryAtStart: UInt64
}

struct CrashReport {
    let timestamp: Date
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let memoryWarnings: Int
}

struct ErrorPattern {
    let errorType: String
    let context: String
    var count: Int
    let firstOccurrence: Date
    var lastOccurrence: Date
}

struct AppHealthStatus {
    let memoryUsage: UInt64
    let memoryWarnings: Int
    let uptime: TimeInterval
    let lastCrash: CrashReport?
    let activeOperations: Int
}

struct DiagnosticData {
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let deviceModel: String
    let healthStatus: AppHealthStatus
    let errorPatterns: [ErrorPattern]
}

// MARK: - Convenience Extensions

extension CrashMonitoringService {
    
    /// Convenience method for tracking AI operations
    func trackAIOperation<T>(
        provider: String,
        operation: String,
        metadata: [String: Any] = [:],
        block: () async throws -> T
    ) async rethrows -> T {
        let tracker = startPerformanceTracking(for: "\(provider)_\(operation)")
        
        do {
            let result = try await block()
            endPerformanceTracking(tracker, success: true, metadata: metadata)
            logAIProcessing(provider: provider, operation: operation, duration: Date().timeIntervalSince(tracker.startTime), success: true, metadata: metadata)
            return result
        } catch {
            endPerformanceTracking(tracker, success: false, metadata: metadata)
            logAIProcessing(provider: provider, operation: operation, duration: Date().timeIntervalSince(tracker.startTime), success: false, metadata: metadata)
            logError(error, context: "\(provider)_\(operation)", metadata: metadata)
            throw error
        }
    }
    
    /// Convenience method for tracking general operations
    func trackOperation<T>(
        _ operation: String,
        metadata: [String: Any] = [:],
        block: () throws -> T
    ) rethrows -> T {
        let tracker = startPerformanceTracking(for: operation)
        
        do {
            let result = try block()
            endPerformanceTracking(tracker, success: true, metadata: metadata)
            return result
        } catch {
            endPerformanceTracking(tracker, success: false, metadata: metadata)
            logError(error, context: operation, metadata: metadata)
            throw error
        }
    }
}

