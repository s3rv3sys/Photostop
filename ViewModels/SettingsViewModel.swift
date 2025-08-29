//
//  SettingsViewModel.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import SwiftUI
import Combine

/// ViewModel for app settings and configuration
@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var apiKey = ""
    @Published var isAPIKeyConfigured = false
    @Published var showingAPIKeyInput = false
    
    // Usage and subscription
    @Published var usageCount = 0
    @Published var remainingFreeUses = 20
    @Published var isPremiumUser = false
    @Published var showingSubscription = false
    
    // Storage
    @Published var storageUsed = "0 MB"
    @Published var editHistoryCount = 0
    @Published var showingStorageManagement = false
    
    // App preferences
    @Published var enableWatermark = false
    @Published var autoSaveToPhotos = true
    @Published var enableHapticFeedback = true
    @Published var preferredImageQuality: ImageQuality = .high
    
    // Permissions
    @Published var cameraPermissionStatus = "Not Determined"
    @Published var photosPermissionStatus = "Not Determined"
    
    // UI State
    @Published var showingAbout = false
    @Published var showingPrivacyPolicy = false
    @Published var showingTermsOfService = false
    
    // Error handling
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var successMessage = ""
    
    // MARK: - Private Properties
    private let aiService = AIService()
    private let storageService = StorageService()
    private let cameraService = CameraService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadSettings()
        updatePermissionStatus()
        updateStorageInfo()
    }
    
    // MARK: - Public Methods
    
    /// Save API key
    func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            showError("Please enter a valid API key")
            return
        }
        
        let success = aiService.setAPIKey(trimmedKey)
        
        if success {
            isAPIKeyConfigured = true
            showingAPIKeyInput = false
            showSuccess("API key saved successfully")
            apiKey = "" // Clear the input field for security
        } else {
            showError("Failed to save API key")
        }
    }
    
    /// Remove API key
    func removeAPIKey() {
        let keychain = KeychainService.shared
        let success = keychain.delete("gemini_api_key")
        
        if success {
            isAPIKeyConfigured = false
            showSuccess("API key removed")
        } else {
            showError("Failed to remove API key")
        }
    }
    
    /// Clear edit history
    func clearEditHistory() async {
        let editedImages = await storageService.loadEditedImages()
        var deletedCount = 0
        
        for image in editedImages {
            if await storageService.deleteEditedImage(image) {
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            showSuccess("Cleared \(deletedCount) items from history")
            await updateStorageInfo()
        } else {
            showError("Failed to clear history")
        }
    }
    
    /// Clean up old images
    func cleanupOldImages() async {
        let deletedCount = await storageService.cleanupOldImages(keepCount: 20)
        
        if deletedCount > 0 {
            showSuccess("Cleaned up \(deletedCount) old images")
            await updateStorageInfo()
        } else {
            showSuccess("No cleanup needed")
        }
    }
    
    /// Reset usage count (for testing or premium users)
    func resetUsageCount() {
        aiService.resetUsageCount()
        showSuccess("Usage count reset")
    }
    
    /// Request camera permission
    func requestCameraPermission() async {
        let granted = await cameraService.requestCameraPermission()
        updatePermissionStatus()
        
        if granted {
            showSuccess("Camera permission granted")
        } else {
            showError("Camera permission denied")
        }
    }
    
    /// Request photos permission
    func requestPhotosPermission() async {
        let granted = await storageService.requestPhotoLibraryPermission()
        updatePermissionStatus()
        
        if granted {
            showSuccess("Photos permission granted")
        } else {
            showError("Photos permission denied")
        }
    }
    
    /// Export settings
    func exportSettings() -> [String: Any] {
        return [
            "enableWatermark": enableWatermark,
            "autoSaveToPhotos": autoSaveToPhotos,
            "enableHapticFeedback": enableHapticFeedback,
            "preferredImageQuality": preferredImageQuality.rawValue,
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
    }
    
    /// Import settings
    func importSettings(_ settings: [String: Any]) {
        enableWatermark = settings["enableWatermark"] as? Bool ?? false
        autoSaveToPhotos = settings["autoSaveToPhotos"] as? Bool ?? true
        enableHapticFeedback = settings["enableHapticFeedback"] as? Bool ?? true
        
        if let qualityRaw = settings["preferredImageQuality"] as? String,
           let quality = ImageQuality(rawValue: qualityRaw) {
            preferredImageQuality = quality
        }
        
        saveSettings()
        showSuccess("Settings imported successfully")
    }
    
    /// Get app version
    func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    /// Get app info for about screen
    func getAppInfo() -> [String: String] {
        return [
            "Version": getAppVersion(),
            "Build Date": getBuildDate(),
            "Developer": "Esh",
            "Framework": "SwiftUI + Core ML",
            "AI Provider": "Google Gemini"
        ]
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind AI service properties
        aiService.$usageCount
            .receive(on: DispatchQueue.main)
            .assign(to: \.usageCount, on: self)
            .store(in: &cancellables)
        
        aiService.$remainingFreeUses
            .receive(on: DispatchQueue.main)
            .assign(to: \.remainingFreeUses, on: self)
            .store(in: &cancellables)
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        enableWatermark = defaults.bool(forKey: "enable_watermark")
        autoSaveToPhotos = defaults.object(forKey: "auto_save_to_photos") as? Bool ?? true
        enableHapticFeedback = defaults.object(forKey: "enable_haptic_feedback") as? Bool ?? true
        isPremiumUser = defaults.bool(forKey: "is_premium_user")
        
        if let qualityRaw = defaults.string(forKey: "preferred_image_quality"),
           let quality = ImageQuality(rawValue: qualityRaw) {
            preferredImageQuality = quality
        }
        
        isAPIKeyConfigured = aiService.isAPIKeyConfigured()
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(enableWatermark, forKey: "enable_watermark")
        defaults.set(autoSaveToPhotos, forKey: "auto_save_to_photos")
        defaults.set(enableHapticFeedback, forKey: "enable_haptic_feedback")
        defaults.set(preferredImageQuality.rawValue, forKey: "preferred_image_quality")
    }
    
    private func updatePermissionStatus() {
        // Update camera permission status
        switch cameraService.authorizationStatus {
        case .authorized:
            cameraPermissionStatus = "Authorized"
        case .denied:
            cameraPermissionStatus = "Denied"
        case .restricted:
            cameraPermissionStatus = "Restricted"
        case .notDetermined:
            cameraPermissionStatus = "Not Determined"
        @unknown default:
            cameraPermissionStatus = "Unknown"
        }
        
        // Update photos permission status
        switch storageService.authorizationStatus {
        case .authorized:
            photosPermissionStatus = "Authorized"
        case .limited:
            photosPermissionStatus = "Limited"
        case .denied:
            photosPermissionStatus = "Denied"
        case .restricted:
            photosPermissionStatus = "Restricted"
        case .notDetermined:
            photosPermissionStatus = "Not Determined"
        @unknown default:
            photosPermissionStatus = "Unknown"
        }
    }
    
    private func updateStorageInfo() {
        Task {
            storageUsed = await storageService.getStorageUsedString()
            let editedImages = await storageService.loadEditedImages()
            editHistoryCount = editedImages.count
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func showSuccess(_ message: String) {
        successMessage = message
        showingSuccess = true
    }
    
    private func getBuildDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date()) // In a real app, this would be the actual build date
    }
}

// MARK: - Supporting Types

enum ImageQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case maximum = "maximum"
    
    var displayName: String {
        switch self {
        case .low: return "Low (Faster)"
        case .medium: return "Medium"
        case .high: return "High"
        case .maximum: return "Maximum (Slower)"
        }
    }
    
    var compressionQuality: CGFloat {
        switch self {
        case .low: return 0.5
        case .medium: return 0.7
        case .high: return 0.8
        case .maximum: return 0.9
        }
    }
}

