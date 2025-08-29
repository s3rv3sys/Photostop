//
//  Entitlements.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import Foundation

/// User entitlements based on subscription tier
struct Entitlements: Codable, Sendable {
    let tier: UserTier
    let budgetCap: Int
    let premiumCap: Int
    let maxResolution: CGSize
    let priorityQueue: Bool
    let watermarkFree: Bool
    let unlimitedHistory: Bool
    
    /// Free tier entitlements
    static let free = Entitlements(
        tier: .free,
        budgetCap: 50,
        premiumCap: 5,
        maxResolution: CGSize(width: 2048, height: 2048),
        priorityQueue: false,
        watermarkFree: false,
        unlimitedHistory: false
    )
    
    /// Pro tier entitlements
    static let pro = Entitlements(
        tier: .pro,
        budgetCap: 500,
        premiumCap: 300,
        maxResolution: CGSize(width: 4096, height: 4096),
        priorityQueue: true,
        watermarkFree: true,
        unlimitedHistory: true
    )
    
    /// Get entitlements for a specific tier
    static func forTier(_ tier: UserTier) -> Entitlements {
        switch tier {
        case .free: return .free
        case .pro: return .pro
        }
    }
}

/// Manages user entitlements and subscription status
final class EntitlementStore: @unchecked Sendable {
    static let shared = EntitlementStore()
    
    private let defaults = UserDefaults.standard
    private let kEntitlements = "photostop_entitlements"
    private let kPremiumCreditsAddon = "photostop_premium_addon"
    private let kLastEntitlementCheck = "photostop_last_entitlement_check"
    
    private init() {}
    
    /// Get current user entitlements
    func current() -> Entitlements {
        if let data = defaults.data(forKey: kEntitlements),
           let entitlements = try? JSONDecoder().decode(Entitlements.self, from: data) {
            return entitlements
        }
        return .free
    }
    
    /// Set user entitlements
    func set(_ entitlements: Entitlements) {
        if let data = try? JSONEncoder().encode(entitlements) {
            defaults.set(data, forKey: kEntitlements)
            defaults.set(Date(), forKey: kLastEntitlementCheck)
            
            // Notify observers
            NotificationCenter.default.post(
                name: .entitlementsChanged,
                object: entitlements
            )
        }
    }
    
    /// Get addon premium credits (from consumable purchases)
    func getAddonPremiumCredits() -> Int {
        return defaults.integer(forKey: kPremiumCreditsAddon)
    }
    
    /// Add addon premium credits
    func addAddonPremiumCredits(_ count: Int) {
        let current = getAddonPremiumCredits()
        defaults.set(current + count, forKey: kPremiumCreditsAddon)
        
        // Notify observers
        NotificationCenter.default.post(
            name: .addonCreditsChanged,
            object: current + count
        )
    }
    
    /// Consume one addon premium credit if available
    func consumeAddonPremiumCredit() -> Bool {
        let current = getAddonPremiumCredits()
        guard current > 0 else { return false }
        
        defaults.set(current - 1, forKey: kPremiumCreditsAddon)
        
        // Notify observers
        NotificationCenter.default.post(
            name: .addonCreditsChanged,
            object: current - 1
        )
        
        return true
    }
    
    /// Get last entitlement check date
    func lastEntitlementCheck() -> Date? {
        return defaults.object(forKey: kLastEntitlementCheck) as? Date
    }
    
    /// Check if entitlements need refresh (older than 1 hour)
    func needsEntitlementRefresh() -> Bool {
        guard let lastCheck = lastEntitlementCheck() else { return true }
        return Date().timeIntervalSince(lastCheck) > 3600 // 1 hour
    }
    
    /// Reset to free tier (for testing or subscription expiry)
    func resetToFree() {
        set(.free)
    }
    
    /// Upgrade to pro tier
    func upgradeToPro() {
        set(.pro)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let entitlementsChanged = Notification.Name("EntitlementStore.entitlementsChanged")
    static let addonCreditsChanged = Notification.Name("EntitlementStore.addonCreditsChanged")
}

// MARK: - Entitlements Extensions

extension Entitlements {
    
    /// Check if user can perform an operation based on cost class
    func canPerform(_ costClass: CostClass, withAddonCredits addonCredits: Int = 0) -> Bool {
        switch costClass {
        case .free:
            return true // Always allowed
        case .budget:
            return budgetCap > 0 // Has budget allocation
        case .premium:
            return premiumCap > 0 || addonCredits > 0 // Has premium allocation or addon credits
        }
    }
    
    /// Get effective premium credits (subscription + addon)
    func effectivePremiumCredits(withAddon addonCredits: Int) -> Int {
        return premiumCap + addonCredits
    }
    
    /// Get feature comparison for UI display
    static func featureComparison() -> [(feature: String, free: String, pro: String)] {
        return [
            ("Budget AI Edits/Month", "50", "500"),
            ("Premium AI Credits/Month", "5", "300"),
            ("Max Resolution", "2K", "4K"),
            ("Priority Processing", "❌", "✅"),
            ("Watermark-Free", "❌", "✅"),
            ("Unlimited History", "❌", "✅"),
            ("Customer Support", "Community", "Priority")
        ]
    }
}

// MARK: - Usage Integration

extension EntitlementStore {
    
    /// Update usage tracker with current entitlements
    func syncWithUsageTracker() {
        let entitlements = current()
        let usageTracker = UsageTracker.shared
        
        // Update tier
        usageTracker.currentTier = entitlements.tier
        
        // Update capacity limits based on tier
        switch entitlements.tier {
        case .free:
            usageTracker.budgetCapFree = entitlements.budgetCap
            usageTracker.premiumCapFree = entitlements.premiumCap
        case .pro:
            usageTracker.budgetCapPro = entitlements.budgetCap
            usageTracker.premiumCapPro = entitlements.premiumCap
        }
    }
}

