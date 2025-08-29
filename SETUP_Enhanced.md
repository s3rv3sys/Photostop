# PhotoStop Enhanced - Complete Setup Guide

This guide will walk you through setting up the enhanced PhotoStop app with AI routing, subscription system, and social media integration.

## 📋 Prerequisites

### **Development Environment**
- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later
- **iOS Deployment Target**: 17.0 or later
- **Apple Developer Account**: Required for device testing and App Store distribution

### **API Accounts Required**
1. **Google AI Studio** - For Gemini 2.5 Flash Image API
2. **OpenAI** - For DALL-E image editing API
3. **Clipdrop** - For background removal API
4. **Fal.ai** - For FLUX model API
5. **Apple Developer** - For StoreKit and App Store Connect

## 🚀 Quick Start

### **1. Project Setup**

```bash
# Extract the PhotoStop project
tar -xzf PhotoStop_Complete.tar.gz
cd PhotoStop

# Open in Xcode
open PhotoStop.xcodeproj
```

### **2. Configure Development Team**
1. **Select** PhotoStop project in Xcode navigator
2. **Choose** your development team in "Signing & Capabilities"
3. **Update** Bundle Identifier to your unique identifier
4. **Enable** required capabilities:
   - Camera
   - Photos
   - In-App Purchase
   - Background Modes (if needed)

### **3. Install Dependencies**
PhotoStop uses only native iOS frameworks - no external dependencies required!

## 🔑 API Configuration

### **Google Gemini API Setup**

