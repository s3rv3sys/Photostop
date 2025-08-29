# PhotoStop - AI-Powered Photo Enhancement App

**Version 2.0** - Enhanced with Smart AI Routing & Subscription System

PhotoStop is a cutting-edge iOS app that transforms ordinary photos into stunning masterpieces using advanced AI technology. With intelligent provider routing, cost optimization, and seamless social sharing, PhotoStop delivers professional-quality photo enhancement in just one tap.

## 🌟 Key Features

### 🎯 **One-Tap AI Enhancement**
- **Smart Burst Capture**: Automatically captures multiple frames with exposure bracketing
- **Intelligent Frame Selection**: Core ML-powered scoring to select the best frame
- **AI Enhancement**: Advanced AI processing with multiple provider options
- **Instant Results**: Professional-quality enhancements in seconds

### 🧠 **Smart AI Routing System**
- **Cost Optimization**: Automatically routes to the most cost-effective provider
- **Multi-Provider Support**: 5 AI providers with different strengths and costs
- **Intelligent Fallback**: Graceful degradation when providers are unavailable
- **Quality Assurance**: Best-in-class results through provider specialization

### 💳 **Flexible Subscription System**
- **Free Tier**: 50 budget + 5 premium AI credits per month
- **Pro Subscription**: 500 budget + 300 premium credits per month
- **Consumable Credits**: 10 or 50 premium credit top-ups available
- **7-Day Free Trial**: Risk-free trial on monthly subscriptions

### 📱 **One-Tap Social Sharing**
- **Instagram Integration**: Direct sharing to Stories with attribution
- **TikTok Integration**: Seamless sharing with pre-filled captions
- **Smart Platform Detection**: Auto-hide unavailable platforms
- **Aspect Ratio Optimization**: Perfect sizing for each platform

### 🎨 **Advanced Editing Features**
- **16 Preset Prompts**: Artistic, Enhancement, Style, Creative, and Cleanup categories
- **Custom Prompts**: Create your own enhancement descriptions
- **Before/After Comparison**: Tap to toggle between original and enhanced
- **Edit History**: Browse and manage your enhancement history
- **Undo/Redo**: Full edit history with unlimited undo

## 🏗 Architecture Overview

PhotoStop is built using modern iOS development patterns and best practices:

### **MVVM Architecture**
```
Models/
├── EditedImage.swift          # Core image data model
├── EditPrompt.swift           # Prompt and enhancement data
└── FrameScore.swift           # ML scoring results

Services/
├── CameraService.swift        # AVFoundation camera integration
├── AIService.swift            # Legacy AI service (deprecated)
├── StorageService.swift       # Photos and local storage
├── FrameScoringService.swift  # Core ML frame analysis
├── KeychainService.swift      # Secure API key storage
├── Routing/                   # Smart AI routing system
│   ├── RoutingService.swift   # Main routing orchestrator
│   ├── UsageTracker.swift     # Credit tracking and limits
│   ├── ResultCache.swift      # Performance optimization
│   └── Providers/             # AI provider implementations
├── Payments/                  # Subscription system
│   ├── StoreKitService.swift  # StoreKit 2 integration
│   ├── Entitlements.swift     # User tier management
│   └── SubscriptionViewModel.swift # Paywall logic
└── Social/                    # Social media integration
    └── SocialShareService.swift # Instagram & TikTok sharing

ViewModels/
├── CameraViewModel.swift      # Camera and capture logic
├── EditViewModel.swift        # Enhancement and editing
└── SettingsViewModel.swift    # App configuration

Views/
├── CameraView.swift           # Live camera interface
├── ResultView.swift           # Enhanced image display
├── SettingsView.swift         # App settings and preferences
├── GalleryView.swift          # Edit history browser
└── Subscription/              # Subscription UI
    ├── PaywallView.swift      # Beautiful subscription screen
    ├── ManageSubscriptionView.swift # Subscription management
    └── CreditsShopView.swift  # Consumable credit purchases
```

### **Smart AI Routing System**

PhotoStop's routing system intelligently selects the best AI provider for each task:

#### **Provider Hierarchy**
1. **OnDevice (Free)**: Core Image + Vision framework for basic enhancements
2. **Clipdrop (Budget)**: Specialized background removal and cleanup
3. **Fal.ai FLUX (Budget)**: Fast creative transformations and styling
4. **OpenAI DALL-E (Budget)**: General-purpose image editing and variations
5. **Gemini 2.5 Flash Image (Premium)**: Advanced multi-modal AI for complex tasks

