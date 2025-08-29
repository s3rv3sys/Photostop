# PhotoStop - AI-Powered Photo Enhancement App

PhotoStop is a revolutionary iOS camera app that uses AI to automatically enhance your photos with just one tap. The app captures multiple frames, selects the best one using Core ML, and enhances it using Google's Gemini AI API.

## Features

### 🎯 One-Tap AI Enhancement
- Capture and enhance photos with a single tap
- Automatic frame selection using Core ML quality scoring
- AI-powered enhancement via Google Gemini API
- Fallback Core Image filters when API is unavailable

### 📸 Smart Camera System
- Burst capture with exposure bracketing
- Automatic best frame selection
- Real-time camera preview
- Support for front and back cameras

### 🧠 Intelligent Frame Scoring
- Core ML model for image quality assessment
- Evaluates sharpness, exposure, and noise
- Algorithmic fallback for consistent performance
- Quality ratings and technical analysis

### 🎨 Creative Enhancement Options
- Pre-defined enhancement prompts
- Custom prompt support
- Before/after comparison view
- Quality score display

### 💾 Smart Storage Management
- Local storage for edit history
- Photos library integration
- Storage usage tracking
- Automatic cleanup of old images

### ⚙️ Comprehensive Settings
- API key management with Keychain security
- Usage tracking and limits
- Camera and photo permissions
- App preferences and configuration

## Architecture

PhotoStop follows the MVVM (Model-View-ViewModel) architecture pattern with a clean separation of concerns:

```
PhotoStop/
├── Models/              # Data structures
│   ├── EditedImage.swift
│   ├── EditPrompt.swift
│   └── FrameScore.swift
├── Services/            # Business logic layer
│   ├── CameraService.swift
│   ├── AIService.swift
│   ├── StorageService.swift
│   ├── KeychainService.swift
│   └── FrameScoringService.swift
├── ViewModels/          # MVVM presentation layer
│   ├── CameraViewModel.swift
│   ├── EditViewModel.swift
│   └── SettingsViewModel.swift
├── Views/               # SwiftUI user interface
│   ├── CameraView.swift
│   ├── ResultView.swift
│   ├── SettingsView.swift
│   └── GalleryView.swift
├── MLModel/             # Machine learning components
│   ├── TrainingSpec.md
│   └── FrameScoring.mlmodel.md
└── Tests/               # Unit tests
    ├── CameraServiceTests.swift
    ├── AIServiceTests.swift
    ├── StorageServiceTests.swift
    └── FrameScoringTests.swift
```

## Requirements

### System Requirements
- iOS 17.0 or later
- iPhone or iPad with camera
- Xcode 15.0 or later (for development)

### API Requirements
- Google Gemini API key (for AI enhancement)
- Internet connection (for AI features)

### Permissions
- Camera access (required)
- Photo Library access (for saving enhanced photos)

## Setup Instructions

### 1. Clone and Open Project

```bash
# Open the project in Xcode
open PhotoStop.xcodeproj
```

### 2. Configure Development Team
1. Select the PhotoStop project in Xcode
2. Go to "Signing & Capabilities"
3. Select your development team
4. Ensure bundle identifier is unique (e.g., `com.yourname.photostop`)

### 3. Set Up Google Gemini API

#### Get API Key
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key for Gemini
3. Copy the API key

#### Configure in App
1. Build and run the app
2. Go to Settings tab
3. Tap "Configure API Key"
4. Enter your Gemini API key
5. The key is securely stored in iOS Keychain

### 4. Add Core ML Model (Optional)

The app includes a fallback algorithm, but for best results:

1. Train the frame scoring model using `MLModel/TrainingSpec.md`
2. Convert to Core ML format
3. Add `FrameScoring.mlmodel` to the project
4. Ensure it's included in the app bundle

### 5. Build and Run

```bash
# Build for simulator
⌘ + R

# Build for device
Select your device and press ⌘ + R
```

## Usage Guide

### Basic Usage
1. **Launch PhotoStop** - Grant camera and photo library permissions
2. **Tap the capture button** - App captures multiple frames automatically
3. **Wait for AI processing** - Best frame is selected and enhanced
4. **View results** - See before/after comparison with quality score
5. **Save or share** - Save to Photos or share with others

### Advanced Features

#### Custom Enhancement Prompts
1. After capturing, tap "Edit Prompt"
2. Enter custom enhancement instructions
3. Tap "Re-enhance" to apply new prompt

#### Gallery and History
1. Tap "Gallery" to view edit history
2. Browse previous enhancements
3. Re-save or share any previous edit