1. **Visit** [Google AI Studio](https://aistudio.google.com/)
2. **Create** new project or select existing
3. **Generate** API key for Gemini 2.5 Flash Image
4. **Copy** API key for later configuration

**Pricing**: $0.00025 per image (very cost-effective for premium features)

### **OpenAI API Setup**

1. **Visit** [OpenAI Platform](https://platform.openai.com/)
2. **Create** account and add billing information
3. **Generate** API key with image editing permissions
4. **Copy** API key for configuration

**Pricing**: ~$0.02 per image edit (budget-friendly option)

### **Clipdrop API Setup**

1. **Visit** [Clipdrop API](https://clipdrop.co/apis)
2. **Sign up** for developer account
3. **Subscribe** to background removal API
4. **Generate** API key

**Pricing**: ~$0.01 per background removal (specialized tool)

### **Fal.ai API Setup**

1. **Visit** [Fal.ai](https://fal.ai/)
2. **Create** developer account
3. **Generate** API key for FLUX models
4. **Choose** between FLUX Schnell (fast) or FLUX Dev (quality)

**Pricing**: ~$0.003-0.01 per image (excellent value for creative edits)

## 📱 App Configuration

### **Method 1: Runtime Configuration (Recommended)**

Run the app and use the Settings screen to add API keys:

1. **Launch** PhotoStop on device/simulator
2. **Navigate** to Settings tab
3. **Tap** "API Configuration"
4. **Enter** each API key in the respective field
5. **Tap** "Save" to store securely in Keychain

### **Method 2: Programmatic Configuration**

Add API keys directly in code (for development only):

```swift
// Add to AppDelegate.swift or SceneDelegate.swift
func configureAPIKeys() {
    let keychain = KeychainService.shared
    
    // Add your API keys here (NEVER commit to version control)
    keychain.save("your-gemini-api-key", forKey: "gemini_api_key")
    keychain.save("your-openai-api-key", forKey: "openai_api_key")
    keychain.save("your-clipdrop-api-key", forKey: "clipdrop_api_key")
    keychain.save("your-fal-api-key", forKey: "fal_api_key")
}
```

### **Method 3: Environment Variables**

For CI/CD or team development:

```bash
# Add to your shell profile (.zshrc, .bash_profile)
export PHOTOSTOP_GEMINI_KEY="your-gemini-api-key"
export PHOTOSTOP_OPENAI_KEY="your-openai-api-key"
export PHOTOSTOP_CLIPDROP_KEY="your-clipdrop-api-key"
export PHOTOSTOP_FAL_KEY="your-fal-api-key"
```

Then load in app:
```swift
func loadEnvironmentKeys() {
    let keychain = KeychainService.shared
    
    if let geminiKey = ProcessInfo.processInfo.environment["PHOTOSTOP_GEMINI_KEY"] {
        keychain.save(geminiKey, forKey: "gemini_api_key")
    }
    // Repeat for other keys...
}
```

## 💳 StoreKit Configuration

### **1. App Store Connect Setup**

1. **Login** to [App Store Connect](https://appstoreconnect.apple.com/)
2. **Create** new app or select existing
3. **Navigate** to "Features" → "In-App Purchases"
4. **Create** the following products:

#### **Subscription Products**
```
Product ID: com.photostop.pro.monthly
Type: Auto-Renewable Subscription
Price: $9.99/month
Free Trial: 7 days
Subscription Group: PhotoStop Pro
```

```
Product ID: com.photostop.pro.yearly
Type: Auto-Renewable Subscription
Price: $79.99/year (20% savings)
Free Trial: 7 days
Subscription Group: PhotoStop Pro
```

#### **Consumable Products**
```
Product ID: com.photostop.credits.premium10
Type: Consumable
Price: $2.99
Description: 10 Premium AI Credits
```

```
Product ID: com.photostop.credits.premium50
Type: Consumable
Price: $9.99
Description: 50 Premium AI Credits
```

### **2. StoreKit Testing Configuration**

PhotoStop includes a `PhotoStop.storekit` configuration file for testing:

1. **Open** `PhotoStop.storekit` in Xcode
2. **Verify** product IDs match your App Store Connect configuration
3. **Update** prices and descriptions as needed
4. **Enable** StoreKit testing in scheme settings:
   - **Edit Scheme** → Run → Options
   - **StoreKit Configuration**: PhotoStop.storekit

### **3. Sandbox Testing**

1. **Create** sandbox test accounts in App Store Connect
2. **Sign out** of App Store on test device
3. **Run** PhotoStop and attempt purchase
4. **Sign in** with sandbox account when prompted
5. **Test** subscription flow and credit purchases

## 📱 Social Media Integration

### **Instagram Integration**

1. **Add** URL schemes to `Info.plist`:
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>instagram</string>
    <string>instagram-stories</string>
</array>
```

2. **Test** Instagram sharing:
   - **Install** Instagram app on test device
   - **Enhance** a photo in PhotoStop
   - **Tap** Instagram sharing button
   - **Verify** handoff to Instagram Stories

### **TikTok Integration**

1. **Register** app with TikTok for Developers (optional for basic sharing)
2. **Add** TikTok URL schemes:
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tiktok</string>
    <string>snssdk1233</string>
</array>
```

3. **Configure** URL scheme handling:
```xml
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

## 🧪 Testing Setup

### **Unit Testing**

PhotoStop includes comprehensive test coverage:

```bash
# Run all tests
⌘ + U in Xcode

# Run specific test suite
xcodebuild test -scheme PhotoStop -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:PhotoStopTests/RoutingServiceTests
```

### **Test Configuration**

1. **Enable** test coverage in scheme settings
2. **Configure** test plans for different scenarios:
   - **Unit Tests**: Fast, isolated component testing
   - **Integration Tests**: Cross-service communication
   - **UI Tests**: End-to-end user workflows

### **Mock Testing**

All services include mock implementations:
```swift
// Example: Testing with mock services
let mockRouting = MockRoutingService()
mockRouting.shouldSucceed = true
mockRouting.mockProvider = "TestProvider"

let viewModel = CameraViewModel(routingService: mockRouting)
// Test viewModel behavior...
```

## 🎯 Core ML Model Setup

### **Frame Scoring Model**

PhotoStop includes a Core ML model stub for frame scoring:

1. **Review** `MLModel/TrainingSpec.md` for training requirements
2. **Train** model using provided PyTorch script (optional)
3. **Replace** `FrameScoring.mlmodel.md` with actual `.mlmodel` file
4. **Update** `FrameScoringService.swift` to load real model

### **Training Data**

For production use, train the model with:
- **10,000+** diverse photos with quality scores
- **Balanced dataset** across different photo types
- **Validation set** for performance testing

## 🚀 Deployment

### **Development Build**

```bash
# Build for simulator
xcodebuild -scheme PhotoStop -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Build for device
xcodebuild -scheme PhotoStop -destination 'platform=iOS,name=Your iPhone'
```

### **TestFlight Distribution**

1. **Archive** the app:
   - **Product** → Archive in Xcode
   - **Distribute App** → App Store Connect
   - **Upload** to TestFlight

2. **Configure** TestFlight:
   - **Add** beta testers
   - **Set** testing instructions
   - **Enable** StoreKit testing for reviewers

### **App Store Release**

1. **Prepare** App Store listing:
   - **Screenshots** (use included app icon assets)
   - **Description** highlighting AI features
   - **Keywords** for discoverability
   - **Privacy policy** (required for camera/photos access)

2. **Submit** for review:
   - **Complete** App Store Connect metadata
   - **Submit** for review
   - **Respond** to reviewer feedback if needed

## 🔧 Troubleshooting

### **Common Issues**

#### **API Key Issues**
```
Error: "API key not found" or "Invalid API key"
```
**Solution**: 
- Verify API key is correctly entered in Settings
- Check Keychain storage with debugging
- Ensure API key has correct permissions

#### **StoreKit Issues**
```
Error: "Product not found" or "Purchase failed"
```
**Solution**:
- Verify product IDs match App Store Connect
- Check StoreKit configuration file
- Test with sandbox account
- Clear StoreKit cache if needed

#### **Camera Permissions**
```
Error: "Camera access denied"
```
**Solution**:
- Check Info.plist camera usage description
- Reset privacy settings on device
- Verify app has camera permission in Settings

#### **Build Issues**
```
Error: "Signing certificate not found"
```
**Solution**:
- Configure development team in project settings
- Update provisioning profiles
- Check Apple Developer account status

### **Debug Mode**

Enable debug logging for troubleshooting:

```swift
// Add to AppDelegate.swift
#if DEBUG
Logger.shared.enableDebugLogging = true
#endif
```

### **Performance Monitoring**

Use Xcode Instruments to monitor:
- **Memory usage** during image processing
- **Network activity** for API calls
- **CPU usage** during ML inference
- **Battery impact** of camera operations

## 📊 Analytics & Monitoring

### **Usage Analytics**

Track key metrics:
- **Enhancement success rate** by provider
- **Credit consumption** patterns
- **Subscription conversion** rates
- **Social sharing** engagement

### **Error Monitoring**

Implement crash reporting:
```swift
// Example: Custom error tracking
func trackError(_ error: Error, context: String) {
    // Send to analytics service
    print("Error in \(context): \(error)")
}
```

### **Performance Metrics**

Monitor performance:
- **API response times** by provider
- **Image processing** duration
- **Cache hit rates**
- **Memory usage** patterns

## 🔒 Security Considerations

### **API Key Security**
- **Never** commit API keys to version control
- **Use** Keychain for secure storage
- **Rotate** keys regularly
- **Monitor** usage for anomalies

### **User Privacy**
- **Minimize** data collection
- **Delete** temporary files after processing
- **Respect** user privacy preferences
- **Comply** with App Store privacy requirements

### **Network Security**
- **Use** HTTPS for all API calls
- **Validate** SSL certificates
- **Implement** request signing where supported
- **Handle** network errors gracefully

## 📞 Support

### **Development Support**
- **Documentation**: Check README and inline comments
- **GitHub Issues**: Report bugs and request features
- **Code Review**: Submit pull requests for improvements

### **API Provider Support**
- **Google AI**: [Support Documentation](https://ai.google.dev/docs)
- **OpenAI**: [API Documentation](https://platform.openai.com/docs)
- **Clipdrop**: [API Support](https://clipdrop.co/apis/docs)
- **Fal.ai**: [Documentation](https://fal.ai/docs)

### **Apple Developer Support**
- **StoreKit**: [StoreKit Documentation](https://developer.apple.com/storekit/)
- **Core ML**: [Core ML Documentation](https://developer.apple.com/machine-learning/)
- **AVFoundation**: [Camera Documentation](https://developer.apple.com/avfoundation/)

---

**Congratulations!** 🎉 You now have a fully configured PhotoStop app with advanced AI routing, subscription management, and social media integration. Start enhancing photos and building amazing experiences!

*For additional help, check the comprehensive README or create an issue on GitHub.*

