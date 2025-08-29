//
//  PersonalizationEngine.swift
//  PhotoStop - Personalization v1
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import OSLog

/// Engine for learning user preferences and applying personalization bias to frame scores
@MainActor
public final class PersonalizationEngine: ObservableObject {
    
    static let shared = PersonalizationEngine()
    
    // MARK: - Published Properties
    
    @Published public private(set) var profile: PersonalizationProfile
    @Published public private(set) var isLearning = false
    @Published public private(set) var totalFeedbackEvents = 0
    
    // MARK: - Private Properties
    
    private let store = PersonalizationStore.shared
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "PersonalizationEngine")
    
    // Bias application coefficients (small values to avoid overwhelming base scores)
    private let coefficients = BiasCoefficients(
        sharpness: 0.10,
        exposure: 0.08,
        noise: 0.08,
        portrait: 0.06,
        hdr: 0.05,
        lens: 0.05
    )
    
    // Maximum bias adjustment to prevent overwhelming base scores
    private let maxBiasAdjustment: Float = 0.15
    
    // MARK: - Initialization
    
    private init() {
        self.profile = store.migrateIfNeeded()
        logger.info("PersonalizationEngine initialized with profile v\(profile.version)")
        
        // Load feedback count from UserDefaults
        totalFeedbackEvents = UserDefaults.standard.integer(forKey: "personalization_feedback_count")
    }
    
    // MARK: - Public Interface
    
    /// Get current personalization profile
    public func currentProfile() -> PersonalizationProfile {
        return profile
    }
    
    /// Enable or disable personalization
    public func setEnabled(_ enabled: Bool) {
        profile.enabled = enabled
        store.save(profile)
        logger.info("Personalization \(enabled ? "enabled" : "disabled")")
    }
    
    /// Update preferences based on user feedback
    public func update(with event: PersonalizationEvent) {
        guard profile.enabled else {
            logger.debug("Skipping personalization update - disabled")
            return
        }
        
        isLearning = true
        defer { isLearning = false }
        
        logger.debug("Processing personalization event: \(event.feedback)")
        
        // Apply learning updates based on feedback
        switch event.feedback {
        case .positive:
            applyPositiveFeedback(event)
        case .negative:
            applyNegativeFeedback(event)
        }
        
        // Clamp all values to valid ranges
        profile = profile.clamped()
        
        // Persist updated profile
        store.save(profile)
        
        // Update feedback count
        totalFeedbackEvents += 1
        UserDefaults.standard.set(totalFeedbackEvents, forKey: "personalization_feedback_count")
        
        logger.debug("Updated personalization profile: strength=\(String(format: "%.3f", profile.preferenceStrength))")
    }
    
    /// Apply personalization bias to a base frame score
    public func applyBias(
        baseScore: Float,
        features: PersonalizationFeatures,
        lens: FrameMetadata.Lens
    ) -> Float {
        
        guard profile.enabled else {
            return baseScore
        }
        
        // Calculate lens-specific bias
        let lensBias = getLensBias(for: lens)
        
        // Calculate feature-based adjustments
        var adjustment: Float = 0.0
        
        adjustment += coefficients.sharpness * profile.sharpnessWeight * features.sharpness
        adjustment += coefficients.exposure * profile.exposureWeight * features.exposure
        adjustment -= coefficients.noise * (1.0 - profile.noiseTolerance) * features.noise
        adjustment += coefficients.portrait * profile.portraitAffinity * features.depth
        adjustment += coefficients.hdr * profile.hdrAffinity * features.hdr
        adjustment += coefficients.lens * lensBias
        
        // Clamp adjustment to prevent overwhelming base score
        adjustment = max(-maxBiasAdjustment, min(maxBiasAdjustment, adjustment))
        
        // Apply adjustment and clamp final score to [0, 1]
        let finalScore = max(0.0, min(1.0, baseScore + adjustment))
        
        if abs(adjustment) > 0.01 {
            logger.debug("Applied personalization bias: \(String(format: "%.3f", adjustment)) (base: \(String(format: "%.3f", baseScore)) → final: \(String(format: "%.3f", finalScore)))")
        }
        
        return finalScore
    }
    
    /// Reset personalization to neutral state
    public func reset() {
        profile = PersonalizationProfile.default()
        store.reset()
        totalFeedbackEvents = 0
        UserDefaults.standard.removeObject(forKey: "personalization_feedback_count")
        logger.info("Reset personalization to neutral state")
    }
    
    /// Update specific preference manually (for Settings UI)
    public func updatePreference(_ keyPath: WritableKeyPath<PersonalizationProfile, Float>, value: Float) {
        profile[keyPath: keyPath] = value
        profile = profile.clamped()
        store.save(profile)
        logger.debug("Manually updated preference")
    }
    
    /// Get personalization statistics for debugging
    public func getStatistics() -> PersonalizationStatistics {
        return PersonalizationStatistics(
            profile: profile,
            totalFeedbackEvents: totalFeedbackEvents,
            isEnabled: profile.enabled,
            preferenceStrength: profile.preferenceStrength,
            isNeutral: profile.isNeutral
        )
    }
    
    // MARK: - Private Learning Methods
    
    private func applyPositiveFeedback(_ event: PersonalizationEvent) {
        let lr = profile.lrPositive
        
        // Update sharpness preference
        // If user likes this image and it's sharp (>0.5), increase sharpness weight
        // If user likes this image and it's soft (<0.5), decrease sharpness weight
        profile.sharpnessWeight += lr * (event.normalizedSharpness - 0.5)
        
        // Update exposure preference
        // If user likes this image and it's well-exposed (>0.5), increase exposure weight
        profile.exposureWeight += lr * (event.normalizedExposure - 0.5)
        
        // Update noise tolerance
        // If user likes this image and it's noisy, increase noise tolerance
        // If user likes this image and it's clean, decrease noise tolerance (prefers clean)
        profile.noiseTolerance += lr * (0.5 - event.normalizedNoise)
        
        // Update portrait affinity
        // If user likes this image and it has good depth, increase portrait affinity
        profile.portraitAffinity += lr * (event.depthSignal - 0.5)
        
        // Update HDR affinity
        // If user likes this image and it has HDR characteristics, increase HDR affinity
        profile.hdrAffinity += lr * (event.hdrSignal - 0.5)
        
        // Update lens affinities
        updateLensAffinities(for: event.lens, learningRate: lr, isPositive: true)
    }
    
    private func applyNegativeFeedback(_ event: PersonalizationEvent) {
        let lr = profile.lrNegative
        
        // Apply opposite adjustments for negative feedback
        profile.sharpnessWeight -= lr * (event.normalizedSharpness - 0.5)
        profile.exposureWeight -= lr * (event.normalizedExposure - 0.5)
        profile.noiseTolerance -= lr * (0.5 - event.normalizedNoise)
        profile.portraitAffinity -= lr * (event.depthSignal - 0.5)
        profile.hdrAffinity -= lr * (event.hdrSignal - 0.5)
        
        // Update lens affinities
        updateLensAffinities(for: event.lens, learningRate: lr, isPositive: false)
    }
    
    private func updateLensAffinities(for lens: FrameMetadata.Lens, learningRate: Float, isPositive: Bool) {
        let adjustment: Float = isPositive ? learningRate : -learningRate
        
        switch lens {
        case .tele:
            profile.teleAffinity += adjustment * 0.25
            profile.ultraWideAffinity -= adjustment * 0.05 // Slight negative adjustment to others
            
        case .ultraWide:
            profile.ultraWideAffinity += adjustment * 0.25
            profile.teleAffinity -= adjustment * 0.05
            
        case .wide, .unknown:
            // Wide lens is neutral, so apply smaller adjustments
            profile.teleAffinity -= adjustment * 0.02
            profile.ultraWideAffinity -= adjustment * 0.02
        }
    }
    
    private func getLensBias(for lens: FrameMetadata.Lens) -> Float {
        switch lens {
        case .tele:
            return profile.teleAffinity
        case .ultraWide:
            return profile.ultraWideAffinity
        case .wide, .unknown:
            return 0.0 // Neutral for wide lens
        }
    }
}

