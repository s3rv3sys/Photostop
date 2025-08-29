# PhotoStop Setup and Deployment Guide

This guide provides step-by-step instructions for setting up, building, and deploying the PhotoStop iOS app.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Setup](#project-setup)
3. [API Configuration](#api-configuration)
4. [Core ML Model Setup](#core-ml-model-setup)
5. [Building the App](#building-the-app)
6. [Testing](#testing)
7. [Deployment](#deployment)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Development Environment

- **macOS**: macOS 13.0 (Ventura) or later
- **Xcode**: Version 15.0 or later
- **iOS Deployment Target**: iOS 17.0 or later
- **Swift**: Version 5.9 or later

### Hardware Requirements

- **Mac**: Intel or Apple Silicon Mac
- **iOS Device**: iPhone or iPad with iOS 17.0+ (for device testing)
- **Camera**: Required for full functionality testing

### Developer Account

- **Apple Developer Account**: Required for device testing and App Store deployment
- **Google Cloud Account**: Required for Gemini API access

## Project Setup

### 1. Download and Extract Project

```bash
# If you have the project as a zip file
unzip PhotoStop.zip
cd PhotoStop

# Or if cloning from repository
git clone <repository-url>
cd PhotoStop
```

### 2. Open in Xcode

```bash
# Open the Xcode project
open PhotoStop.xcodeproj
```

### 3. Configure Project Settings

#### Bundle Identifier
1. Select the **PhotoStop** project in the navigator
2. Select the **PhotoStop** target
3. In the **General** tab, change the **Bundle Identifier** to something unique:
   ```
   com.yourname.photostop
   ```

#### Development Team
1. In the **Signing & Capabilities** tab
2. Select your **Team** from the dropdown
3. Ensure **Automatically manage signing** is checked

#### Deployment Target
1. Verify **iOS Deployment Target** is set to **17.0**
2. In **Supported Destinations**, ensure iPhone and iPad are selected

### 4. Verify File Structure

Ensure your project structure matches:

```
PhotoStop/
├── PhotoStop.xcodeproj/
├── AppDelegate.swift
├── SceneDelegate.swift
├── ContentView.swift
├── Info.plist
├── Models/
│   ├── EditedImage.swift
│   ├── EditPrompt.swift
│   └── FrameScore.swift
├── Services/
│   ├── CameraService.swift
│   ├── AIService.swift
│   ├── StorageService.swift
│   ├── KeychainService.swift
│   └── FrameScoringService.swift
├── ViewModels/
│   ├── CameraViewModel.swift
│   ├── EditViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── CameraView.swift
│   ├── ResultView.swift
│   ├── SettingsView.swift
│   └── GalleryView.swift
├── Assets.xcassets/
│   └── AppIcon.appiconset/
├── MLModel/
├── Tests/
└── README.md
```

## API Configuration

### 1. Get Google Gemini API Key

#### Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the **Generative AI API**

#### Generate API Key
1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Click **Create API Key**
3. Select your Google Cloud project
4. Copy the generated API key
5. **Keep this key secure** - never commit it to version control

### 2. Configure API Key in App

#### Method 1: Runtime Configuration (Recommended)
1. Build and run the app
2. Navigate to **Settings** tab
3. Tap **"Configure API Key"**
4. Enter your Gemini API key
5. Tap **"Save"**

The key will be securely stored in iOS Keychain.

#### Method 2: Development Configuration (Optional)
For development convenience, you can temporarily hardcode the key:

```swift
// In AIService.swift (DEVELOPMENT ONLY)
private func getAPIKey() -> String? {
    #if DEBUG
    // REMOVE BEFORE PRODUCTION
    return "your-api-key-here"
    #else
    return KeychainService.shared.get("gemini_api_key")
    #endif
}
```

**⚠️ WARNING**: Never ship with hardcoded API keys!

### 3. Verify API Configuration

1. Run the app
2. Capture a photo
3. Check that AI enhancement works
4. Monitor console for API-related logs

## Core ML Model Setup

### Option 1: Use Fallback Algorithm (Default)

The app works without a Core ML model using algorithmic frame scoring:
- Laplacian variance for sharpness
- Histogram analysis for exposure
- Texture analysis for noise

No additional setup required.

### Option 2: Add Trained Core ML Model

#### Train the Model
1. Follow instructions in `MLModel/TrainingSpec.md`
2. Use the provided PyTorch training script
3. Convert trained model to Core ML format

#### Add Model to Project
1. Drag `FrameScoring.mlmodel` into Xcode project
2. Ensure **"Add to target"** is checked for PhotoStop
3. Verify model appears in project navigator
4. Build project to compile model

#### Verify Model Integration
```swift
// Check if model loads successfully
guard let modelURL = Bundle.main.url(forResource: "FrameScoring", withExtension: "mlmodel"),
      let model = try? MLModel(contentsOf: modelURL) else {
    print("Core ML model not found, using fallback")
    return
}
print("Core ML model loaded successfully")
```

## Building the App

### 1. Clean Build Environment

```bash
# In Xcode
Product → Clean Build Folder (⇧⌘K)
```

### 2. Build for Simulator

1. Select **iPhone 15 Pro** (or preferred simulator)
2. Press **⌘R** to build and run
3. Grant camera permissions when prompted
4. Test basic functionality

### 3. Build for Device

1. Connect your iPhone/iPad via USB
2. Select your device from the scheme selector
3. Press **⌘R** to build and run
4. If prompted, trust the developer certificate on device
5. Test camera functionality on real device

### 4. Build Configurations

#### Debug Build (Development)
- Includes debug symbols
- Verbose logging enabled
- Faster compilation
- Larger app size

#### Release Build (Production)
- Optimized for performance
- Minimal logging
- Smaller app size
- Slower compilation

To create release build:
1. Edit scheme (⌘<)
2. Select **Run** → **Info**
3. Change **Build Configuration** to **Release**

## Testing

### 1. Unit Tests

Run all unit tests:
```bash
# In Xcode
Product → Test (⌘U)
```

Individual test files:
- `CameraServiceTests.swift` - Camera functionality
- `AIServiceTests.swift` - AI enhancement logic
- `StorageServiceTests.swift` - Storage operations
- `FrameScoringTests.swift` - Frame scoring algorithms

### 2. Manual Testing Checklist

#### Camera Functionality
- [ ] Camera preview displays correctly
- [ ] Capture button responds
- [ ] Front/back camera switching works
- [ ] Burst capture completes successfully
- [ ] Frame selection occurs

#### AI Enhancement
- [ ] API key configuration works
- [ ] Enhancement processing completes
- [ ] Before/after comparison displays
- [ ] Custom prompts function
- [ ] Fallback enhancement works without API

#### Storage and Gallery
- [ ] Images save to Photos library
- [ ] Local storage works correctly
- [ ] Gallery displays edit history
- [ ] Image deletion functions
- [ ] Storage usage tracking accurate

#### Settings and Permissions
- [ ] Camera permission request
- [ ] Photo library permission request
- [ ] API key storage and retrieval
- [ ] Usage limit tracking
- [ ] Settings persistence

### 3. Performance Testing

#### Memory Usage
- Monitor memory during burst capture
- Check for memory leaks in Instruments
- Verify proper image disposal

#### Processing Speed
- Measure frame scoring performance
- Time AI enhancement requests
- Profile Core ML inference (if using model)

#### Battery Usage
- Test extended usage scenarios
- Monitor background processing
- Verify efficient camera usage

## Deployment

### 1. App Store Preparation

#### Update Version and Build Numbers
```swift
// In project settings
Marketing Version: 1.0
Current Project Version: 1
```

#### Create App Store Connect Record
1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Create new app record
3. Fill in app information:
   - **Name**: PhotoStop
   - **Bundle ID**: com.yourname.photostop
   - **SKU**: photostop-ios
   - **Category**: Photo & Video

#### Prepare App Store Assets
- **App Icon**: 1024x1024 PNG (already included)
- **Screenshots**: iPhone and iPad screenshots
- **App Preview**: Optional video preview
- **Description**: App Store description
- **Keywords**: Relevant search keywords
- **Privacy Policy**: Required for camera/photo access

### 2. Archive and Upload

#### Create Archive
1. Select **Any iOS Device** as destination
2. **Product** → **Archive**
3. Wait for archive to complete
4. Organizer window opens automatically

#### Upload to App Store Connect
1. In Organizer, select your archive
2. Click **Distribute App**
3. Select **App Store Connect**
4. Choose **Upload**
5. Follow prompts to upload

#### Submit for Review
1. In App Store Connect, go to your app
2. Select the uploaded build
3. Fill in required metadata
4. Submit for App Store review

### 3. TestFlight Distribution (Optional)

#### Internal Testing
1. In App Store Connect, go to **TestFlight**
2. Add internal testers (up to 100)
3. Testers receive email invitation
4. Install via TestFlight app

#### External Testing
1. Create external test group
2. Add up to 10,000 external testers
3. Requires App Store review for first build
4. Subsequent builds auto-approved

### 4. Enterprise Distribution (If Applicable)

For enterprise deployment:
1. Enroll in Apple Developer Enterprise Program
2. Create enterprise distribution certificate
3. Build with enterprise provisioning profile
4. Distribute via internal channels

## Troubleshooting

### Common Build Issues

#### Code Signing Errors
```
Error: Code signing failed
```
**Solution**:
1. Check development team selection
2. Verify bundle identifier is unique
3. Ensure valid provisioning profile
4. Clean build folder and retry

#### Missing Dependencies
```
Error: Module 'SomeFramework' not found
```
**Solution**:
1. Check all files are added to target
2. Verify import statements
3. Clean and rebuild project

#### API Key Issues
```
Error: API key not configured
```
**Solution**:
1. Verify API key is entered in Settings
2. Check Keychain storage permissions
3. Ensure API key has correct permissions
4. Test with fresh API key

### Runtime Issues

#### Camera Not Working
**Symptoms**: Black camera preview, no capture
**Solutions**:
1. Check camera permissions in iOS Settings
2. Test on physical device (simulator has no camera)
3. Verify Info.plist camera usage description
4. Restart app after granting permissions

#### AI Enhancement Failing
**Symptoms**: Enhancement returns original image
**Solutions**:
1. Check internet connectivity
2. Verify API key configuration
3. Monitor API usage limits
4. Check console for error messages
5. Test fallback enhancement

#### Storage Issues
**Symptoms**: Images not saving, gallery empty
**Solutions**:
1. Check photo library permissions
2. Verify available storage space
3. Test local storage functionality
4. Check file system permissions

### Performance Issues

#### Slow Processing
**Symptoms**: Long enhancement times, UI freezing
**Solutions**:
1. Profile with Instruments
2. Check for main thread blocking
3. Optimize image processing pipeline
4. Reduce image resolution if needed

#### Memory Warnings
**Symptoms**: App crashes, memory warnings
**Solutions**:
1. Monitor memory usage in Xcode
2. Check for retain cycles
3. Optimize image handling
4. Implement proper memory management

#### Battery Drain
**Symptoms**: Rapid battery consumption
**Solutions**:
1. Optimize camera usage
2. Reduce background processing
3. Implement efficient algorithms
4. Profile energy usage

### Getting Help

#### Documentation
- Review `README.md` for general information
- Check `MLModel/TrainingSpec.md` for ML details
- Read inline code comments

#### Debugging
- Enable verbose logging in debug builds
- Use Xcode debugger and breakpoints
- Monitor console output
- Use Instruments for profiling

#### Community Support
- GitHub Issues for bug reports
- Stack Overflow for technical questions
- Apple Developer Forums for iOS-specific issues
- Google AI documentation for API questions

---

**Success!** You should now have PhotoStop running on your device. The app provides a powerful AI-enhanced photography experience with intelligent frame selection and automatic enhancement capabilities.

For additional support or questions, please refer to the main README.md or create an issue in the project repository.

