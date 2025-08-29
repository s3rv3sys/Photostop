//
//  PersonalizationStore.swift
//  PhotoStop - Personalization v1
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import OSLog

/// On-device storage for user personalization preferences
public final class PersonalizationStore: Sendable {
    
    static let shared = PersonalizationStore()
    
    // MARK: - Constants
    
    private let userDefaultsKey = "photostop_personalization_v1"
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "PersonalizationStore")
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "personalization.store", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Load personalization profile from persistent storage
    public func load() -> PersonalizationProfile {
        return queue.sync {
            guard let data = userDefaults.data(forKey: userDefaultsKey) else {
                logger.info("No personalization profile found, creating default")
                return PersonalizationProfile.default()
            }
            
            do {
                let profile = try JSONDecoder().decode(PersonalizationProfile.self, from: data)
                logger.info("Loaded personalization profile v\(profile.version)")
                return profile
            } catch {
                logger.error("Failed to decode personalization profile: \(error.localizedDescription)")
                logger.info("Creating default profile due to decode error")
                return PersonalizationProfile.default()
            }
        }
    }
    
    /// Save personalization profile to persistent storage
    public func save(_ profile: PersonalizationProfile) {
        queue.async {
            do {
                let data = try JSONEncoder().encode(profile)
                self.userDefaults.set(data, forKey: self.userDefaultsKey)
                self.logger.debug("Saved personalization profile v\(profile.version)")
            } catch {
                self.logger.error("Failed to encode personalization profile: \(error.localizedDescription)")
            }
        }
    }
    
    /// Reset personalization profile to factory defaults
    public func reset() {
        queue.sync {
            userDefaults.removeObject(forKey: userDefaultsKey)
            logger.info("Reset personalization profile to defaults")
        }
    }
    
    /// Check if personalization data exists
    public func hasExistingProfile() -> Bool {
        return queue.sync {
            return userDefaults.data(forKey: userDefaultsKey) != nil
        }
    }
    
    /// Get profile version from storage without full decode
    public func getStoredVersion() -> Int? {
        return queue.sync {
            guard let data = userDefaults.data(forKey: userDefaultsKey) else {
                return nil
            }
            
            do {
                // Decode just the version field for efficiency
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                return json?["version"] as? Int
            } catch {
                return nil
            }
        }
    }
    
    /// Migrate profile if needed (for future version upgrades)
    public func migrateIfNeeded() -> PersonalizationProfile {
        let profile = load()
        
        // Future migration logic would go here
        // For now, just ensure we have the latest version
        if profile.version < PersonalizationProfile.currentVersion {
            logger.info("Migrating personalization profile from v\(profile.version) to v\(PersonalizationProfile.currentVersion)")
            
            var migratedProfile = profile
            migratedProfile.version = PersonalizationProfile.currentVersion
            
            save(migratedProfile)
            return migratedProfile
        }
        
        return profile
    }
    
    /// Export profile data for debugging or backup
    public func exportData() -> [String: Any] {
        let profile = load()
        
        return [
            "version": profile.version,
            "enabled": profile.enabled,
            "preferences": [
                "sharpnessWeight": profile.sharpnessWeight,
                "exposureWeight": profile.exposureWeight,
                "noiseTolerance": profile.noiseTolerance,
                "portraitAffinity": profile.portraitAffinity,
                "hdrAffinity": profile.hdrAffinity,
                "teleAffinity": profile.teleAffinity,
                "ultraWideAffinity": profile.ultraWideAffinity
            ],
            "learningRates": [
                "positive": profile.lrPositive,
                "negative": profile.lrNegative
            ],
            "metadata": [
                "hasExistingProfile": hasExistingProfile(),
                "storedVersion": getStoredVersion() as Any
            ]
        ]
    }
}

// MARK: - PersonalizationProfile

/// User personalization preferences stored on-device
public struct PersonalizationProfile: Codable, Sendable {
    
    // MARK: - Version Management
    
    /// Current profile version for migration support
    public static let currentVersion = 1
    
    /// Profile schema version
    public var version: Int = currentVersion
    
    /// Whether personalization is enabled
    public var enabled: Bool = true
    
    // MARK: - Core Preferences (range: -1.0 to 1.0, neutral = 0.0)
    
    /// Preference for image sharpness (+1 = prefers sharp, -1 = tolerates soft)
    public var sharpnessWeight: Float = 0.0
    
    /// Preference for balanced exposure (+1 = prefers balanced, -1 = prefers moody/low-key)
    public var exposureWeight: Float = 0.0
    
    /// Tolerance for image noise (0.0 = intolerant, 1.0 = very tolerant)
    public var noiseTolerance: Float = 0.5
    
    /// Affinity for portrait/depth effects (-1.0 to 1.0)
    public var portraitAffinity: Float = 0.0
    
    /// Affinity for HDR/high contrast images (-1.0 to 1.0)
    public var hdrAffinity: Float = 0.0
    
    /// Affinity for telephoto lens captures (-1.0 to 1.0)
    public var teleAffinity: Float = 0.0
    
    /// Affinity for ultra-wide lens captures (-1.0 to 1.0)
    public var ultraWideAffinity: Float = 0.0
    
    // MARK: - Learning Parameters
    
    /// Learning rate for positive feedback (small values for stability)
    public var lrPositive: Float = 0.02
    
    /// Learning rate for negative feedback (small values for stability)
    public var lrNegative: Float = 0.02
    
    // MARK: - Initialization
    
    public init() {}
    
    /// Create default neutral profile
    public static func `default`() -> PersonalizationProfile {
        return PersonalizationProfile()
    }
    
