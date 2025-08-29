//
//  PreflightChecks.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import StoreKit
import os.log

/// Service for performing preflight checks at app startup
final class PreflightChecks {
    
    static let shared = PreflightChecks()
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "PreflightChecks")
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Perform all preflight checks
    func performAllChecks() async -> PreflightResult {
        logger.info("Starting preflight checks...")
        
        var issues: [PreflightIssue] = []
        
        // Check legal documents
        issues.append(contentsOf: await checkLegalDocuments())
        
        // Check StoreKit configuration
        issues.append(contentsOf: await checkStoreKitConfiguration())
        
        // Check network connectivity
        issues.append(contentsOf: checkNetworkConfiguration())
        
        // Check app configuration
        issues.append(contentsOf: checkAppConfiguration())
        
        // Check permissions
        issues.append(contentsOf: checkPermissionConfiguration())
        
        // Check file system
        issues.append(contentsOf: checkFileSystemConfiguration())
        
        let result = PreflightResult(
            isSuccess: issues.filter { $0.severity == .critical }.isEmpty,
            issues: issues
        )
        
        logger.info("Preflight checks completed. Critical issues: \(result.criticalIssues.count), Warnings: \(result.warnings.count)")
        
        return result
    }
    
    // MARK: - Individual Checks
    
    /// Check that legal documents are accessible
    private func checkLegalDocuments() async -> [PreflightIssue] {
        var issues: [PreflightIssue] = []
        
        // Check Privacy Policy URL
        let privacyPolicyURL = "https://servesys.com/photostop/privacy"
        if !(await isURLAccessible(privacyPolicyURL)) {
            issues.append(PreflightIssue(
                type: .legalDocuments,
                severity: .critical,
                message: "Privacy Policy URL is not accessible: \(privacyPolicyURL)",
                suggestion: "Ensure the privacy policy is published and accessible"
            ))
        }
        
        // Check Terms of Service URL
        let termsURL = "https://servesys.com/photostop/terms"
        if !(await isURLAccessible(termsURL)) {
            issues.append(PreflightIssue(
                type: .legalDocuments,
                severity: .critical,
                message: "Terms of Service URL is not accessible: \(termsURL)",
                suggestion: "Ensure the terms of service are published and accessible"
            ))
        }
        
        return issues
    }
    
    /// Check StoreKit product configuration
    private func checkStoreKitConfiguration() async -> [PreflightIssue] {
        var issues: [PreflightIssue] = []
        
        let expectedProductIDs = [
            "com.servesys.photostop.pro.monthly",
            "com.servesys.photostop.pro.yearly",
            "com.servesys.photostop.credits.premium10",
            "com.servesys.photostop.credits.premium50"
        ]
        
        do {
            let products = try await Product.products(for: expectedProductIDs)
            
            for expectedID in expectedProductIDs {
                if !products.contains(where: { $0.id == expectedID }) {
                    issues.append(PreflightIssue(
                        type: .storeKit,
                        severity: .critical,
                        message: "StoreKit product not found: \(expectedID)",
                        suggestion: "Configure the product in App Store Connect"
                    ))
                }
            }
            
            logger.info("StoreKit products found: \(products.count)/\(expectedProductIDs.count)")
            
        } catch {
            issues.append(PreflightIssue(
                type: .storeKit,
                severity: .critical,
                message: "Failed to load StoreKit products: \(error.localizedDescription)",
                suggestion: "Check App Store Connect configuration and network connectivity"
            ))
        }
        
        return issues
    }
    
    /// Check network configuration
    private func checkNetworkConfiguration() -> [PreflightIssue] {
        var issues: [PreflightIssue] = []
        
        // Check if we have network connectivity
        // This is a basic check - in production you might use NWPathMonitor
        let networkReachable = true // Placeholder - implement actual network check
        
        if !networkReachable {
            issues.append(PreflightIssue(
                type: .network,
                severity: .warning,
                message: "No network connectivity detected",
                suggestion: "Some features may not work without internet connection"
            ))
        }
        
        return issues
    }
    
    /// Check app configuration
    private func checkAppConfiguration() -> [PreflightIssue] {
        var issues: [PreflightIssue] = []
        
        // Check bundle identifier
        guard let bundleID = Bundle.main.bundleIdentifier else {
            issues.append(PreflightIssue(
                type: .appConfiguration,
                severity: .critical,
                message: "Bundle identifier is missing",
                suggestion: "Configure bundle identifier in project settings"
            ))
            return issues
        }
        
        if bundleID == "com.example.photostop" {
            issues.append(PreflightIssue(
                type: .appConfiguration,
                severity: .warning,
                message: "Using example bundle identifier",
                suggestion: "Update to production bundle identifier"
            ))
        }
        
        // Check app version
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            issues.append(PreflightIssue(
                type: .appConfiguration,
                severity: .warning,
                message: "App version is missing",
                suggestion: "Set CFBundleShortVersionString in Info.plist"
            ))
            return issues
        }
        
        if version == "1.0" {
            logger.info("App version: \(version)")
        }
        
        // Check Team ID
        guard let teamID = Bundle.main.infoDictionary?["TeamIdentifier"] as? String else {
            issues.append(PreflightIssue(
                type: .appConfiguration,
                severity: .warning,
                message: "Team ID is missing",
                suggestion: "Configure development team in project settings"
            ))
            return issues
        }
        
        if teamID != "NZBE9W77FA" {
            issues.append(PreflightIssue(
                type: .appConfiguration,
                severity: .warning,
                message: "Unexpected Team ID: \(teamID)",
                suggestion: "Verify development team configuration"
            ))
        }
        
        return issues
    }
    
    /// Check permission configuration
    private func checkPermissionConfiguration() -> [PreflightIssue] {
        var issues: [PreflightIssue] = []
        
        guard let infoPlist = Bundle.main.infoDictionary else {
            issues.append(PreflightIssue(
                type: .permissions,
                severity: .critical,
                message: "Info.plist is not accessible",
                suggestion: "Check Info.plist file configuration"
            ))
            return issues
        }
        
        // Check camera usage description
        if infoPlist["NSCameraUsageDescription"] == nil {
            issues.append(PreflightIssue(
                type: .permissions,
                severity: .critical,
                message: "Camera usage description is missing",
                suggestion: "Add NSCameraUsageDescription to Info.plist"
            ))
        }
        
        // Check photo library usage description
        if infoPlist["NSPhotoLibraryUsageDescription"] == nil {
            issues.append(PreflightIssue(
                type: .permissions,
                severity: .critical,
                message: "Photo library usage description is missing",
                suggestion: "Add NSPhotoLibraryUsageDescription to Info.plist"
            ))
        }
        
        // Check photo library add usage description
        if infoPlist["NSPhotoLibraryAddUsageDescription"] == nil {
            issues.append(PreflightIssue(
                type: .permissions,
                severity: .critical,
                message: "Photo library add usage description is missing",
                suggestion: "Add NSPhotoLibraryAddUsageDescription to Info.plist"
            ))
        }
        
        return issues
    }
    
    /// Check file system configuration
    private func checkFileSystemConfiguration() -> [PreflightIssue] {
        var issues: [PreflightIssue] = []
        
        // Check documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if documentsURL == nil {
            issues.append(PreflightIssue(
                type: .fileSystem,
                severity: .critical,
                message: "Cannot access documents directory",
                suggestion: "Check app sandbox configuration"
            ))
        }
        
        // Check available disk space
        if let documentsURL = documentsURL {
            do {
                let resourceValues = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
                if let availableCapacity = resourceValues.volumeAvailableCapacity {
                    let availableMB = availableCapacity / (1024 * 1024)
                    
                    if availableMB < 100 {
                        issues.append(PreflightIssue(
                            type: .fileSystem,
                            severity: .warning,
                            message: "Low disk space: \(availableMB)MB available",
                            suggestion: "User may need to free up space for photo storage"
                        ))
                    }
                    
                    logger.info("Available disk space: \(availableMB)MB")
                }
            } catch {
                issues.append(PreflightIssue(
                    type: .fileSystem,
                    severity: .warning,
                    message: "Cannot check available disk space: \(error.localizedDescription)",
                    suggestion: "Monitor disk space manually"
                ))
            }
        }
        
        return issues
    }
    
    // MARK: - Helper Methods
    
    /// Check if URL is accessible
    private func isURLAccessible(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            logger.error("URL accessibility check failed for \(urlString): \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Data Models

/// Result of preflight checks
struct PreflightResult {
    let isSuccess: Bool
    let issues: [PreflightIssue]
    
    var criticalIssues: [PreflightIssue] {
        issues.filter { $0.severity == .critical }
    }
    
    var warnings: [PreflightIssue] {
        issues.filter { $0.severity == .warning }
    }
    
    var hasIssues: Bool {
        !issues.isEmpty
    }
}

/// Individual preflight issue
struct PreflightIssue {
    let type: PreflightIssueType
    let severity: PreflightSeverity
    let message: String
    let suggestion: String
}

/// Types of preflight issues
enum PreflightIssueType {
    case legalDocuments
    case storeKit
    case network
    case appConfiguration
    case permissions
    case fileSystem
}

/// Severity levels for preflight issues
enum PreflightSeverity {
    case critical  // App cannot function properly
    case warning   // App can function but with limitations
}

// MARK: - Extensions

extension PreflightIssueType {
    var displayName: String {
        switch self {
        case .legalDocuments: return "Legal Documents"
        case .storeKit: return "StoreKit"
        case .network: return "Network"
        case .appConfiguration: return "App Configuration"
        case .permissions: return "Permissions"
        case .fileSystem: return "File System"
        }
    }
}

extension PreflightSeverity {
    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .warning: return "Warning"
        }
    }
    
    var emoji: String {
        switch self {
        case .critical: return "🔴"
        case .warning: return "🟡"
        }
    }
}

