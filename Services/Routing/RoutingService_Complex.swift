//
//  RoutingService.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import os.log

/// Represents a routing decision made by the service
public enum RoutingDecision {
    case route([ImageEditProvider])
    case requiresUpgrade(reason: UpgradeReason)
    case noProvidersAvailable
}

/// Reasons why an upgrade might be required
public enum UpgradeReason {
    case insufficientBudgetCredits(required: Int, remaining: Int)
    case insufficientPremiumCredits(required: Int, remaining: Int)
    case premiumFeatureRequired(feature: String)
    case tierLimitReached(tier: UserTier, limit: String)
    
    var displayTitle: String {
        switch self {
        case .insufficientBudgetCredits:
            return "Out of Budget Credits"
        case .insufficientPremiumCredits:
            return "Out of Premium Credits"
        case .premiumFeatureRequired:
            return "Premium Feature"
        case .tierLimitReached:
            return "Tier Limit Reached"
        }
    }
    
    var displayMessage: String {
        switch self {
        case .insufficientBudgetCredits(let required, let remaining):
            return "This edit requires \(required) budget credits, but you only have \(remaining) remaining this month."
        case .insufficientPremiumCredits(let required, let remaining):
            return "This edit requires \(required) premium credits, but you only have \(remaining) remaining this month."
        case .premiumFeatureRequired(let feature):
            return "\(feature) is a premium feature that requires PhotoStop Pro."
        case .tierLimitReached(let tier, let limit):
            return "You've reached the \(limit) limit for \(tier.displayName) users."
        }
    }
    
    var suggestedAction: String {
        switch self {
        case .insufficientBudgetCredits, .insufficientPremiumCredits:
            return "Upgrade to Pro for more credits"
        case .premiumFeatureRequired, .tierLimitReached:
            return "Upgrade to PhotoStop Pro"
        }
    }
}

/// Main routing service that orchestrates AI provider selection and execution
final class RoutingService: @unchecked Sendable {
    static let shared = RoutingService()
    
    private let logger = Logger(subsystem: "PhotoStop", category: "RoutingService")
    private let usageTracker = UsageTracker.shared
    private let resultCache = ResultCache.shared
    private let entitlementStore = EntitlementStore.shared
    
    // Provider instances (lazy loaded)
    private lazy var providers: [ImageEditProvider] = [
        OnDeviceProvider(),
        ClipdropProvider(),
        FalFluxProvider(),
        OpenAIImageProvider(),
        GeminiProvider()
    ]
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Route an edit request to the best available provider
    func routeEdit(_ request: EditRequest) async -> EditResult {
        logger.info("Routing edit request: \(request.prompt)")
        
        // Check cache first
        if let cachedResult = resultCache.get(request: request) {
            logger.info("Returning cached result")
            return cachedResult
        }
        
        // Classify the edit type
        let editType = classifyEdit(request.prompt)
        logger.info("Classified as: \(editType)")
        
        // Get routing decision with subscription gating
        let decision = await getRoutingDecisionWithGating(for: editType, tier: usageTracker.currentTier)
        logger.info("Routing decision: \(decision)")
        
        // Check if we need to present paywall
        if case .requiresUpgrade(let reason) = decision {
            return .requiresUpgrade(reason: reason)
        }
        
        // Execute the routing decision
        guard case .route(let providers) = decision else {
            return .failure(RoutingError.noProvidersAvailable)
        }
        
        let result = await executeRouting(providers: providers, request: request)
        
        // Cache successful results
        if case .success = result {
            resultCache.store(request: request, result: result)
        }
        
        return result
    }
    
    /// Get routing decision without executing (for UI preview)
    func getRoutingPreview(for prompt: String, tier: UserTier) async -> RoutingDecision {
        let editType = classifyEdit(prompt)
        return await getRoutingDecisionWithGating(for: editType, tier: tier)
    }
    
    /// Check if a specific edit type can be performed with current credits
    func canPerformEdit(_ editType: EditType, tier: UserTier) -> Bool {
        let costClass = getCostClass(for: editType, tier: tier)
        
        switch costClass {
        case .free:
            return true
        case .budget:
            return usageTracker.remaining(for: tier, cost: .budget) > 0
        case .premium:
            let subscriptionCredits = usageTracker.remaining(for: tier, cost: .premium)
            let addonCredits = entitlementStore.getAddonPremiumCredits()
            return (subscriptionCredits + addonCredits) > 0
        }
    }
    
    // MARK: - Routing Logic with Subscription Gating
    
    private func getRoutingDecisionWithGating(for editType: EditType, tier: UserTier) async -> RoutingDecision {
        let costClass = getCostClass(for: editType, tier: tier)
        
        // Check if user can perform this edit based on their tier and remaining credits
        let canPerform = checkCanPerformEdit(costClass: costClass, tier: tier)
        
        if case .requiresUpgrade(let reason) = canPerform {
            return .requiresUpgrade(reason: reason)
        }
        
        // Get available providers for this edit type and cost class
        let availableProviders = getAvailableProviders(for: editType, costClass: costClass, tier: tier)
        
        if availableProviders.isEmpty {
            return .noProvidersAvailable
        }
        
        return .route(availableProviders)
    }
    
