//
//  RoutingService.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import os.log

/// Represents a routing decision made by the service
public struct RoutingDecision {
    public let provider: ImageEditProvider
    public let costClass: CostClass
    public let willConsumeCredit: Bool
    public let reason: String
    public let estimatedTime: TimeInterval
    public let alternatives: [ImageEditProvider]
    
    public init(
        provider: ImageEditProvider,
        costClass: CostClass,
        willConsumeCredit: Bool,
        reason: String,
        estimatedTime: TimeInterval = 0,
        alternatives: [ImageEditProvider] = []
    ) {
        self.provider = provider
        self.costClass = costClass
        self.willConsumeCredit = willConsumeCredit
        self.reason = reason
        self.estimatedTime = estimatedTime
        self.alternatives = alternatives
    }
}

/// Main routing service that orchestrates AI provider selection and execution
final class RoutingService: @unchecked Sendable {
    static let shared = RoutingService()
    
    private let logger = Logger(subsystem: "PhotoStop", category: "RoutingService")
    private let usageTracker = UsageTracker.shared
    private let resultCache = ResultCache.shared
    
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
    
    /// Main entry point for edit requests
    public func requestEdit(
        source: UIImage,
        prompt: String? = nil,
        requestedTask: EditTask? = nil,
        tier: Tier? = nil,
        targetSize: CGSize? = nil,
        allowWatermark: Bool = true,
        quality: Float = 0.8
    ) async throws -> ProviderResult {
        
        let userTier = tier ?? usageTracker.currentTier
        let task = classify(prompt: prompt, requestedTask: requestedTask)
        let options = EditOptions(
            prompt: prompt,
            targetSize: targetSize,
            allowWatermark: allowWatermark,
            quality: quality
        )
        
        logger.info("Edit request: task=\(task.rawValue), tier=\(userTier.rawValue)")
        
        // Check cache first
        let cacheKey = resultCache.key(
            for: source,
            prompt: prompt,
            provider: .onDevice, // Will be updated with actual provider
            task: task,
            options: options
        )
        
        if let cachedResult = resultCache.get(cacheKey) {
            logger.debug("Returning cached result")
            return ProviderResult(
                image: cachedResult.image,
                provider: cachedResult.provider,
                costClass: cachedResult.costClass,
                processingTime: cachedResult.processingTime,
                metadata: cachedResult.metadata.mapValues { $0 as Any }
            )
        }
        
        // Make routing decision
        let decision = route(task: task, tier: userTier)
        logger.info("Routing decision: \(decision.provider.id.rawValue) (\(decision.reason))")
        
        // Check if user has sufficient credits
        if decision.willConsumeCredit && !usageTracker.canPerform(decision.costClass, tier: userTier) {
            throw RoutingError.insufficientCredits(
                required: decision.costClass,
                remaining: usageTracker.remaining(for: userTier, cost: decision.costClass)
            )
        }
        
        // Execute the edit with fallback handling
        let result = try await executeWithFallback(
            provider: decision.provider,
            alternatives: decision.alternatives,
            image: source,
            task: task,
            options: options,
            tier: userTier
        )
        
        // Update usage tracking
        if decision.willConsumeCredit {
            usageTracker.increment(result.costClass)
        }
        
        // Cache the result
        let finalCacheKey = resultCache.key(
            for: source,
            prompt: prompt,
            provider: result.provider,
            task: task,
            options: options
        )
        resultCache.set(finalCacheKey, result: result)
        
        logger.info("Edit completed: provider=\(result.provider.rawValue), time=\(result.processingTime)s")
        return result
    }
    
    /// Get routing decision without executing
    public func getRoutingDecision(
        for task: EditTask,
        tier: Tier? = nil,
        imageSize: CGSize = CGSize(width: 1024, height: 1024)
    ) -> RoutingDecision {
        let userTier = tier ?? usageTracker.currentTier
        return route(task: task, tier: userTier, imageSize: imageSize)
    }
    
    /// Get available providers for a task
    public func getAvailableProviders(for task: EditTask) -> [ImageEditProvider] {
        return providers.filter { $0.supports(task) }
    }
    
    /// Validate all providers
    public func validateProviders() async -> [ProviderID: Bool] {
        var results: [ProviderID: Bool] = [:]
        
        await withTaskGroup(of: (ProviderID, Bool).self) { group in
            for provider in providers {
                group.addTask {
                    let isAvailable = await provider.isAvailable
                    return (provider.id, isAvailable)
                }
            }
            
            for await (id, isAvailable) in group {
                results[id] = isAvailable
            }
        }
        
        return results
    }
    
    // MARK: - Task Classification
    
