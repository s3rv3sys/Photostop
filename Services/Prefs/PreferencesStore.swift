//
//  PreferencesStore.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import Combine
import os.log

/// Store for user preferences with per-user namespacing
@MainActor
final class PreferencesStore: ObservableObject {
    
    static let shared = PreferencesStore()
    
    // MARK: - Published Properties
    
    /// Current user preferences
    @Published private(set) var prefs: UserPreferences = UserPreferences()
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Last error
    @Published private(set) var lastError: Error?
    
    // MARK: - Private Properties
    
    private var currentUserId: String?
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "PreferencesStore")
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    
    private init() {
        logger.info("PreferencesStore initialized")
    }
    
    // MARK: - Public Interface
    
    /// Load preferences for a specific user
    func load(for userId: String) {
        logger.info("Loading preferences for user: \(userId.prefix(8))...")
        
        currentUserId = userId
        isLoading = true
        lastError = nil
        
        do {
            if let loadedPrefs = try readPreferences(for: userId) {
                prefs = loadedPrefs
                logger.info("Preferences loaded successfully")
            } else {
                // No existing preferences, use defaults
                prefs = UserPreferences.defaultPreferences()
                logger.info("No existing preferences found, using defaults")
                
                // Save default preferences
                try writePreferences(prefs, for: userId)
            }
        } catch {
            logger.error("Failed to load preferences: \(error.localizedDescription)")
            lastError = error
            prefs = UserPreferences.defaultPreferences()
        }
        
        isLoading = false
    }
    
    /// Save current preferences
    func save() {
        guard let userId = currentUserId else {
            logger.warning("Cannot save preferences: no current user ID")
            return
        }
        
        do {
            try writePreferences(prefs, for: userId)
            logger.info("Preferences saved successfully for user: \(userId.prefix(8))...")
        } catch {
            logger.error("Failed to save preferences: \(error.localizedDescription)")
            lastError = error
        }
    }
    
    /// Update specific preference and save
    func updatePreference<T>(_ keyPath: WritableKeyPath<UserPreferences, T>, value: T) {
        prefs[keyPath: keyPath] = value
        save()
    }
    
    /// Migrate preferences from one user to another
    func migrate(from oldUserId: String, to newUserId: String) throws {
        logger.info("Migrating preferences from \(oldUserId.prefix(8))... to \(newUserId.prefix(8))...")
        
        // Read old preferences
        let oldPrefs = try readPreferences(for: oldUserId) ?? UserPreferences.defaultPreferences()
        
        // Write to new user
        try writePreferences(oldPrefs, for: newUserId)
        
        // Update current state if this is the active user
        if currentUserId == oldUserId {
            currentUserId = newUserId
            prefs = oldPrefs
        }
        
        logger.info("Preferences migration completed")
    }
    
    /// Delete preferences for a specific user
    func deleteUser(_ userId: String) throws {
        logger.info("Deleting preferences for user: \(userId.prefix(8))...")
        
        let url = try preferencesURL(for: userId)
        
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            logger.info("Preferences file deleted")
        }
        
        // Clear current state if this was the active user
        if currentUserId == userId {
            currentUserId = nil
            prefs = UserPreferences.defaultPreferences()
        }
    }
    
    /// Reset preferences to defaults for current user
    func resetToDefaults() {
        prefs = UserPreferences.defaultPreferences()
        save()
        logger.info("Preferences reset to defaults")
    }
    
    /// Get preferences for a specific user (without loading)
    func getPreferences(for userId: String) throws -> UserPreferences? {
        return try readPreferences(for: userId)
    }
    
    /// Check if preferences exist for a user
    func hasPreferences(for userId: String) -> Bool {
        do {
            let url = try preferencesURL(for: userId)
            return fileManager.fileExists(atPath: url.path)
        } catch {
            return false
        }
    }
    
    /// List all users with preferences
    func getAllUserIds() throws -> [String] {
        let prefsDir = try preferencesDirectory()
        let contents = try fileManager.contentsOfDirectory(at: prefsDir, includingPropertiesForKeys: nil)
        
        return contents
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
    }
    
    // MARK: - Convenience Methods
    
    /// Update personalization preferences
    func updatePersonalization(
        enabled: Bool? = nil,
        portraitAffinity: Float? = nil,
        hdrAffinity: Float? = nil,
        teleAffinity: Float? = nil,
        ultraWideAffinity: Float? = nil
    ) {
        if let enabled = enabled {
            prefs.personalizeEnabled = enabled
        }
        if let portraitAffinity = portraitAffinity {
            prefs.portraitAffinity = max(-1.0, min(1.0, portraitAffinity))
        }
        if let hdrAffinity = hdrAffinity {
            prefs.hdrAffinity = max(-1.0, min(1.0, hdrAffinity))
        }
        if let teleAffinity = teleAffinity {
            prefs.teleAffinity = max(-1.0, min(1.0, teleAffinity))
        }
        if let ultraWideAffinity = ultraWideAffinity {
            prefs.ultraWideAffinity = max(-1.0, min(1.0, ultraWideAffinity))
        }
        
        save()
    }
    
    /// Update sharing preferences
    func updateSharing(
        watermark: Bool? = nil,
        attribution: Bool? = nil,
        instagramDefault: Bool? = nil,
        tiktokDefault: Bool? = nil
    ) {
        if let watermark = watermark {
            prefs.watermarkVisible = watermark
        }
        if let attribution = attribution {
            prefs.shareAttribution = attribution
        }
        if let instagramDefault = instagramDefault {
            prefs.shareToInstagramDefault = instagramDefault
        }
        if let tiktokDefault = tiktokDefault {
            prefs.shareToTikTokDefault = tiktokDefault
        }
        
        save()
    }
    
    /// Update privacy preferences
    func updatePrivacy(
        analytics: Bool? = nil,
        crashReporting: Bool? = nil
    ) {
        if let analytics = analytics {
            prefs.analyticsOptIn = analytics
        }
        if let crashReporting = crashReporting {
            prefs.crashReportingEnabled = crashReporting
        }
        
        save()
    }
    
    // MARK: - File System Operations
    
    /// Get preferences directory URL
    private func preferencesDirectory() throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let prefsDir = appSupport.appendingPathComponent("Preferences", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: prefsDir.path) {
            try fileManager.createDirectory(
                at: prefsDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        return prefsDir
    }
    
    /// Get preferences file URL for a specific user
    private func preferencesURL(for userId: String) throws -> URL {
        let prefsDir = try preferencesDirectory()
        return prefsDir.appendingPathComponent("\(userId).json")
    }
    
    /// Read preferences from disk
    private func readPreferences(for userId: String) throws -> UserPreferences? {
        let url = try preferencesURL(for: userId)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let preferences = try JSONDecoder().decode(UserPreferences.self, from: data)
        
        return preferences
    }
    
    /// Write preferences to disk
    private func writePreferences(_ preferences: UserPreferences, for userId: String) throws {
        let url = try preferencesURL(for: userId)
        
        var validatedPrefs = preferences
        validatedPrefs.validate()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(validatedPrefs)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - Preferences Store Errors

enum PreferencesError: LocalizedError {
    case userNotLoaded
    case fileSystemError(underlying: Error)
    case encodingError(underlying: Error)
    case decodingError(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .userNotLoaded:
            return "No user loaded in preferences store"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode preferences: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode preferences: \(error.localizedDescription)"
        }
    }
}

// MARK: - Extensions

extension PreferencesStore {
    /// Export preferences as JSON string (for debugging)
    func exportPreferences() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(prefs)
            return String(data: data, encoding: .utf8)
        } catch {
            logger.error("Failed to export preferences: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Import preferences from JSON string (for debugging)
    func importPreferences(from jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw PreferencesError.encodingError(underlying: NSError(domain: "PreferencesStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"]))
        }
        
        let importedPrefs = try JSONDecoder().decode(UserPreferences.self, from: data)
        prefs = importedPrefs
        save()
    }
}