    private func checkCanPerformEdit(costClass: CostClass, tier: UserTier) -> RoutingDecision {
        switch costClass {
        case .free:
            return .route([]) // Will be filled with actual providers
            
        case .budget:
            let remaining = usageTracker.remaining(for: tier, cost: .budget)
            if remaining <= 0 {
                let capacity = usageTracker.capacity(for: tier, cost: .budget)
                return .requiresUpgrade(reason: .insufficientBudgetCredits(required: 1, remaining: remaining))
            }
            return .route([])
            
        case .premium:
            let subscriptionCredits = usageTracker.remaining(for: tier, cost: .premium)
            let addonCredits = entitlementStore.getAddonPremiumCredits()
            let totalCredits = subscriptionCredits + addonCredits
            
            if totalCredits <= 0 {
                return .requiresUpgrade(reason: .insufficientPremiumCredits(required: 1, remaining: totalCredits))
            }
            return .route([])
        }
    }
    
    private func getAvailableProviders(for editType: EditType, costClass: CostClass, tier: UserTier) -> [ImageEditProvider] {
        var availableProviders: [ImageEditProvider] = []
        
        switch editType {
        case .enhancement:
            if costClass == .free {
                availableProviders.append(providers[0]) // OnDeviceProvider
            } else {
                availableProviders.append(contentsOf: [
                    providers[0], // OnDeviceProvider (fallback)
                    providers[2], // FalFluxProvider
                    providers[3]  // OpenAIImageProvider
                ])
                if costClass == .premium {
                    availableProviders.append(providers[4]) // GeminiProvider
                }
            }
            
        case .backgroundRemoval, .cleanup:
            availableProviders.append(providers[0]) // OnDeviceProvider
            if costClass != .free {
                availableProviders.append(providers[1]) // ClipdropProvider
            }
            
        case .creative, .style, .artistic:
            if costClass == .free {
                availableProviders.append(providers[0]) // OnDeviceProvider (limited)
            } else {
                availableProviders.append(contentsOf: [
                    providers[2], // FalFluxProvider
                    providers[3]  // OpenAIImageProvider
                ])
                if costClass == .premium {
                    availableProviders.append(providers[4]) // GeminiProvider
                }
            }
            
        case .advanced:
            // Advanced edits require premium
            if costClass == .premium {
                availableProviders.append(providers[4]) // GeminiProvider
            } else {
                // Return empty array, will trigger upgrade requirement
            }
        }
        
        return availableProviders
    }
    
    // MARK: - Execution
    
    private func executeRouting(providers: [ImageEditProvider], request: EditRequest) async -> EditResult {
        guard !providers.isEmpty else {
            return .failure(RoutingError.noProvidersAvailable)
        }
        
        // Try providers in order of preference
        for (index, provider) in providers.enumerated() {
            logger.info("Trying provider: \(type(of: provider))")
            
            // Check and consume credits before attempting
            let costClass = provider.costClass
            if !consumeCreditsIfNeeded(for: costClass) {
                logger.warning("Failed to consume credits for \(costClass)")
                continue
            }
            
            do {
                let result = try await provider.editImage(request)
                
                // Track successful usage
                usageTracker.recordUsage(
                    provider: String(describing: type(of: provider)),
                    cost: costClass,
                    success: true
                )
                
                logger.info("Successfully processed with \(type(of: provider))")
                return .success(
                    image: result.image,
                    provider: String(describing: type(of: provider)),
                    processingTime: result.processingTime,
                    metadata: result.metadata
                )
                
            } catch {
                logger.error("Provider \(type(of: provider)) failed: \(error)")
                
                // Refund credits on failure
                refundCreditsIfNeeded(for: costClass)
                
                // Track failed usage
                usageTracker.recordUsage(
                    provider: String(describing: type(of: provider)),
                    cost: costClass,
                    success: false
                )
                
                // If this was the last provider, return the error
                if index == providers.count - 1 {
                    return .failure(RoutingError.allProvidersFailed(lastError: error))
                }
                
                // Otherwise, continue to next provider
                continue
            }
        }
        
        return .failure(RoutingError.noProvidersAvailable)
    }
    
    // MARK: - Credit Management
    
    private func consumeCreditsIfNeeded(for costClass: CostClass) -> Bool {
        switch costClass {
        case .free:
            return true // No credits needed
            
        case .budget:
            return usageTracker.consumeCredit(for: usageTracker.currentTier, cost: .budget)
            
        case .premium:
            // Try addon credits first, then subscription credits
            if entitlementStore.consumeAddonPremiumCredit() {
                return true
            }
            return usageTracker.consumeCredit(for: usageTracker.currentTier, cost: .premium)
        }
    }
    