// MARK: - Supporting Types

/// Event passed when user provides feedback on a frame selection
public struct PersonalizationEvent: Sendable {
    
    public enum Feedback: String, CaseIterable {
        case positive = "positive"
        case negative = "negative"
        
        public var displayName: String {
            switch self {
            case .positive: return "👍 Liked"
            case .negative: return "👎 Disliked"
            }
        }
    }
    
    public let feedback: Feedback
    public let normalizedSharpness: Float   // 0..1 (0 = very soft, 1 = very sharp)
    public let normalizedExposure: Float    // 0..1 (0 = poor exposure, 1 = well balanced)
    public let normalizedNoise: Float       // 0..1 (0 = clean, 1 = very noisy)
    public let depthSignal: Float           // 0..1 (hasDepth * depthQuality)
    public let hdrSignal: Float             // 0..1 (derived from contrast/dynamic range)
    public let lens: FrameMetadata.Lens     // Lens used for capture
    
    public init(
        feedback: Feedback,
        normalizedSharpness: Float,
        normalizedExposure: Float,
        normalizedNoise: Float,
        depthSignal: Float,
        hdrSignal: Float,
        lens: FrameMetadata.Lens
    ) {
        self.feedback = feedback
        self.normalizedSharpness = max(0, min(1, normalizedSharpness))
        self.normalizedExposure = max(0, min(1, normalizedExposure))
        self.normalizedNoise = max(0, min(1, normalizedNoise))
        self.depthSignal = max(0, min(1, depthSignal))
        self.hdrSignal = max(0, min(1, hdrSignal))
        self.lens = lens
    }
    
