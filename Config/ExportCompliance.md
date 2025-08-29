# Export Compliance Documentation

This document provides the export compliance information required for PhotoStop's App Store submission.

## 🔒 Encryption Usage

### **Does your app use encryption?**
**Answer: YES**

PhotoStop uses encryption in the following ways:

### **Standard Encryption APIs**
- **HTTPS/TLS**: All network communication with AI service providers uses standard HTTPS encryption
- **iOS Keychain**: API keys are stored using iOS Keychain Services with hardware-backed encryption
- **Network Security**: URLSession with default TLS configuration for secure API calls

### **Encryption Details**
- **Type**: Standard cryptographic protocols
- **Implementation**: iOS-provided APIs only
- **Purpose**: Secure network communication and local data protection
- **Algorithms**: TLS 1.2/1.3 for network, AES for Keychain storage

## 📋 Export Administration Regulations (EAR)

### **Classification**
PhotoStop qualifies for **EAR99** classification under the Export Administration Regulations because:

1. **Standard Encryption**: Uses only standard, publicly available encryption
2. **No Custom Crypto**: No proprietary or custom cryptographic implementations
3. **Commercial Software**: Standard commercial mobile application
4. **Mass Market**: Available to general public through App Store

### **Exemption Status**
PhotoStop is **EXEMPT** from export licensing requirements under:
- **Section 740.17(b)(1)**: Mass market software exemption
- **Note 4 to Category 5 Part 2**: Standard encryption exemption

## 🌐 AI Service Providers

PhotoStop communicates with the following AI service providers using standard HTTPS:

### **Google AI (Gemini)**
- **Endpoint**: `https://generativelanguage.googleapis.com`
- **Encryption**: TLS 1.3
- **Data**: Temporary image processing only
- **Retention**: Images deleted immediately after processing

### **OpenAI**
- **Endpoint**: `https://api.openai.com`
- **Encryption**: TLS 1.3
- **Data**: Temporary image processing only
- **Retention**: Images deleted immediately after processing

### **Clipdrop**
- **Endpoint**: `https://clipdrop-api.co`
- **Encryption**: TLS 1.2+
- **Data**: Temporary image processing only
- **Retention**: Images deleted immediately after processing

### **Fal.ai**
- **Endpoint**: `https://fal.run`
- **Encryption**: TLS 1.3
- **Data**: Temporary image processing only
- **Retention**: Images deleted immediately after processing

## 📱 iOS Security Features

### **Keychain Services**
- **Purpose**: Secure storage of API keys
- **Encryption**: Hardware-backed AES encryption
- **Access**: App-specific, biometric protection available
- **Implementation**: Standard iOS Keychain Services API

### **Network Security**
- **Transport**: HTTPS only (no HTTP allowed)
- **Certificate Validation**: Standard iOS certificate pinning
- **App Transport Security**: Enabled with no exceptions
- **TLS Version**: Minimum TLS 1.2, prefers TLS 1.3

### **Data Protection**
- **Local Storage**: iOS file protection enabled
- **Memory**: Automatic memory encryption on supported devices
- **Biometric**: Touch ID/Face ID integration for sensitive operations
- **Secure Enclave**: Utilized for cryptographic operations when available

## 🔐 Security Architecture

### **Data Flow Security**
1. **Image Capture**: Local processing with Core Image (no encryption needed)
2. **API Communication**: HTTPS/TLS encrypted transmission to AI providers
3. **Response Processing**: Encrypted response handling and immediate cleanup
4. **Local Storage**: Encrypted storage using iOS file protection

### **Key Management**
- **API Keys**: Stored in iOS Keychain with hardware encryption
- **Session Keys**: Managed by iOS URLSession with standard TLS
- **No Custom Keys**: No application-specific cryptographic key generation

### **Privacy Protection**
- **No Persistent Storage**: Images not stored on external servers
- **Temporary Processing**: AI providers delete images after processing
- **Local First**: On-device processing preferred when possible
- **User Control**: Users control all data sharing and processing

## 📄 Compliance Statements

### **For App Store Connect**
```
ITSAppUsesNonExemptEncryption: YES
ITSEncryptionExportComplianceCode: Uses standard HTTPS/TLS encryption for API communication and iOS Keychain for secure local storage. Qualifies for mass market software exemption under EAR 740.17(b)(1).
```

### **For Export Control**
PhotoStop uses only standard, publicly available encryption algorithms and protocols. The app:
- Does not implement proprietary cryptographic functionality
- Uses only iOS-provided security APIs
- Communicates via standard HTTPS/TLS protocols
- Qualifies for EAR99 classification and mass market exemption

### **For Privacy Compliance**
PhotoStop implements privacy-by-design principles:
- Minimal data collection (photos for processing only)
- Temporary processing with immediate deletion
- No cross-app tracking or user profiling
- Full user control over data sharing

## 🌍 International Distribution

### **Restricted Countries**
PhotoStop may be subject to distribution restrictions in certain countries due to:
- Export control regulations
- Local content restrictions
- AI service availability

### **Compliance Monitoring**
- Regular review of export control regulations
- Monitoring of AI service provider compliance
- Updates to encryption usage as needed
- Coordination with legal counsel for international distribution

## 📞 Contact Information

### **Export Compliance Officer**
- **Name**: Ishwar Prasad Nagulapalle
- **Title**: Developer/Export Compliance Officer
- **Company**: Servesys Corporation
- **Address**: 240 OConnor Ridge Blvd Suite 100, Irving, TX 75028, United States
- **Email**: ishwar@servesys.com
- **Phone**: [Your Phone Number]

### **Legal Counsel** (if applicable)
- **Company**: Servesys Corporation Legal Department
- **Address**: 240 OConnor Ridge Blvd Suite 100, Irving, TX 75028, United States
- **Contact**: Legal Team
- **Email**: legal@servesys.com

## 📚 References

### **Regulatory References**
- **EAR**: 15 CFR Parts 730-774
- **Section 740.17**: Mass Market Software Exemption
- **Category 5 Part 2**: Information Security
- **ITAR**: 22 CFR Parts 120-130 (not applicable)

### **Technical Standards**
- **TLS 1.3**: RFC 8446
- **TLS 1.2**: RFC 5246
- **HTTPS**: RFC 2818
- **iOS Security**: Apple Platform Security Guide

### **Apple Documentation**
- **App Store Review Guidelines**: Section 5.3 (Privacy)
- **Export Compliance**: App Store Connect Help
- **Encryption Guidelines**: Technical Q&A QA1686

---

**Certification**: I certify that the information provided in this document is accurate and complete to the best of my knowledge. PhotoStop complies with all applicable export control regulations and uses only standard, publicly available encryption technologies.

**Date**: August 29, 2025
**Signature**: Ishwar Prasad Nagulapalle
**Name**: Ishwar Prasad Nagulapalle
**Title**: Lead Developer
**Company**: Servesys Corporation