    private func refundCreditsIfNeeded(for costClass: CostClass) {
        switch costClass {
        case .free:
            break // No credits to refund
            
        case .budget:
            usageTracker.refundCredit(for: usageTracker.currentTier, cost: .budget)
            
        case .premium:
            // For simplicity, refund to subscription credits
            // In a real app, you'd track which type was consumed
            usageTracker.refundCredit(for: usageTracker.currentTier, cost: .premium)
        }
    }
    
    // MARK: - Edit Classification
    
    private func classifyEdit(_ prompt: String) -> EditType {
        let lowercased = prompt.lowercased()
        
        // Enhancement keywords
        if lowercased.contains("enhance") || lowercased.contains("improve") || 
           lowercased.contains("quality") || lowercased.contains("sharpen") ||
           lowercased.contains("brighten") || lowercased.contains("contrast") {
            return .enhancement
        }
        
        // Background removal keywords
        if lowercased.contains("background") || lowercased.contains("remove") ||
           lowercased.contains("cutout") || lowercased.contains("isolate") {
            return .backgroundRemoval
        }
        
        // Cleanup keywords
        if lowercased.contains("clean") || lowercased.contains("fix") ||
           lowercased.contains("repair") || lowercased.contains("restore") {
            return .cleanup
        }
        
        // Style keywords
        if lowercased.contains("style") || lowercased.contains("filter") ||
           lowercased.contains("vintage") || lowercased.contains("retro") {
            return .style
        }
        
        // Artistic keywords
        if lowercased.contains("artistic") || lowercased.contains("painting") ||
           lowercased.contains("sketch") || lowercased.contains("cartoon") ||
           lowercased.contains("anime") {
            return .artistic
        }
        
        // Creative keywords
        if lowercased.contains("creative") || lowercased.contains("fantasy") ||
           lowercased.contains("surreal") || lowercased.contains("transform") {
            return .creative
        }
        
        // Advanced keywords (complex operations)
        if lowercased.contains("complex") || lowercased.contains("advanced") ||
           lowercased.contains("professional") || lowercased.contains("detailed") {
            return .advanced
        }
        
        // Default to enhancement for simple prompts
        return .enhancement
    }
    
    private func getCostClass(for editType: EditType, tier: UserTier) -> CostClass {
        switch editType {
        case .enhancement:
            return tier == .free ? .budget : .budget
        case .backgroundRemoval, .cleanup:
            return .budget
        case .creative, .style, .artistic:
            return tier == .free ? .premium : .budget
        case .advanced:
            return .premium
        }
    }
}

// MARK: - Supporting Types

extension RoutingService {
    
    enum RoutingError: LocalizedError {
        case noProvidersAvailable
        case allProvidersFailed(lastError: Error)
        case creditConsumptionFailed
        case invalidRequest
        
        var errorDescription: String? {
            switch self {
            case .noProvidersAvailable:
                return "No AI providers are available for this edit"
            case .allProvidersFailed(let error):
                return "All AI providers failed. Last error: \(error.localizedDescription)"
            case .creditConsumptionFailed:
                return "Failed to consume credits for this operation"
            case .invalidRequest:
                return "The edit request is invalid"
            }
        }
    }
}

// MARK: - Edit Result Extensions

extension EditResult {
    /// Create a result that requires upgrade
    static func requiresUpgrade(reason: UpgradeReason) -> EditResult {
        return .requiresUpgrade(reason: reason)
    }
}

// MARK: - Usage Statistics

extension RoutingService {
    
    /// Get usage statistics for display
    func getUsageStatistics(for tier: UserTier) -> UsageStatistics {
        let budgetUsed = usageTracker.capacity(for: tier, cost: .budget) - usageTracker.remaining(for: tier, cost: .budget)
        let premiumUsed = usageTracker.capacity(for: tier, cost: .premium) - usageTracker.remaining(for: tier, cost: .premium)
        
        return UsageStatistics(
            tier: tier,
            budgetUsed: budgetUsed,
            budgetRemaining: usageTracker.remaining(for: tier, cost: .budget),
            budgetCapacity: usageTracker.capacity(for: tier, cost: .budget),
            premiumUsed: premiumUsed,
            premiumRemaining: usageTracker.remaining(for: tier, cost: .premium),
            premiumCapacity: usageTracker.capacity(for: tier, cost: .premium),
            addonPremiumCredits: entitlementStore.getAddonPremiumCredits()
        )
    }
}

struct UsageStatistics {
    let tier: UserTier
    let budgetUsed: Int
    let budgetRemaining: Int
    let budgetCapacity: Int
    let premiumUsed: Int
    let premiumRemaining: Int
    let premiumCapacity: Int
    let addonPremiumCredits: Int
    
    var totalPremiumCredits: Int {
        return premiumRemaining + addonPremiumCredits
    }
    
    var budgetUsagePercentage: Double {
        guard budgetCapacity > 0 else { return 0 }
        return Double(budgetUsed) / Double(budgetCapacity)
    }
    
    var premiumUsagePercentage: Double {
        guard premiumCapacity > 0 else { return 0 }
        return Double(premiumUsed) / Double(premiumCapacity)
    }
}

