//
//  StoreKitProducts.swift
//  PhotoStop
//
//  Updated with Servesys Corporation product IDs
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import StoreKit

/// StoreKit product configuration for PhotoStop
/// All product IDs must match exactly with App Store Connect configuration
struct StoreKitProducts {
    
    // MARK: - Product IDs
    
    /// Subscription product IDs for PhotoStop Pro
    enum SubscriptionProductID: String, CaseIterable {
        case monthlyPro = "com.servesys.photostop.pro.monthly"
        case yearlyPro = "com.servesys.photostop.pro.yearly"
        
        var displayName: String {
            switch self {
            case .monthlyPro:
                return "PhotoStop Pro (Monthly)"
            case .yearlyPro:
                return "PhotoStop Pro (Yearly)"
            }
        }
        
        var description: String {
            switch self {
            case .monthlyPro:
                return "Unlock unlimited AI photo enhancement with 500 budget credits and 300 premium credits per month."
            case .yearlyPro:
                return "Get PhotoStop Pro with 20% savings! Includes 500 budget credits and 300 premium credits per month."
            }
        }
        
        var duration: String {
            switch self {
            case .monthlyPro:
                return "1 Month"
            case .yearlyPro:
                return "1 Year"
            }
        }
        
        var hasFreeTrial: Bool {
            return true // Both subscriptions offer 7-day free trial
        }
        
        var trialDuration: String {
            return "7 Days"
        }
    }
    
    /// Consumable product IDs for premium credits
    enum ConsumableProductID: String, CaseIterable {
        case premiumCredits10 = "com.servesys.photostop.credits.premium10"
        case premiumCredits50 = "com.servesys.photostop.credits.premium50"
        
        var displayName: String {
            switch self {
            case .premiumCredits10:
                return "10 Premium Credits"
            case .premiumCredits50:
                return "50 Premium Credits"
            }
        }
        
        var description: String {
            switch self {
            case .premiumCredits10:
                return "Add 10 premium AI credits to your account for advanced photo enhancements."
            case .premiumCredits50:
                return "Add 50 premium AI credits to your account. Best value for power users!"
            }
        }
        
        var creditAmount: Int {
            switch self {
            case .premiumCredits10:
                return 10
            case .premiumCredits50:
                return 50
            }
        }
        
        var isPopular: Bool {
            switch self {
            case .premiumCredits10:
                return false
            case .premiumCredits50:
                return true // Mark as "Best Value"
            }
        }
    }
    
    // MARK: - All Product IDs
    
    /// All product IDs for easy iteration
    static var allProductIDs: [String] {
        return SubscriptionProductID.allCases.map { $0.rawValue } +
               ConsumableProductID.allCases.map { $0.rawValue }
    }
    
    /// Subscription group identifier
    static let subscriptionGroupID = "PhotoStop Pro"
    
    // MARK: - Product Information
    
    /// Get product information by ID
    static func productInfo(for productID: String) -> (name: String, description: String)? {
        if let subscription = SubscriptionProductID(rawValue: productID) {
            return (subscription.displayName, subscription.description)
        }
        
        if let consumable = ConsumableProductID(rawValue: productID) {
            return (consumable.displayName, consumable.description)
        }
        
        return nil
    }
    
    /// Check if product ID is a subscription
    static func isSubscription(_ productID: String) -> Bool {
        return SubscriptionProductID(rawValue: productID) != nil
    }
    
    /// Check if product ID is a consumable
    static func isConsumable(_ productID: String) -> Bool {
        return ConsumableProductID(rawValue: productID) != nil
    }
    
    /// Get credit amount for consumable products
    static func creditAmount(for productID: String) -> Int? {
        guard let consumable = ConsumableProductID(rawValue: productID) else {
            return nil
        }
        return consumable.creditAmount
    }
}

// MARK: - StoreKit Configuration Validation

extension StoreKitProducts {
    
    /// Validate that all product IDs are properly formatted
    static func validateProductIDs() -> [String] {
        var errors: [String] = []
        
        // Check bundle ID prefix
        let expectedPrefix = "com.servesys.photostop"
        
        for productID in allProductIDs {
            if !productID.hasPrefix(expectedPrefix) {
                errors.append("Product ID '\(productID)' does not have expected prefix '\(expectedPrefix)'")
            }
            
            if productID.contains(" ") {
                errors.append("Product ID '\(productID)' contains spaces")
            }
            
            if productID != productID.lowercased() {
                errors.append("Product ID '\(productID)' contains uppercase characters")
            }
        }
        
        return errors
    }
    
    /// Print product configuration for App Store Connect setup
    static func printConfiguration() {
        print("=== PhotoStop StoreKit Configuration ===")
        print("Company: Servesys Corporation")
        print("Bundle ID Prefix: com.servesys.photostop")
        print("")
        
        print("SUBSCRIPTION PRODUCTS:")
        for subscription in SubscriptionProductID.allCases {
            print("- Product ID: \(subscription.rawValue)")
            print("  Name: \(subscription.displayName)")
            print("  Duration: \(subscription.duration)")
            print("  Free Trial: \(subscription.trialDuration)")
            print("  Description: \(subscription.description)")
            print("")
        }
        
        print("CONSUMABLE PRODUCTS:")
        for consumable in ConsumableProductID.allCases {
            print("- Product ID: \(consumable.rawValue)")
            print("  Name: \(consumable.displayName)")
            print("  Credits: \(consumable.creditAmount)")
            print("  Popular: \(consumable.isPopular ? "Yes" : "No")")
            print("  Description: \(consumable.description)")
            print("")
        }
        
        let validationErrors = validateProductIDs()
        if validationErrors.isEmpty {
            print("✅ All product IDs are valid")
        } else {
            print("❌ Validation errors:")
            for error in validationErrors {
                print("  - \(error)")
            }
        }
    }
}

// MARK: - Usage Example

/*
 Usage in StoreKitService:
 
 // Load products
 let productIDs = Set(StoreKitProducts.allProductIDs)
 let products = try await Product.products(for: productIDs)
 
 // Check product type
 if StoreKitProducts.isSubscription(productID) {
     // Handle subscription
 } else if StoreKitProducts.isConsumable(productID) {
     // Handle consumable
     let credits = StoreKitProducts.creditAmount(for: productID)
 }
 
 // Get product info
 if let info = StoreKitProducts.productInfo(for: productID) {
     print("Product: \(info.name) - \(info.description)")
 }
 */

