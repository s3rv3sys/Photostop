//
//  LocalizationHelper.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation

/// Helper for managing localized strings throughout the app
final class LocalizationHelper {
    
    /// Get localized string with optional formatting
    static func string(for key: String, arguments: CVarArg...) -> String {
        let localizedString = NSLocalizedString(key, comment: "")
        
        if arguments.isEmpty {
            return localizedString
        } else {
            return String(format: localizedString, arguments: arguments)
        }
    }
    
    /// Get localized string with fallback
    static func string(for key: String, fallback: String, arguments: CVarArg...) -> String {
        let localizedString = NSLocalizedString(key, value: fallback, comment: "")
        
        if arguments.isEmpty {
            return localizedString
        } else {
            return String(format: localizedString, arguments: arguments)
        }
    }
}

// MARK: - Convenience Extensions

extension String {
    /// Get localized version of this string
    var localized: String {
        return LocalizationHelper.string(for: self)
    }
    
    /// Get localized version with arguments
    func localized(arguments: CVarArg...) -> String {
        return LocalizationHelper.string(for: self, arguments: arguments)
    }
}

// MARK: - Localized String Constants

/// Centralized localized strings for type safety
struct L10n {
    
    // MARK: - App
    struct App {
        static let name = "app_name".localized
        static let tagline = "app_tagline".localized
        static let description = "app_description".localized
    }
    
    // MARK: - Onboarding
    struct Onboarding {
        static let welcomeTitle = "onboarding_welcome_title".localized
        static let welcomeSubtitle = "onboarding_welcome_subtitle".localized
        static let welcomeDescription = "onboarding_welcome_description".localized
        
        static let personalizationTitle = "onboarding_personalization_title".localized
        static let personalizationSubtitle = "onboarding_personalization_subtitle".localized
        static let personalizationDescription = "onboarding_personalization_description".localized
        
        static let sharingTitle = "onboarding_sharing_title".localized
        static let sharingSubtitle = "onboarding_sharing_subtitle".localized
        static let sharingDescription = "onboarding_sharing_description".localized
        
        static let plansTitle = "onboarding_plans_title".localized
        static let plansSubtitle = "onboarding_plans_subtitle".localized
        static let plansDescription = "onboarding_plans_description".localized
        
        static let continueButton = "onboarding_continue".localized
        static let skipButton = "onboarding_skip".localized
        static let getStartedButton = "onboarding_get_started".localized
    }
    
    // MARK: - Authentication
    struct Auth {
        static let signInTitle = "auth_sign_in_title".localized
        static let signInSubtitle = "auth_sign_in_subtitle".localized
        static let signInApple = "auth_sign_in_apple".localized
        static let signInEmail = "auth_sign_in_email".localized
        static let continueAnonymous = "auth_continue_anonymous".localized
        static let benefitsTitle = "auth_benefits_title".localized
        static let benefitsSync = "auth_benefits_sync".localized
        static let benefitsBackup = "auth_benefits_backup".localized
        static let benefitsPersonalization = "auth_benefits_personalization".localized
    }
    
    // MARK: - Camera
    struct Camera {
        static let title = "camera_title".localized
        static let capture = "camera_capture".localized
        static let processing = "camera_processing".localized
        static let flashOn = "camera_flash_on".localized
        static let flashOff = "camera_flash_off".localized
        static let switchCamera = "camera_switch_camera".localized
        static let permissionTitle = "camera_permission_title".localized
        static let permissionMessage = "camera_permission_message".localized
        static let permissionSettings = "camera_permission_settings".localized
    }
    
    // MARK: - Processing
    struct Processing {
        static let analyzing = "processing_analyzing".localized
        static let enhancing = "processing_enhancing".localized
        static let finalizing = "processing_finalizing".localized
        static let complete = "processing_complete".localized
        static let cancel = "processing_cancel".localized
    }
    
    // MARK: - Results
    struct Result {
        static let title = "result_title".localized
        static let save = "result_save".localized
        static let share = "result_share".localized
        static let editMore = "result_edit_more".localized
        static let tryAgain = "result_try_again".localized
        static let before = "result_before".localized
        static let after = "result_after".localized
        static let tapToCompare = "result_tap_to_compare".localized
        
        static func enhancedBy(_ provider: String) -> String {
            return "result_enhanced_by".localized(arguments: provider)
        }
    }
    
    // MARK: - Gallery
    struct Gallery {
        static let title = "gallery_title".localized
        static let emptyTitle = "gallery_empty_title".localized
        static let emptyMessage = "gallery_empty_message".localized
        static let search = "gallery_search".localized
        static let select = "gallery_select".localized
        static let delete = "gallery_delete".localized
        static let share = "gallery_share".localized
    }
    