    /// Create profile with custom preferences (for testing)
    public static func custom(
        enabled: Bool = true,
        sharpnessWeight: Float = 0.0,
        exposureWeight: Float = 0.0,
        noiseTolerance: Float = 0.5,
        portraitAffinity: Float = 0.0,
        hdrAffinity: Float = 0.0,
        teleAffinity: Float = 0.0,
        ultraWideAffinity: Float = 0.0,
        lrPositive: Float = 0.02,
        lrNegative: Float = 0.02
    ) -> PersonalizationProfile {
        
        var profile = PersonalizationProfile()
        profile.enabled = enabled
        profile.sharpnessWeight = sharpnessWeight
        profile.exposureWeight = exposureWeight
        profile.noiseTolerance = noiseTolerance
        profile.portraitAffinity = portraitAffinity
        profile.hdrAffinity = hdrAffinity
        profile.teleAffinity = teleAffinity
        profile.ultraWideAffinity = ultraWideAffinity
        profile.lrPositive = lrPositive
        profile.lrNegative = lrNegative
        
        return profile.clamped()
    }
    
    // MARK: - Validation & Clamping
    
    /// Clamp all values to valid ranges
    public func clamped() -> PersonalizationProfile {
        var clamped = self
        
        // Clamp preference weights to [-1, 1]
        clamped.sharpnessWeight = max(-1.0, min(1.0, sharpnessWeight))
        clamped.exposureWeight = max(-1.0, min(1.0, exposureWeight))
        clamped.portraitAffinity = max(-1.0, min(1.0, portraitAffinity))
        clamped.hdrAffinity = max(-1.0, min(1.0, hdrAffinity))
        clamped.teleAffinity = max(-1.0, min(1.0, teleAffinity))
        clamped.ultraWideAffinity = max(-1.0, min(1.0, ultraWideAffinity))
        
        // Clamp noise tolerance to [0, 1]
        clamped.noiseTolerance = max(0.0, min(1.0, noiseTolerance))
        
        // Clamp learning rates to reasonable bounds
        clamped.lrPositive = max(0.001, min(0.1, lrPositive))
        clamped.lrNegative = max(0.001, min(0.1, lrNegative))
        
        return clamped
    }
    
    /// Check if profile has neutral preferences
    public var isNeutral: Bool {
        let threshold: Float = 0.05
        
        return abs(sharpnessWeight) < threshold &&
               abs(exposureWeight) < threshold &&
               abs(noiseTolerance - 0.5) < threshold &&
               abs(portraitAffinity) < threshold &&
               abs(hdrAffinity) < threshold &&
               abs(teleAffinity) < threshold &&
               abs(ultraWideAffinity) < threshold
    }
    
    /// Get preference strength (0.0 to 1.0) for UI display
    public var preferenceStrength: Float {
        let weights = [
            abs(sharpnessWeight),
            abs(exposureWeight),
            abs(noiseTolerance - 0.5) * 2.0, // Convert [0,1] to [0,1] distance from neutral
            abs(portraitAffinity),
            abs(hdrAffinity),
            abs(teleAffinity),
            abs(ultraWideAffinity)
        ]
        
        let avgStrength = weights.reduce(0, +) / Float(weights.count)
        return min(1.0, avgStrength)
    }
    
    // MARK: - Description
    
    /// Human-readable summary of preferences
    public var summary: String {
        var components: [String] = []
        
        if abs(sharpnessWeight) > 0.1 {
            components.append("Sharpness: \(sharpnessWeight > 0 ? "Prefers sharp" : "Tolerates soft")")
        }
        
        if abs(exposureWeight) > 0.1 {
            components.append("Exposure: \(exposureWeight > 0 ? "Balanced" : "Moody")")
        }
        
        if abs(noiseTolerance - 0.5) > 0.2 {
            components.append("Noise: \(noiseTolerance > 0.5 ? "Tolerant" : "Intolerant")")
        }
        
        if abs(portraitAffinity) > 0.1 {
            components.append("Portrait: \(portraitAffinity > 0 ? "Likes" : "Avoids")")
        }
        
        if abs(hdrAffinity) > 0.1 {
            components.append("HDR: \(hdrAffinity > 0 ? "Likes" : "Avoids")")
        }
        
        if abs(teleAffinity) > 0.1 {
            components.append("Tele: \(teleAffinity > 0 ? "Prefers" : "Avoids")")
        }
        
        if abs(ultraWideAffinity) > 0.1 {
            components.append("Ultra-wide: \(ultraWideAffinity > 0 ? "Prefers" : "Avoids")")
        }
        
        if components.isEmpty {
            return "Neutral preferences"
        }
        
        return components.joined(separator: ", ")
    }
    
    /// Debug description with all values
    public var debugDescription: String {
        return """
        PersonalizationProfile v\(version) (enabled: \(enabled))
        - Sharpness: \(String(format: "%.3f", sharpnessWeight))
        - Exposure: \(String(format: "%.3f", exposureWeight))
        - Noise Tolerance: \(String(format: "%.3f", noiseTolerance))
        - Portrait: \(String(format: "%.3f", portraitAffinity))
        - HDR: \(String(format: "%.3f", hdrAffinity))
        - Tele: \(String(format: "%.3f", teleAffinity))
        - Ultra-wide: \(String(format: "%.3f", ultraWideAffinity))
        - Learning rates: +\(lrPositive), -\(lrNegative)
        - Strength: \(String(format: "%.1f%%", preferenceStrength * 100))
        """
    }
}