    /// Create event from FrameBundle.Item
    public static func from(
        item: FrameBundle.Item,
        feedback: Feedback
    ) -> PersonalizationEvent {
        
        let metadata = item.metadata
        
        // Convert metadata to normalized features
        let sharpness = 1.0 - metadata.motionScore // Invert motion score to get sharpness
        let exposure = calculateExposureBalance(from: metadata)
        let noise = calculateNoiseLevel(from: metadata)
        let depth = metadata.hasDepth ? metadata.depthQuality : 0.0
        let hdr = calculateHDRSignal(from: metadata)
        
        return PersonalizationEvent(
            feedback: feedback,
            normalizedSharpness: sharpness,
            normalizedExposure: exposure,
            normalizedNoise: noise,
            depthSignal: depth,
            hdrSignal: hdr,
            lens: metadata.lens
        )
    }
    
    private static func calculateExposureBalance(from metadata: FrameMetadata) -> Float {
        let luma = metadata.meanLuma
        
        // Calculate how well-balanced the exposure is
        // Optimal exposure is around 0.4-0.6 luminance
        if luma >= 0.4 && luma <= 0.6 {
            return 1.0
        } else if luma >= 0.2 && luma <= 0.8 {
            return 0.7
        } else if luma >= 0.1 && luma <= 0.9 {
            return 0.4
        } else {
            return 0.1
        }
    }
    
    private static func calculateNoiseLevel(from metadata: FrameMetadata) -> Float {
        let iso = metadata.iso
        
        // Convert ISO to normalized noise level
        if iso <= 400 {
            return 0.1
        } else if iso <= 800 {
            return 0.3
        } else if iso <= 1600 {
            return 0.5
        } else if iso <= 3200 {
            return 0.7
        } else {
            return 0.9
        }
    }
    
    private static func calculateHDRSignal(from metadata: FrameMetadata) -> Float {
        // Estimate HDR potential from exposure and scene characteristics
        let hasHighContrast = metadata.meanLuma < 0.3 || metadata.meanLuma > 0.7
        let isLowLight = metadata.isLowLight
        
        if hasHighContrast && !isLowLight {
            return 0.8
        } else if hasHighContrast || metadata.iso > 800 {
            return 0.5
        } else {
            return 0.2
        }
    }
}

/// Normalized features for personalization bias calculation
public struct PersonalizationFeatures {
    public let sharpness: Float     // 0..1
    public let exposure: Float      // 0..1
    public let noise: Float         // 0..1
    public let depth: Float         // 0..1
    public let hdr: Float           // 0..1
    
    public init(sharpness: Float, exposure: Float, noise: Float, depth: Float, hdr: Float) {
        self.sharpness = max(0, min(1, sharpness))
        self.exposure = max(0, min(1, exposure))
        self.noise = max(0, min(1, noise))
        self.depth = max(0, min(1, depth))
        self.hdr = max(0, min(1, hdr))
    }
    
    /// Create features from FrameBundle.Item
    public static func from(item: FrameBundle.Item) -> PersonalizationFeatures {
        let metadata = item.metadata
        
        return PersonalizationFeatures(
            sharpness: 1.0 - metadata.motionScore,
            exposure: PersonalizationEvent.calculateExposureBalance(from: metadata),
            noise: PersonalizationEvent.calculateNoiseLevel(from: metadata),
            depth: metadata.hasDepth ? metadata.depthQuality : 0.0,
            hdr: PersonalizationEvent.calculateHDRSignal(from: metadata)
        )
    }
}

/// Coefficients for bias calculation
private struct BiasCoefficients {
    let sharpness: Float
    let exposure: Float
    let noise: Float
    let portrait: Float
    let hdr: Float
    let lens: Float
}

/// Statistics for personalization debugging and UI display
public struct PersonalizationStatistics {
    public let profile: PersonalizationProfile
    public let totalFeedbackEvents: Int
    public let isEnabled: Bool
    public let preferenceStrength: Float
    public let isNeutral: Bool
    
    public var summary: String {
        if !isEnabled {
            return "Personalization disabled"
        } else if isNeutral {
            return "Learning your preferences (\(totalFeedbackEvents) ratings)"
        } else {
            let strength = Int(preferenceStrength * 100)
            return "\(strength)% personalized (\(totalFeedbackEvents) ratings)"
        }
    }
    
    public var detailedSummary: String {
        return """
        Personalization Status: \(isEnabled ? "Enabled" : "Disabled")
        Total Feedback Events: \(totalFeedbackEvents)
        Preference Strength: \(String(format: "%.1f%%", preferenceStrength * 100))
        Profile: \(profile.summary)
        """
    }
}

