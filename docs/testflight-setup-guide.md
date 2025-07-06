# TestFlight Setup Guide for Echo Map

This document outlines the essential steps for preparing and distributing a Flutter iOS app to TestFlight using the Hochschule Bremen Apple Developer account.

## Prerequisites

- **Apple Developer Account**: Hochschule Bremen (Team ID: P9TBP84RRQ)
- **Bundle ID**: `com.milad9a.echo-map`
- **Flutter Project**: Ready for iOS build

## Step-by-Step Process

### 1. Configure iOS Project for Correct Team

Update the Xcode project to use the Hochschule Bremen developer account:

**File**: `ios/Runner.xcodeproj/project.pbxproj`
- Set all `DEVELOPMENT_TEAM` entries to `P9TBP84RRQ`
- Set all `PRODUCT_BUNDLE_IDENTIFIER` entries to `com.milad9a.echo-map`

### 2. Update Android Configuration (Optional - for consistency)

**File**: `android/app/build.gradle.kts`
```kotlin
android {
    namespace = "com.milad9a.echo_map"
    // ...
    defaultConfig {
        applicationId = "com.milad9a.echo-map"
        // ...
    }
}
```

### 3. Register Bundle ID in Apple Developer Portal

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Sign in with Hochschule Bremen Apple ID
3. Navigate to "Certificates, Identifiers & Profiles" → "Identifiers"
4. Click "+" to register new App ID
5. Enter:
   - **Description**: "Echo Map"
   - **Bundle ID**: `com.milad9a.echo-map`
   - **Capabilities**: Add as needed

### 4. Create App in App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Sign in with Hochschule Bremen Apple ID
3. Click "My Apps" → "+" → "New App"
4. Fill in:
   - **Platform**: iOS
   - **Name**: "Echo Map"
   - **Primary Language**: English
   - **Bundle ID**: Select `com.milad9a.echo-map`
   - **SKU**: Unique identifier (e.g., "echo-map-2025")

### 5. Build IPA for App Store

```bash
# Clean build environment
flutter clean

# Build IPA for App Store distribution
flutter build ipa --export-method app-store --release
```

**Expected Output**: 
- Build should show: "using specified development team in Xcode project: P9TBP84RRQ"
- IPA created at: `build/ios/ipa/echo_map.ipa`

### 6. Upload to App Store Connect

**Using Apple Transporter (Recommended):**
1. Download [Apple Transporter](https://apps.apple.com/us/app/transporter/id1450874784)
2. Sign in with Hochschule Bremen Apple ID
3. Drag and drop `build/ios/ipa/echo_map.ipa`
4. Click "Deliver"

**Using Command Line:**
```bash
xcrun altool --upload-app --type ios -f build/ios/ipa/echo_map.ipa --username YOUR_APPLE_ID --password YOUR_APP_SPECIFIC_PASSWORD
```

### 7. Set Up TestFlight

1. In App Store Connect, go to "Echo Map" app
2. Click "TestFlight" tab
3. Wait for build to process (few minutes)
4. Add internal testers or create external test groups
5. Distribute to testers


## Quick Reference

### Key Configuration Values
- **Team ID**: P9TBP84RRQ (Hochschule Bremen)
- **Bundle ID**: com.milad9a.echo-map
- **Export Method**: app-store

### Essential Commands
```bash
flutter clean
flutter build ipa --export-method app-store --release
```

### Key Files to Modify
1. `ios/Runner.xcodeproj/project.pbxproj` - Development team and bundle ID
2. `android/app/build.gradle.kts` - Application ID (optional)

### Links
- [Apple Developer Portal](https://developer.apple.com/account)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Apple Transporter](https://apps.apple.com/us/app/transporter/id1450874784)
