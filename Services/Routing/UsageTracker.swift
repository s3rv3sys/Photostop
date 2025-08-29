//
//  UsageTracker.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import Foundation

/// User subscription tier
public enum Tier: String, CaseIterable {
    case free = "free"
    case pro = "pro"
    
    public var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        }
    }
}

/// Usage statistics for a specific period
public struct UsageStats: Codable {
    public let budgetUsed: Int
    public let premiumUsed: Int
    public let period: String // YYYY-MM format
    public let resetDate: Date
    
    public init(budgetUsed: Int = 0, premiumUsed: Int = 0, period: String, resetDate: Date) {
        self.budgetUsed = budgetUsed
        self.premiumUsed = premiumUsed
        self.period = period
        self.resetDate = resetDate
    }
}

/// Tracks usage across different cost classes and manages monthly limits
final class UsageTracker: @unchecked Sendable {
    static let shared = UsageTracker()
    
    private let store = UserDefaults.standard
    private let keychain = KeychainService.shared
    
    // UserDefaults keys
    private let kBudgetUsage = "usage_budget_month"
    private let kPremiumUsage = "usage_premium_month"
    private let kResetDate = "usage_reset_date"
    private let kCurrentPeriod = "usage_current_period"
    private let kUserTier = "user_tier"
    
    // Monthly limits configuration
    public struct Limits {
        let budgetCapFree: Int
        let premiumCapFree: Int
        let budgetCapPro: Int
        let premiumCapPro: Int
        
        static let `default` = Limits(
            budgetCapFree: 50,
            premiumCapFree: 5,
            budgetCapPro: 500,
            premiumCapPro: 50
        )
    }
    
    public var limits = Limits.default
    
    private init() {
        ensureMonthBoundary()
    }
    
    // MARK: - Public Interface
    
    /// Get current user tier
    public var currentTier: Tier {
        get {
            let tierString = store.string(forKey: kUserTier) ?? Tier.free.rawValue
            return Tier(rawValue: tierString) ?? .free
        }
        set {
            store.set(newValue.rawValue, forKey: kUserTier)
        }
    }
    
    /// Check if user can perform an operation of the given cost class
    public func canPerform(_ costClass: CostClass, tier: Tier? = nil) -> Bool {
        let userTier = tier ?? currentTier
        return remaining(for: userTier, cost: costClass) > 0
    }
    
    /// Get remaining usage for a specific cost class and tier
    public func remaining(for tier: Tier, cost: CostClass) -> Int {
        ensureMonthBoundary()
        
        switch cost {
        case .freeLocal:
            return .max // Unlimited local processing
            
        case .budget:
            let used = store.integer(forKey: kBudgetUsage)
            let cap = (tier == .free) ? limits.budgetCapFree : limits.budgetCapPro
            return max(0, cap - used)
            
        case .premium:
            let used = store.integer(forKey: kPremiumUsage)
            let cap = (tier == .free) ? limits.premiumCapFree : limits.premiumCapPro
            return max(0, cap - used)
        }
    }
    
    /// Get total capacity for a cost class and tier
    public func capacity(for tier: Tier, cost: CostClass) -> Int {
        switch cost {
        case .freeLocal:
            return .max
        case .budget:
            return (tier == .free) ? limits.budgetCapFree : limits.budgetCapPro
        case .premium:
            return (tier == .free) ? limits.premiumCapFree : limits.premiumCapPro
        }
    }
    