#### **Routing Logic**
```swift
// Edit Classification → Cost Class → Provider Selection
Enhancement → Budget → OnDevice → Fal.ai → OpenAI → Gemini
Background Removal → Budget → OnDevice → Clipdrop
Creative/Style → Budget/Premium → Fal.ai → OpenAI → Gemini
Advanced Tasks → Premium → Gemini → Budget Fallback
```

#### **Credit Management**
- **Free Tier**: 50 budget + 5 premium credits/month
- **Pro Tier**: 500 budget + 300 premium credits/month
- **Addon Credits**: Consumable premium credits (10 or 50 packs)
- **Smart Gating**: Automatic paywall presentation when credits insufficient

## 🚀 Getting Started

### **Prerequisites**
- Xcode 15.0 or later
- iOS 17.0 or later
- Apple Developer Account (for device testing)
- API Keys for AI providers (see Configuration section)

### **Installation**

1. **Clone or Download** the PhotoStop project
2. **Open** `PhotoStop.xcodeproj` in Xcode
3. **Configure** your Apple Developer Team in project settings
4. **Add API Keys** (see Configuration section below)
5. **Build and Run** on device or simulator

### **Configuration**

#### **API Keys Setup**
PhotoStop requires API keys for AI providers. Add them through the Settings screen or configure programmatically:

```swift
// Required API Keys
KeychainService.shared.save("your-gemini-api-key", forKey: "gemini_api_key")
KeychainService.shared.save("your-openai-api-key", forKey: "openai_api_key")
KeychainService.shared.save("your-clipdrop-api-key", forKey: "clipdrop_api_key")
KeychainService.shared.save("your-fal-api-key", forKey: "fal_api_key")
```

#### **StoreKit Configuration**
1. **Configure** your App Store Connect products:
   - `com.photostop.pro.monthly` - Monthly Pro subscription
   - `com.photostop.pro.yearly` - Yearly Pro subscription  
   - `com.photostop.credits.premium10` - 10 Premium Credits
   - `com.photostop.credits.premium50` - 50 Premium Credits

2. **Update** `PhotoStop.storekit` configuration file with your product IDs
3. **Enable** StoreKit testing in Xcode scheme settings

#### **Social Media Integration**
Add URL schemes to `Info.plist` for social sharing:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>instagram</string>
    <string>instagram-stories</string>
    <string>tiktok</string>
    <string>snssdk1233</string>
</array>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>PhotoStop</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>photostop</string>
        </array>
    </dict>
</array>
```

## 🎯 Usage Guide

### **Basic Photo Enhancement**
1. **Launch** PhotoStop and grant camera permissions
2. **Tap** the capture button for one-tap enhancement
3. **View** your enhanced photo with before/after comparison
4. **Save** to Photos or share to social media

### **Custom Editing**
1. **Capture** or select a photo
2. **Choose** from 16 preset prompts or create custom prompt
3. **Wait** for AI processing (2-10 seconds depending on provider)
4. **Compare** results and save your favorite

### **Subscription Management**
1. **Tap** "Go Pro" when credits are low
2. **Choose** monthly or yearly subscription (7-day free trial)
3. **Purchase** additional credits as needed
4. **Manage** subscription through Settings → Manage Subscription

### **Social Sharing**
1. **Enhance** your photo
2. **Tap** Instagram or TikTok sharing buttons
3. **Confirm** sharing with pre-filled captions
4. **Post** directly to your social media

## 🧪 Testing

PhotoStop includes comprehensive test coverage for all critical systems:

### **Running Tests**
```bash
# Run all tests
⌘ + U in Xcode

# Run specific test suites
xcodebuild test -scheme PhotoStop -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### **Test Coverage**
- **RoutingServiceTests**: AI provider selection and credit management
- **StoreKitServiceTests**: Subscription and purchase flow testing
- **SubscriptionViewModelTests**: Paywall logic and presentation
- **EntitlementsTests**: User tier and feature availability
- **CameraServiceTests**: Camera capture and frame scoring
- **AIServiceTests**: Legacy AI service compatibility
- **StorageServiceTests**: Photos integration and local storage
- **FrameScoringTests**: Core ML model integration

### **Mock Testing**
All services include comprehensive mock implementations for reliable testing:
- **MockUsageTracker**: Credit simulation
- **MockStoreKitService**: Purchase flow simulation
- **MockEntitlementStore**: Subscription simulation
- **MockResultCache**: Caching behavior simulation

