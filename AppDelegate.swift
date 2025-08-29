//
//  AppDelegate.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import UIKit
import os.log

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "AppDelegate")
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.info("PhotoStop launching...")
        
        // Perform preflight checks
        Task {
            let preflightResult = await PreflightChecks.shared.performAllChecks()
            if !preflightResult.isSuccess {
                logger.error("Preflight checks failed with \(preflightResult.criticalIssues.count) critical issues")
                for issue in preflightResult.criticalIssues {
                    logger.error("Critical: \(issue.message)")
                }
            } else {
                logger.info("Preflight checks passed")
            }
        }
        
        // Configure app appearance
        configureAppearance()
        
        // Initialize core services
        initializeCoreServices()
        
        // Initialize memory manager
        _ = MemoryManager.shared
        
        // Check if this is first launch
        checkFirstLaunch()
        
        logger.info("PhotoStop launch completed")
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session
    }
    
    // MARK: - Private Methods
    
    /// Configure global app appearance
    private func configureAppearance() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor.systemBackground
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Set app tint color
        if let window = UIApplication.shared.windows.first {
            window.tintColor = UIColor.systemBlue
        }
        
        logger.info("App appearance configured")
    }
    
    /// Initialize core services
    private func initializeCoreServices() {
        // Initialize AuthService (this will set up anonymous user if needed)
        _ = AuthService.shared
        
        // Initialize PreferencesStore
        _ = PreferencesStore.shared
        
        // Initialize UsageTracker
        _ = UsageTracker.shared
        
        // Initialize other core services
        _ = KeychainService.shared
        
        logger.info("Core services initialized")
    }
    
    /// Check if this is the first app launch
    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "OnboardingCompleted")
        
        if !hasLaunchedBefore {
            logger.info("First app launch detected")
            
            // Mark as launched
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            UserDefaults.standard.set(false, forKey: "OnboardingCompleted")
            
            // Set up default preferences for new user
            setupDefaultPreferences()
            
        } else if !hasCompletedOnboarding {
            logger.info("App previously launched but onboarding not completed")
        } else {
            logger.info("Returning user launch")
        }
    }
    
    /// Set up default preferences for new users
    private func setupDefaultPreferences() {
        let authService = AuthService.shared
        let preferencesStore = PreferencesStore.shared
        
        // Load preferences for current user (anonymous)
        preferencesStore.load(for: authService.currentProfile().userId)
        
        // Apply default preferences
        let defaultPrefs = UserPreferences.defaultPreferences()
        preferencesStore.prefs = defaultPrefs
        preferencesStore.save()
        
        logger.info("Default preferences set up for new user")
    }
}

// MARK: - App State Management

extension AppDelegate {
    
    /// Handle app becoming active
    func applicationDidBecomeActive(_ application: UIApplication) {
        logger.info("App became active")
        
        // Update last seen timestamp
        let authService = AuthService.shared
        Task {
            await authService.updateProfile(
                displayName: authService.currentProfile().displayName,
                email: authService.currentProfile().email
            )
        }
        
        // Refresh usage tracking
        UsageTracker.shared.ensureMonthBoundary()
    }
    
    /// Handle app entering background
    func applicationDidEnterBackground(_ application: UIApplication) {
        logger.info("App entered background")
        
        // Save current preferences
        PreferencesStore.shared.save()
        
        // Save usage tracking data
        UsageTracker.shared.save()
    }
    
    /// Handle app termination
    func applicationWillTerminate(_ application: UIApplication) {
        logger.info("App will terminate")
        
        // Final save of all data
        PreferencesStore.shared.save()
        UsageTracker.shared.save()
    }
}

// MARK: - URL Handling

extension AppDelegate {
    
    /// Handle URL schemes (for social sharing callbacks)
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        logger.info("Handling URL: \(url.absoluteString)")
        
        // Handle Instagram callback
        if url.scheme == "photostop" && url.host == "instagram" {
            logger.info("Instagram callback received")
            NotificationCenter.default.post(name: .instagramShareCompleted, object: url)
            return true
        }
        
        // Handle TikTok callback
        if url.scheme == "photostop" && url.host == "tiktok" {
            logger.info("TikTok callback received")
            NotificationCenter.default.post(name: .tiktokShareCompleted, object: url)
            return true
        }
        
        return false
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let instagramShareCompleted = Notification.Name("InstagramShareCompleted")
    static let tiktokShareCompleted = Notification.Name("TikTokShareCompleted")
}

