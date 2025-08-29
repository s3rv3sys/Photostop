//
//  AnonymousId.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation

/// Service for managing anonymous user identifiers
enum AnonymousId {
    
    /// Keychain key for storing anonymous ID
    private static let key = "PHOTOSTOP_ANON_ID"
    
    /// Get existing anonymous ID or create new one
    static func getOrCreate() -> String {
        // Try to get existing ID from keychain
        if let existingId = KeychainService.shared.get(key) {
            return existingId
        }
        
        // Create new anonymous ID
        let newId = UUID().uuidString
        
        // Save to keychain
        let saved = KeychainService.shared.save(newId, forKey: key)
        
        if !saved {
            // Fallback to UserDefaults if keychain fails
            UserDefaults.standard.set(newId, forKey: key)
            return newId
        }
        
        return newId
    }
    
    /// Get current anonymous ID (if exists)
    static func getCurrent() -> String? {
        return KeychainService.shared.get(key) ?? UserDefaults.standard.string(forKey: key)
    }
    
    /// Delete anonymous ID (used when upgrading to signed-in)
    static func delete() {
        _ = KeychainService.shared.delete(key)
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// Generate new anonymous ID (for testing or reset)
    static func regenerate() -> String {
        delete()
        return getOrCreate()
    }
    
    /// Check if current session is anonymous
    static func isAnonymous() -> Bool {
        return getCurrent() != nil
    }
}

