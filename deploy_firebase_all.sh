#!/bin/bash

echo "🚀 Starting cross-platform Firebase App Distribution deployment..."

# Build and deploy Android
echo "📱 Building Android APK..."
flutter build apk --release

echo "📤 Uploading Android APK to Firebase..."
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
    --app 1:198276033289:android:ffc03ebe7abab5cf9ac1d8 \
    --release-notes "Beta version for testing - Android"

# Build and deploy iOS
echo "🍎 Building iOS release..."
flutter build ios --release

echo "📦 Creating iOS archive..."
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
    -destination generic/platform=iOS -archivePath build/Runner.xcarchive archive

echo "📱 Exporting iOS IPA..."
xcodebuild -exportArchive -archivePath build/Runner.xcarchive \
    -exportPath build/ios/ipa -exportOptionsPlist ExportOptions.plist

echo "📤 Uploading iOS IPA to Firebase..."
cd ..
firebase appdistribution:distribute ios/build/ios/ipa/echo_map.ipa \
    --app 1:198276033289:ios:bbaf194d87df38899ac1d8 \
    --release-notes "Beta version for testing - iOS"

echo "✅ Cross-platform deploy complete!"
echo "📲 Android: https://console.firebase.google.com/project/echo-map-49a3f/appdistribution/app/android:com.milad9a.echo_map"
echo "🍎 iOS: https://console.firebase.google.com/project/echo-map-49a3f/appdistribution/app/ios:com.milad9a.echoMap"