    /// Increment usage counter for a cost class
    public func increment(_ cost: CostClass) {
        ensureMonthBoundary()
        
        switch cost {
        case .freeLocal:
            return // No tracking needed for free operations
            
        case .budget:
            let current = store.integer(forKey: kBudgetUsage)
            store.set(current + 1, forKey: kBudgetUsage)
            
        case .premium:
            let current = store.integer(forKey: kPremiumUsage)
            store.set(current + 1, forKey: kPremiumUsage)
        }
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .usageUpdated,
            object: nil,
            userInfo: ["costClass": cost]
        )
    }
    
    /// Get current usage statistics
    public func getCurrentStats() -> UsageStats {
        ensureMonthBoundary()
        
        let budgetUsed = store.integer(forKey: kBudgetUsage)
        let premiumUsed = store.integer(forKey: kPremiumUsage)
        let period = store.string(forKey: kCurrentPeriod) ?? currentPeriodString()
        let resetDate = store.object(forKey: kResetDate) as? Date ?? Date()
        
        return UsageStats(
            budgetUsed: budgetUsed,
            premiumUsed: premiumUsed,
            period: period,
            resetDate: resetDate
        )
    }
    
    /// Get usage percentage for a cost class
    public func usagePercentage(for tier: Tier, cost: CostClass) -> Double {
        let total = capacity(for: tier, cost: cost)
        if total == .max { return 0.0 }
        
        let used = total - remaining(for: tier, cost: cost)
        return Double(used) / Double(total)
    }
    
    /// Reset usage counters (for testing or manual reset)
    public func resetUsage() {
        store.set(0, forKey: kBudgetUsage)
        store.set(0, forKey: kPremiumUsage)
        store.set(Date(), forKey: kResetDate)
        store.set(currentPeriodString(), forKey: kCurrentPeriod)
        
        NotificationCenter.default.post(name: .usageReset, object: nil)
    }
    
    /// Get next reset date
    public var nextResetDate: Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        
        guard let currentMonth = calendar.date(from: components),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else {
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        }
        
        return nextMonth
    }
    
    /// Days until next reset
    public var daysUntilReset: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: nextResetDate).day ?? 0
        return max(0, days)
    }
    
    // MARK: - Private Methods
    
    private func ensureMonthBoundary(now: Date = Date()) {
        let calendar = Calendar.current
        let currentPeriod = currentPeriodString(for: now)
        let storedPeriod = store.string(forKey: kCurrentPeriod)
        
        if currentPeriod != storedPeriod {
            // New month detected, reset counters
            store.set(0, forKey: kBudgetUsage)
            store.set(0, forKey: kPremiumUsage)
            store.set(now, forKey: kResetDate)
            store.set(currentPeriod, forKey: kCurrentPeriod)
            
            NotificationCenter.default.post(name: .usageReset, object: nil)
        }
    }
    
    private func currentPeriodString(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let usageUpdated = Notification.Name("UsageTracker.usageUpdated")
    static let usageReset = Notification.Name("UsageTracker.usageReset")
    static let usageLimitReached = Notification.Name("UsageTracker.usageLimitReached")
}

// MARK: - Usage Analytics

extension UsageTracker {
    /// Get historical usage data (if stored)
    public func getHistoricalStats(months: Int = 6) -> [UsageStats] {
        var stats: [UsageStats] = []
        let calendar = Calendar.current
        let now = Date()
        
        for i in 0..<months {
            guard let date = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let period = currentPeriodString(for: date)
            
            // For now, we only have current month data
            // In a full implementation, you'd store historical data
            if period == currentPeriodString() {
                stats.append(getCurrentStats())
            } else {
                stats.append(UsageStats(period: period, resetDate: date))
            }
        }
        
        return stats.reversed() // Chronological order
    }
    
    /// Get usage efficiency score (0.0 to 1.0)
    public func getEfficiencyScore() -> Double {
        let stats = getCurrentStats()
        let tier = currentTier
        
        let budgetCap = capacity(for: tier, cost: .budget)
        let premiumCap = capacity(for: tier, cost: .premium)
        
        if budgetCap == 0 && premiumCap == 0 { return 1.0 }
        
        // Prefer budget usage over premium
        let budgetEfficiency = budgetCap > 0 ? Double(stats.budgetUsed) / Double(budgetCap) : 0.0
        let premiumPenalty = premiumCap > 0 ? Double(stats.premiumUsed) / Double(premiumCap) * 0.5 : 0.0
        
        return max(0.0, min(1.0, budgetEfficiency - premiumPenalty))
    }
    
    /// Estimate cost savings from using routing vs always premium
    public func estimatedSavings() -> (budgetSaved: Int, premiumSaved: Int) {
        let stats = getCurrentStats()
        
        // Assume without routing, all operations would use premium
        let totalOperations = stats.budgetUsed + stats.premiumUsed
        let premiumSaved = stats.budgetUsed // These would have been premium
        let budgetSaved = 0 // Budget operations are already optimal
        
        return (budgetSaved: budgetSaved, premiumSaved: premiumSaved)
    }
}

