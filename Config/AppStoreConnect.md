# App Store Connect Configuration Guide

This document provides the exact configuration needed for PhotoStop in App Store Connect.

## 📱 App Information

### **Basic Information**
- **App Name**: PhotoStop
- **Subtitle**: AI-Powered Photo Enhancement
- **Bundle ID**: `com.servesys.photostop`
- **SKU**: `photostop-ios-2024`
- **Primary Language**: English (U.S.)
- **Category**: Photo & Video
- **Secondary Category**: Graphics & Design

### **Age Rating**
- **Age Rating**: 12+
- **Reasons for 12+ Rating**:
  - Infrequent/Mild Mature/Suggestive Themes (user-generated content)
  - Users Can Post/Share Content (social media sharing)
  - Web Access (AI provider APIs)

### **App Privacy**
Configure the following data types in App Privacy section:

#### **Data Collected**
1. **Photos**
   - **Linked to User**: No
   - **Used for Tracking**: No
   - **Purpose**: App Functionality
   - **Description**: "Photos are processed locally and via secure AI services for enhancement. Images are immediately deleted from our servers after processing."

2. **Purchase History**
   - **Linked to User**: Yes
   - **Used for Tracking**: No
   - **Purpose**: App Functionality
   - **Description**: "Purchase history is used to manage subscription status and credit balances."

#### **Data Not Collected**
- Contact Info
- Health & Fitness
- Financial Info
- Location
- Sensitive Info
- Contacts
- User Content (beyond photos for processing)
- Search History
- Identifiers
- Usage Data
- Diagnostics

### **Export Compliance**
- **Uses Encryption**: Yes
- **Encryption Type**: Standard encryption APIs (HTTPS/TLS)
- **Exempt**: Yes (uses only standard encryption)
- **Documentation**: "App uses standard HTTPS/TLS encryption for secure communication with AI service providers."

## 💳 In-App Purchases

### **Subscription Group: PhotoStop Pro**

#### **1. Monthly Pro Subscription**
```
Product ID: com.servesys.photostop.pro.monthly
Reference Name: PhotoStop Pro Monthly
Type: Auto-Renewable Subscription
Subscription Group: PhotoStop Pro
Subscription Duration: 1 Month
Price: $9.99 USD
Free Trial: 7 Days
Introductory Offer: None
Family Sharing: Enabled
```

**Localized Information (English)**:
- **Display Name**: PhotoStop Pro
- **Description**: Unlock unlimited AI photo enhancement with 500 budget credits and 300 premium credits per month. Includes priority processing, advanced features, and high-resolution exports.

#### **2. Yearly Pro Subscription**
```
Product ID: com.servesys.photostop.pro.yearly
Reference Name: PhotoStop Pro Yearly
Type: Auto-Renewable Subscription
Subscription Group: PhotoStop Pro
Subscription Duration: 1 Year
Price: $79.99 USD (20% savings)
Free Trial: 7 Days
Introductory Offer: None
Family Sharing: Enabled
```

**Localized Information (English)**:
- **Display Name**: PhotoStop Pro (Yearly)
- **Description**: Get PhotoStop Pro with 20% savings! Includes 500 budget credits and 300 premium credits per month, priority processing, advanced features, and high-resolution exports.

### **Consumable Products**

#### **3. 10 Premium Credits**
```
Product ID: com.servesys.photostop.credits.premium10
Reference Name: 10 Premium Credits
Type: Consumable
Price: $2.99 USD
Family Sharing: Disabled
```

**Localized Information (English)**:
- **Display Name**: 10 Premium Credits
- **Description**: Add 10 premium AI credits to your account for advanced photo enhancements using our most powerful AI models.

#### **4. 50 Premium Credits**
```
Product ID: com.servesys.photostop.credits.premium50
Reference Name: 50 Premium Credits
Type: Consumable
Price: $9.99 USD
Family Sharing: Disabled
```

**Localized Information (English)**:
- **Display Name**: 50 Premium Credits
- **Description**: Add 50 premium AI credits to your account for advanced photo enhancements. Best value for power users!

### **Subscription Terms**
Add this to all subscription descriptions:

"Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Account will be charged for renewal within 24 hours prior to the end of the current period. Subscriptions may be managed by the user and auto-renewal may be turned off by going to the user's Account Settings after purchase. Any unused portion of a free trial period will be forfeited when the user purchases a subscription."

## 📝 App Description

### **App Store Description**
```
Transform your photos into stunning masterpieces with PhotoStop's advanced AI technology. Our intelligent routing system automatically selects the best AI provider for each enhancement, ensuring professional-quality results at the lowest cost.

✨ ONE-TAP AI ENHANCEMENT
• Smart burst capture with automatic frame selection
• Intelligent AI routing across 5 premium providers
• Professional-quality results in seconds
• Core ML-powered frame scoring

🎨 CREATIVE EDITING TOOLS
• 16 preset enhancement styles
• Custom prompt support
• Before/after comparison
• Unlimited undo/redo
• Edit history browser

💳 FLEXIBLE PRICING
• Free: 50 budget + 5 premium credits/month
• Pro: 500 budget + 300 premium credits/month
• 7-day free trial on subscriptions
• Additional credit packs available

📱 SOCIAL SHARING
• One-tap Instagram Stories sharing
• Direct TikTok integration
• Perfect aspect ratio optimization
• Attribution support

🔒 PRIVACY FIRST
• Local processing when possible
• Secure cloud AI with immediate deletion
• No data tracking or collection
• Your photos stay private

SUBSCRIPTION DETAILS:
• Free tier includes basic enhancements with on-device processing
• Pro subscription unlocks advanced AI providers and premium features
• Credits reset monthly
• Cancel anytime in Settings

PhotoStop uses cutting-edge AI from leading providers including Gemini, OpenAI, Clipdrop, and Fal.ai to deliver the best possible results for every type of photo enhancement.

Download PhotoStop today and discover the future of photo editing!
```