    /// Classify user prompt into appropriate edit task
    public func classify(prompt: String?, requestedTask: EditTask?) -> EditTask {
        // If explicitly requested, use that
        if let task = requestedTask {
            return task
        }
        
        // Default to simple enhance if no prompt
        guard let prompt = prompt?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !prompt.isEmpty else {
            return .simpleEnhance
        }
        
        // Background removal keywords
        if prompt.contains("background") || prompt.contains("remove bg") || 
           prompt.contains("cut out") || prompt.contains("isolate subject") {
            return .bgRemove
        }
        
        // Cleanup keywords
        if prompt.contains("remove") || prompt.contains("cleanup") || 
           prompt.contains("erase") || prompt.contains("delete") ||
           prompt.contains("blemish") || prompt.contains("spot") {
            return .cleanup
        }
        
        // Subject consistency keywords
        if prompt.contains("consistent") || prompt.contains("same person") || 
           prompt.contains("same pet") || prompt.contains("maintain identity") ||
           prompt.contains("keep face") {
            return .subjectConsistency
        }
        
        // Multi-image fusion keywords
        if prompt.contains("merge") || prompt.contains("fuse") || 
           prompt.contains("hdr") || prompt.contains("combine") ||
           prompt.contains("blend") {
            return .multiImageFusion
        }
        
        // Style transfer keywords
        if prompt.contains("style") || prompt.contains("make it look like") || 
           prompt.contains("cartoon") || prompt.contains("painting") ||
           prompt.contains("artistic") || prompt.contains("filter") {
            return .restyle
        }
        
        // Local object edit keywords
        if prompt.contains("replace") || prompt.contains("change") || 
           prompt.contains("modify") || prompt.contains("add") ||
           prompt.contains("transform") {
            return .localObjectEdit
        }
        
        // Default to simple enhance
        return .simpleEnhance
    }
    
    // MARK: - Routing Logic
    
    private func route(
        task: EditTask,
        tier: Tier,
        imageSize: CGSize = CGSize(width: 1024, height: 1024)
    ) -> RoutingDecision {
        
        let availableProviders = getProvidersForTask(task)
        
        switch task {
        case .simpleEnhance:
            // Always prefer on-device for simple enhancement
            if let onDevice = availableProviders.first(where: { $0.id == .onDevice }) {
                return RoutingDecision(
                    provider: onDevice,
                    costClass: .freeLocal,
                    willConsumeCredit: false,
                    reason: "On-device enhancement (free)",
                    estimatedTime: onDevice.estimatedProcessingTime(for: task, imageSize: imageSize),
                    alternatives: Array(availableProviders.dropFirst())
                )
            }
            
        case .bgRemove, .cleanup:
            // Try on-device first if available
            if let onDevice = availableProviders.first(where: { $0.id == .onDevice }),
               onDevice.supports(task) {
                return RoutingDecision(
                    provider: onDevice,
                    costClass: .freeLocal,
                    willConsumeCredit: false,
                    reason: "On-device processing available",
                    estimatedTime: onDevice.estimatedProcessingTime(for: task, imageSize: imageSize),
                    alternatives: Array(availableProviders.dropFirst())
                )
            }
            
            // Fall back to budget providers
            if usageTracker.remaining(for: tier, cost: .budget) > 0,
               let clipdrop = availableProviders.first(where: { $0.id == .clipdrop }) {
                return RoutingDecision(
                    provider: clipdrop,
                    costClass: .budget,
                    willConsumeCredit: true,
                    reason: "Clipdrop for specialized \(task.description.lowercased())",
                    estimatedTime: clipdrop.estimatedProcessingTime(for: task, imageSize: imageSize),
                    alternatives: availableProviders.filter { $0.id != .clipdrop }
                )
            }
            
        case .restyle, .localObjectEdit:
            // Prefer budget providers for these tasks
            if usageTracker.remaining(for: tier, cost: .budget) > 0 {
                if let fal = availableProviders.first(where: { $0.id == .falFlux }) {
                    return RoutingDecision(
                        provider: fal,
                        costClass: .budget,
                        willConsumeCredit: true,
                        reason: "Fal.ai FLUX for creative editing",
                        estimatedTime: fal.estimatedProcessingTime(for: task, imageSize: imageSize),
                        alternatives: availableProviders.filter { $0.id != .falFlux }
                    )
                }
                
                if let openai = availableProviders.first(where: { $0.id == .openAI }) {
                    return RoutingDecision(
                        provider: openai,
                        costClass: .budget,
                        willConsumeCredit: true,
                        reason: "OpenAI for general editing",
                        estimatedTime: openai.estimatedProcessingTime(for: task, imageSize: imageSize),
                        alternatives: availableProviders.filter { $0.id != .openAI }
                    )
                }
            }
            
            // Fall back to premium if budget exhausted
            if usageTracker.remaining(for: tier, cost: .premium) > 0,
               let gemini = availableProviders.first(where: { $0.id == .gemini }) {
                return RoutingDecision(
                    provider: gemini,
                    costClass: .premium,
                    willConsumeCredit: true,
                    reason: "Premium Gemini fallback (budget exhausted)",
                    estimatedTime: gemini.estimatedProcessingTime(for: task, imageSize: imageSize),
                    alternatives: availableProviders.filter { $0.id != .gemini }
                )
            }
            
        case .subjectConsistency, .multiImageFusion:
            // These require premium providers
            if usageTracker.remaining(for: tier, cost: .premium) > 0,
               let gemini = availableProviders.first(where: { $0.id == .gemini }) {
                return RoutingDecision(
                    provider: gemini,
                    costClass: .premium,
                    willConsumeCredit: true,
                    reason: "Premium task requires Gemini 2.5 Flash",
                    estimatedTime: gemini.estimatedProcessingTime(for: task, imageSize: imageSize),
                    alternatives: availableProviders.filter { $0.id != .gemini }
                )
            }
            
            // Fall back to budget providers if premium exhausted
            if usageTracker.remaining(for: tier, cost: .budget) > 0,
               let openai = availableProviders.first(where: { $0.id == .openAI }) {
                return RoutingDecision(
                    provider: openai,
                    costClass: .budget,
                    willConsumeCredit: true,
                    reason: "Budget fallback for premium task",
                    estimatedTime: openai.estimatedProcessingTime(for: task, imageSize: imageSize),
                    alternatives: availableProviders.filter { $0.id != .openAI }
                )
            }
        }
        
        // Final fallback to on-device or first available provider
        if let onDevice = availableProviders.first(where: { $0.id == .onDevice }) {
            return RoutingDecision(
                provider: onDevice,
                costClass: .freeLocal,
                willConsumeCredit: false,
                reason: "Final fallback to on-device processing",
                estimatedTime: onDevice.estimatedProcessingTime(for: task, imageSize: imageSize),
                alternatives: Array(availableProviders.dropFirst())
            )
        }
        
        // If no providers available, return first one (will likely fail)
        let firstProvider = availableProviders.first ?? providers.first!
        return RoutingDecision(
            provider: firstProvider,
            costClass: firstProvider.costClass,
            willConsumeCredit: firstProvider.costClass != .freeLocal,
            reason: "No suitable providers available",
            estimatedTime: firstProvider.estimatedProcessingTime(for: task, imageSize: imageSize),
            alternatives: []
        )
    }
    