#### Settings Configuration
1. **API Key**: Configure Gemini API access
2. **Usage Tracking**: Monitor API usage and limits
3. **Storage**: View and manage local storage
4. **Permissions**: Manage camera and photo access

## Development

### Running Tests

```bash
# Run all tests
⌘ + U

# Run specific test file
⌘ + U (select specific test)
```

### Code Structure

#### Services Layer
- **CameraService**: AVFoundation camera management
- **AIService**: Gemini API integration with fallback
- **StorageService**: Local and Photos library storage
- **FrameScoringService**: Core ML and algorithmic scoring
- **KeychainService**: Secure API key storage

#### ViewModels Layer
- **CameraViewModel**: Camera capture orchestration
- **EditViewModel**: Enhancement and editing logic
- **SettingsViewModel**: App configuration management

#### Views Layer
- **CameraView**: Live camera preview and capture
- **ResultView**: Enhanced image display and actions
- **SettingsView**: App configuration interface
- **GalleryView**: Edit history browser

### Adding New Features

1. **Models**: Add new data structures in `Models/`
2. **Services**: Implement business logic in `Services/`
3. **ViewModels**: Create presentation logic in `ViewModels/`
4. **Views**: Build UI components in `Views/`
5. **Tests**: Add unit tests in `Tests/`

## API Integration

### Gemini API Usage

The app uses Google's Gemini API for image enhancement:

```swift
// Example API call structure
let prompt = "Enhance this photo to make it more vibrant and sharp"
let enhancedImage = await aiService.enhanceImage(originalImage, prompt: prompt)
```

### Rate Limiting
- Free tier: 20 enhancements per day
- Automatic fallback to Core Image filters
- Usage tracking and notifications

### Error Handling
- Network connectivity issues
- API rate limiting
- Invalid API keys
- Service unavailability

## Core ML Integration

### Frame Scoring Model

The app includes a Core ML model for intelligent frame selection:

- **Input**: 224x224 RGB image
- **Output**: Quality score (0.0 to 1.0)
- **Metrics**: Sharpness, exposure, noise assessment
- **Fallback**: Algorithmic scoring when model unavailable

### Training Your Own Model

See `MLModel/TrainingSpec.md` for complete training instructions:

1. Prepare image quality datasets
2. Train MobileNetV3-based model
3. Convert to Core ML format
4. Integrate into app bundle

## Troubleshooting

### Common Issues

#### App Won't Build
- Check development team configuration
- Verify bundle identifier is unique
- Ensure iOS deployment target is 17.0+

#### Camera Not Working
- Check camera permissions in Settings
- Verify device has camera capability
- Test on physical device (not simulator)

#### AI Enhancement Failing
- Verify API key is configured correctly
- Check internet connectivity
- Monitor API usage limits
- Review error messages in console

#### Poor Enhancement Quality
- Ensure good lighting conditions
- Check API key has proper permissions
- Try different enhancement prompts
- Verify image quality before enhancement

### Debug Information

Enable debug logging by setting:
```swift
// In AppDelegate.swift
#if DEBUG
print("Debug mode enabled")
#endif
```

### Performance Optimization

- Use release builds for performance testing
- Monitor memory usage during burst capture
- Profile Core ML inference times
- Optimize image processing pipeline

## Contributing

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Maintain MVVM architecture
- Include comprehensive unit tests

### Pull Request Process
1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit pull request with description

## Privacy and Security

### Data Handling
- Images processed locally when possible
- API calls use HTTPS encryption
- No user data stored on external servers
- Local storage encrypted by iOS

### API Key Security
- Keys stored in iOS Keychain
- Never logged or transmitted insecurely
- Automatic key validation
- Secure key rotation support

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

### Documentation
- In-app help and tutorials
- API documentation links
- Troubleshooting guides

### Contact
- GitHub Issues for bug reports
- Feature requests welcome
- Community discussions encouraged

## Roadmap

### Version 1.1
- [ ] Additional AI models support
- [ ] Batch processing capabilities
- [ ] Advanced editing tools
- [ ] Cloud sync for edit history

### Version 1.2
- [ ] Video enhancement support
- [ ] Social sharing features
- [ ] Custom filter creation
- [ ] Professional editing tools

### Version 2.0
- [ ] iPad optimization
- [ ] macOS support
- [ ] Advanced ML models
- [ ] Professional workflow integration

---

**PhotoStop** - Transform your photos with the power of AI. One tap, endless possibilities.

For more information, visit our [documentation](./MLModel/TrainingSpec.md) or check out the [API integration guide](./Services/).