### **Keywords**
```
photo editor, AI photo, enhance photos, photo enhancement, camera app, photo filters, image editing, AI editing, photo effects, picture editor, photo retouching, smart camera, photo AI, image enhancer, photo studio
```

### **Promotional Text**
```
🎉 NEW: Smart AI routing automatically chooses the best enhancement method for your photos while minimizing costs. Try PhotoStop Pro free for 7 days!
```

## 📸 App Store Screenshots

### **Required Screenshot Sizes**
1. **6.7" Display (iPhone 15 Pro Max, 14 Pro Max, 13 Pro Max, 12 Pro Max)**
   - Size: 1290 x 2796 pixels
   - Format: PNG or JPEG

2. **6.1" Display (iPhone 15, 15 Pro, 14, 14 Pro, 13, 13 Pro, 12, 12 Pro)**
   - Size: 1179 x 2556 pixels
   - Format: PNG or JPEG

3. **5.5" Display (iPhone 8 Plus, 7 Plus, 6s Plus, 6 Plus)**
   - Size: 1242 x 2208 pixels
   - Format: PNG or JPEG

### **Screenshot Content Suggestions**
1. **Main Camera View**: Show live camera preview with capture button
2. **Enhancement in Progress**: Processing overlay with AI provider indication
3. **Before/After Comparison**: Split view showing original vs enhanced
4. **Subscription Paywall**: Beautiful Pro upgrade screen
5. **Social Sharing**: Instagram/TikTok sharing options
6. **Settings Screen**: API configuration and usage tracking

### **App Preview Video** (Optional but Recommended)
- **Duration**: 15-30 seconds
- **Content**: Quick demo of capture → enhance → share workflow
- **Format**: MP4 or MOV
- **Resolution**: Match screenshot dimensions

## 🔗 Support URLs

### **Required URLs**
You must create and host these pages before submission:

1. **Privacy Policy URL**: `https://servesys.com/photostop/privacy`
2. **Terms of Service URL**: `https://servesys.com/photostop/terms`
3. **Support URL**: `https://servesys.com/photostop/support`

### **Optional URLs**
4. **Marketing URL**: `https://servesys.com/photostop`
5. **App Store URL**: (Generated after approval)

## 📋 Review Information

### **App Review Information**
- **First Name**: Ishwar Prasad
- **Last Name**: Nagulapalle
- **Phone Number**: [Your Phone Number]
- **Email**: ishwar@servesys.com
- **Company**: Servesys Corporation
- **Address**: 240 OConnor Ridge Blvd Suite 100, Irving, TX 75028, United States

### **Demo Account** (if login required)
- **Username**: Not applicable (no login required)
- **Password**: Not applicable

### **Notes for Review Team**
```
PhotoStop is a photo enhancement app that uses AI to improve photo quality. Key points for review:

1. SUBSCRIPTIONS: Free tier provides basic functionality with on-device processing. Pro subscription unlocks advanced AI providers and additional credits.

2. API KEYS: The app requires API keys for AI providers (Gemini, OpenAI, Clipdrop, Fal.ai). Test keys are included in the build for review purposes.

3. SOCIAL SHARING: Instagram and TikTok sharing use official handoff methods - no direct posting. Users are redirected to the respective apps to complete sharing.

4. PRIVACY: Photos are processed temporarily by AI services and immediately deleted. No user data is collected or tracked.

5. CONTENT SAFETY: The app includes content filtering to prevent inappropriate prompts and maintains family-friendly operation.

6. OFFLINE MODE: Basic enhancement works offline using Core Image. Network is required for advanced AI features.

Please test the subscription flow, photo enhancement, and social sharing features. The app is designed to be intuitive and requires no special setup beyond granting camera and photos permissions.
```

## 🚀 Release Information

### **Version Information**
- **Version**: 2.0.0
- **Build**: 1
- **What's New in This Version**:
```
🎉 Major Update: Smart AI Routing & Pro Subscriptions

NEW FEATURES:
• Smart AI routing across 5 premium providers
• Flexible subscription plans with 7-day free trial
• One-tap Instagram and TikTok sharing
• 16 preset enhancement styles
• Advanced edit history with undo/redo

IMPROVEMENTS:
• Faster processing with intelligent provider selection
• Better image quality with specialized AI models
• Enhanced user interface with modern design
• Comprehensive privacy protection

Get PhotoStop Pro free for 7 days and unlock unlimited AI enhancement power!
```

### **Release Options**
- **Release Method**: Automatically release this version
- **Earliest Release Date**: Immediately after approval
- **Phased Release**: Enabled (recommended for major updates)

## 🔍 App Store Optimization

### **Localization** (Optional but Recommended)
Consider localizing for these markets:
- **Spanish (Mexico)**: Large iOS market
- **Spanish (Spain)**: European market
- **French (France)**: European market
- **German (Germany)**: European market
- **Japanese (Japan)**: High-value market

### **Pricing Strategy**
- **Free Tier**: Attracts users and demonstrates value
- **Pro Monthly**: $9.99 (competitive with photo editing apps)
- **Pro Yearly**: $79.99 (20% discount encourages annual commitment)
- **Credit Packs**: $2.99 and $9.99 (flexible top-up options)

### **Marketing Strategy**
- **Target Keywords**: Focus on "AI photo editor" and "photo enhancement"
- **ASO**: Optimize title, subtitle, and keywords for discovery
- **Social Proof**: Encourage reviews from beta testers
- **Content Marketing**: Create tutorials and before/after examples

---

**Important**: Ensure all URLs are live and functional before submitting for review. Apple will verify all links during the review process.