    // MARK: - Profile
    struct Profile {
        static let title = "profile_title".localized
        static let anonymous = "profile_anonymous".localized
        static let signIn = "profile_sign_in".localized
        static let signOut = "profile_sign_out".localized
        static let deleteAccount = "profile_delete_account".localized
        static let subscription = "profile_subscription".localized
        static let usage = "profile_usage".localized
        static let preferences = "profile_preferences".localized
    }
    
    // MARK: - Settings
    struct Settings {
        static let title = "settings_title".localized
        static let account = "settings_account".localized
        static let subscription = "settings_subscription".localized
        static let personalization = "settings_personalization".localized
        static let sharing = "settings_sharing".localized
        static let privacy = "settings_privacy".localized
        static let camera = "settings_camera".localized
        static let about = "settings_about".localized
        
        static let watermark = "settings_watermark".localized
        static let watermarkDescription = "settings_watermark_description".localized
        static let attribution = "settings_attribution".localized
        static let attributionDescription = "settings_attribution_description".localized
        
        static let privacyPolicy = "settings_privacy_policy".localized
        static let termsOfService = "settings_terms_of_service".localized
        static let contactSupport = "settings_contact_support".localized
    }
    
    // MARK: - Subscription
    struct Subscription {
        static let title = "subscription_title".localized
        static let freeTrial = "subscription_free_trial".localized
        static let monthly = "subscription_monthly".localized
        static let yearly = "subscription_yearly".localized
        static let restore = "subscription_restore".localized
        static let manage = "subscription_manage".localized
        
        static let freeTitle = "subscription_free_title".localized
        static let freeCredits = "subscription_free_credits".localized
        static let proTitle = "subscription_pro_title".localized
        static let proCredits = "subscription_pro_credits".localized
        
        static let featureUnlimited = "subscription_feature_unlimited".localized
        static let featurePremium = "subscription_feature_premium".localized
        static let featurePriority = "subscription_feature_priority".localized
        static let featureAdvanced = "subscription_feature_advanced".localized
        
        static func savePercent(_ percent: Int) -> String {
            return "subscription_save_percent".localized(arguments: percent)
        }
    }
    
    // MARK: - Credits
    struct Credits {
        static let title = "credits_title".localized
        static let budget = "credits_budget".localized
        static let premium = "credits_premium".localized
        static let buyMore = "credits_buy_more".localized
        static let upgrade = "credits_upgrade".localized
        
        static func remaining(_ count: Int) -> String {
            return "credits_remaining".localized(arguments: count)
        }
        
        static func resets(_ date: String) -> String {
            return "credits_resets".localized(arguments: date)
        }
    }
    
    // MARK: - Sharing
    struct Share {
        static let instagramStories = "share_instagram_stories".localized
        static let tiktok = "share_tiktok".localized
        static let more = "share_more".localized
        static let copyImage = "share_copy_image".localized
        static let saveToPhotos = "share_save_to_photos".localized
        static let aiDisclosure = "share_ai_disclosure".localized
    }
    
    // MARK: - Errors
    struct Error {
        static let title = "error_title".localized
        static let generic = "error_generic".localized
        static let network = "error_network".localized
        static let cameraUnavailable = "error_camera_unavailable".localized
        static let photoSaveFailed = "error_photo_save_failed".localized
        static let aiProcessingFailed = "error_ai_processing_failed".localized
        static let subscriptionFailed = "error_subscription_failed".localized
        static let insufficientCredits = "error_insufficient_credits".localized
        
        static let retry = "error_retry".localized
        static let dismiss = "error_dismiss".localized
        static let upgrade = "error_upgrade".localized
        static let buyCredits = "error_buy_credits".localized
    }
    
    // MARK: - Permissions
    struct Permission {
        static let cameraTitle = "permission_camera_title".localized
        static let cameraMessage = "permission_camera_message".localized
        static let photosTitle = "permission_photos_title".localized
        static let photosMessage = "permission_photos_message".localized
        static let allow = "permission_allow".localized
        static let notNow = "permission_not_now".localized
    }
    
    // MARK: - Success Messages
    struct Success {
        static let photoSaved = "success_photo_saved".localized
        static let photoShared = "success_photo_shared".localized
        static let subscriptionActivated = "success_subscription_activated".localized
        static let creditsPurchased = "success_credits_purchased".localized
    }
    
    // MARK: - Loading States
    struct Loading {
        static let pleaseWait = "loading_please_wait".localized
        static let processingImage = "loading_processing_image".localized
        static let savingPhoto = "loading_saving_photo".localized
        static let sharingPhoto = "loading_sharing_photo".localized
    }
    
    // MARK: - About
    struct About {
        static func version(_ version: String) -> String {
            return "about_version".localized(arguments: version)
        }
        
        static func build(_ build: String) -> String {
            return "about_build".localized(arguments: build)
        }
        
        static let copyright = "about_copyright".localized
        static let madeWithLove = "about_made_with_love".localized
    }
}