## 📊 Performance & Optimization

### **Smart Caching**
- **Result Cache**: SHA256-based caching prevents duplicate API calls
- **Memory Management**: Automatic cleanup of large image data
- **Disk Storage**: Persistent cache with configurable size limits

### **Credit Optimization**
- **Provider Selection**: Always chooses most cost-effective option first
- **Fallback Logic**: Graceful degradation maintains functionality
- **Usage Tracking**: Real-time monitoring prevents overage

### **Image Processing**
- **Automatic Resizing**: Optimizes images for each AI provider's requirements
- **Format Conversion**: Handles HEIC, JPEG, PNG with quality preservation
- **Memory Efficiency**: Streams large images to prevent memory issues

## 🔒 Privacy & Security

### **Data Protection**
- **Local Processing**: On-device enhancement when possible
- **Secure Storage**: API keys stored in iOS Keychain
- **No Data Collection**: Photos never stored on external servers
- **Temporary Processing**: Images deleted from AI providers after processing

### **Permissions**
- **Camera**: Required for photo capture
- **Photos**: Required for saving enhanced images
- **Network**: Required for AI provider communication

### **API Key Security**
```swift
// Secure API key storage
KeychainService.shared.save(apiKey, forKey: "provider_api_key")

// Automatic key rotation support
if KeychainService.shared.get("provider_api_key") == nil {
    // Prompt user to add API key
}
```

## 🛠 Development

### **Adding New AI Providers**
1. **Implement** `ImageEditProvider` protocol
2. **Add** provider to `RoutingService.providers` array
3. **Configure** cost class and supported edit types
4. **Add** API key management to `KeychainService`
5. **Update** routing logic in `getAvailableProviders`

### **Custom Edit Types**
1. **Add** new case to `EditType` enum
2. **Update** `classifyEdit` method with keywords
3. **Configure** provider support in routing logic
4. **Add** preset prompts to `EditViewModel`

### **Subscription Products**
1. **Add** product ID to `StoreKitService.ProductID` enum
2. **Update** `PhotoStop.storekit` configuration
3. **Configure** entitlements in `Entitlements.swift`
4. **Update** paywall UI in `PaywallView.swift`

## 📱 Deployment

### **App Store Preparation**
1. **Configure** App Store Connect with subscription products
2. **Upload** app icon assets (included in project)
3. **Set** pricing and availability for subscriptions
4. **Configure** StoreKit testing for review team
5. **Submit** for App Store review

### **TestFlight Distribution**
1. **Archive** the app in Xcode
2. **Upload** to App Store Connect
3. **Configure** TestFlight testing groups
4. **Distribute** to beta testers

### **Production Considerations**
- **API Rate Limits**: Monitor usage across all providers
- **Cost Management**: Set up billing alerts for AI provider costs
- **Performance Monitoring**: Use Xcode Instruments for optimization
- **Crash Reporting**: Integrate crash analytics service

## 🤝 Contributing

PhotoStop is designed for extensibility and welcomes contributions:

### **Code Style**
- **Swift 5.9+** with modern concurrency (async/await)
- **SwiftUI** for all user interface components
- **MVVM** architecture with clear separation of concerns
- **Protocol-oriented** design for testability

### **Pull Request Process**
1. **Fork** the repository
2. **Create** feature branch (`feature/amazing-feature`)
3. **Add** comprehensive tests for new functionality
4. **Update** documentation and README
5. **Submit** pull request with detailed description

## 📄 License

PhotoStop is available under the MIT License. See LICENSE file for details.

## 🙏 Acknowledgments

- **Apple** - iOS SDK, Core ML, StoreKit 2, AVFoundation
- **OpenAI** - DALL-E image editing capabilities
- **Google** - Gemini 2.5 Flash Image multimodal AI
- **Clipdrop** - Professional background removal
- **Fal.ai** - FLUX model integration
- **Community** - Open source libraries and inspiration

## 📞 Support

For support, feature requests, or bug reports:
- **Email**: support@photostop.app
- **GitHub Issues**: Create detailed issue reports
- **Documentation**: Check README and inline code comments
- **Community**: Join discussions in GitHub Discussions

---

**PhotoStop** - Transform your photos with the power of AI ✨

*Built with ❤️ using Swift, SwiftUI, and cutting-edge AI technology*

