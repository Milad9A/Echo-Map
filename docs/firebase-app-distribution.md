# Firebase App Distribution Setup Guide

Firebase App Distribution provides free beta testing for both iOS and Android apps, serving as an alternative to TestFlight and Google Play Console.

## Quick Start

```bash
# Make script executable (first time only)
chmod +x scripts/deploy_firebase.sh

# Deploy to both platforms
./scripts/deploy_firebase.sh
```p Distribution Setup Guide (Android)

Firebase App Distribution provides free beta testing for Android apps. For iOS, we use the dedicated TestFlight deployment script.

## Quick Start

```bash
# Make script executable (first time only)
chmod +x scripts/deploy_firebase.sh

# Deploy Android to Firebase
./scripts/deploy_firebase.sh
```

## Prerequisites

### 1. Firebase CLI Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Set project
firebase use echo-map-49a3f
```

### 2. iOS Requirements
- Xcode properly configured
- iOS development certificates installed
- `ExportOptions.plist` in the `ios/` directory

### 3. Android Requirements
- Android SDK configured
- Flutter Android build tools setup

## Project Configuration

- **Firebase Project**: `echo-map-49a3f`
- **Android App ID**: `1:198276033289:android:ffc03ebe7abab5cf9ac1d8`
- **iOS App ID**: `1:198276033289:ios:bbaf194d87df38899ac1d8`

## Console Access

- 📲 **Android Builds**: https://console.firebase.google.com/project/echo-map-49a3f/appdistribution/app/android:com.milad9a.echo_map
- 🍎 **iOS Builds**: https://console.firebase.google.com/project/echo-map-49a3f/appdistribution/app/ios:com.milad9a.echoMap

## Adding Testers

1. Go to Firebase Console → App Distribution
2. Select your platform (Android/iOS)
3. Click "Testers & Groups"
4. Add testers by email address
5. They'll receive an invitation email with download instructions

## Troubleshooting

### Common Issues

1. **Firebase CLI not found**: Install with `npm install -g firebase-tools`
2. **Permission denied**: Run `chmod +x scripts/deploy_firebase.sh`
3. **iOS build fails**: Check Xcode configuration and certificates
4. **Android build fails**: Verify Android SDK and Flutter setup
5. **Upload fails**: Check Firebase CLI login status with `firebase login:list`

### Build Output Locations

- **Android APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **iOS IPA**: `ios/build/ios/ipa/echo_map.ipa`