    // MARK: - Provider Management
    
    private func getProvidersForTask(_ task: EditTask) -> [ImageEditProvider] {
        let supportingProviders = providers.filter { $0.supports(task) }
        
        // Sort by preference: free -> budget -> premium
        return supportingProviders.sorted { lhs, rhs in
            if lhs.costClass.weight != rhs.costClass.weight {
                return lhs.costClass.weight < rhs.costClass.weight
            }
            // Secondary sort by provider preference
            return getProviderPriority(lhs.id) < getProviderPriority(rhs.id)
        }
    }
    
    private func getProviderPriority(_ id: ProviderID) -> Int {
        switch id {
        case .onDevice: return 0
        case .clipdrop: return 1
        case .falFlux: return 2
        case .openAI: return 3
        case .gemini: return 4
        }
    }
    
    // MARK: - Execution with Fallback
    
    private func executeWithFallback(
        provider: ImageEditProvider,
        alternatives: [ImageEditProvider],
        image: UIImage,
        task: EditTask,
        options: EditOptions,
        tier: Tier
    ) async throws -> ProviderResult {
        
        let startTime = Date()
        
        do {
            let result = try await provider.edit(image: image, task: task, options: options)
            let processingTime = Date().timeIntervalSince(startTime)
            
            return ProviderResult(
                image: result.image,
                provider: result.provider,
                costClass: result.costClass,
                processingTime: processingTime,
                metadata: result.metadata
            )
            
        } catch let error as ProviderError {
            logger.warning("Provider \(provider.id.rawValue) failed: \(error.localizedDescription)")
            
            // Try fallback providers
            for fallbackProvider in alternatives {
                // Check if we have credits for this fallback
                if fallbackProvider.costClass != .freeLocal &&
                   !usageTracker.canPerform(fallbackProvider.costClass, tier: tier) {
                    continue
                }
                
                do {
                    logger.info("Trying fallback provider: \(fallbackProvider.id.rawValue)")
                    let result = try await fallbackProvider.edit(image: image, task: task, options: options)
                    let processingTime = Date().timeIntervalSince(startTime)
                    
                    // Update usage for fallback provider
                    if fallbackProvider.costClass != .freeLocal {
                        usageTracker.increment(fallbackProvider.costClass)
                    }
                    
                    return ProviderResult(
                        image: result.image,
                        provider: result.provider,
                        costClass: result.costClass,
                        processingTime: processingTime,
                        metadata: result.metadata
                    )
                    
                } catch {
                    logger.warning("Fallback provider \(fallbackProvider.id.rawValue) also failed: \(error.localizedDescription)")
                    continue
                }
            }
            
            // All providers failed
            throw RoutingError.allProvidersFailed(originalError: error)
            
        } catch {
            throw RoutingError.unknownError(error)
        }
    }
}

// MARK: - Routing Errors

public enum RoutingError: Error, LocalizedError {
    case insufficientCredits(required: CostClass, remaining: Int)
    case allProvidersFailed(originalError: Error)
    case noProvidersAvailable
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .insufficientCredits(let required, let remaining):
            return "Insufficient \(required.description) credits. \(remaining) remaining."
        case .allProvidersFailed(let originalError):
            return "All providers failed. Original error: \(originalError.localizedDescription)"
        case .noProvidersAvailable:
            return "No providers available for this operation"
        case .unknownError(let error):
            return "Unknown routing error: \(error.localizedDescription)"
        }
    }
}

