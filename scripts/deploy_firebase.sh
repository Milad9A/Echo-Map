#!/bin/bash

# Firebase App Distribution Cross-Platform Deployment Script for Echo Map
# This script automates the process of building and uploading both iOS and Android to Firebase

set -e  # Exit on any error

# Get the script directory and navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root directory
cd "$PROJECT_ROOT"

echo "🚀 Starting cross-platform Firebase App Distribution deployment..."
echo "📂 Working from project root: $PROJECT_ROOT"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Get release notes
echo ""
read -p "Enter release notes for this build (optional): " release_notes
if [[ -z "$release_notes" ]]; then
    release_notes="Beta version for testing"
fi

print_status "Release notes: $release_notes"

# Clean Flutter
print_status "Cleaning Flutter project..."
flutter clean

# Get dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Build and deploy Android
print_status "Building Android APK..."
flutter build apk --release

# Check if Android build was successful
if [[ ! -f "build/app/outputs/flutter-apk/app-release.apk" ]]; then
    print_error "Android build failed! APK file not found."
    exit 1
fi

print_success "Android APK built successfully!"

# Get Android APK size
apk_size=$(du -h "build/app/outputs/flutter-apk/app-release.apk" | cut -f1)
print_status "Android APK size: $apk_size"

# Upload Android to Firebase App Distribution
print_status "Uploading Android APK to Firebase App Distribution..."
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
    --app 1:198276033289:android:ffc03ebe7abab5cf9ac1d8 \
    --release-notes "$release_notes - Android" || {
    print_error "Android upload failed! Please check your Firebase CLI setup."
    exit 1
}

print_success "Android upload completed!"

# Build and deploy iOS
print_status "Building iOS release..."
flutter build ios --release

print_status "Creating iOS archive..."
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
    -destination generic/platform=iOS -archivePath build/Runner.xcarchive archive || {
    print_error "iOS archive creation failed!"
    exit 1
}

print_status "Exporting iOS IPA..."
xcodebuild -exportArchive -archivePath build/Runner.xcarchive \
    -exportPath build/ios/ipa -exportOptionsPlist ExportOptions.plist || {
    print_error "iOS IPA export failed!"
    exit 1
}

cd ..

# Check if iOS build was successful
if [[ ! -f "ios/build/ios/ipa/echo_map.ipa" ]]; then
    print_error "iOS build failed! IPA file not found."
    exit 1
fi

print_success "iOS IPA built successfully!"

# Get iOS IPA size
ipa_size=$(du -h "ios/build/ios/ipa/echo_map.ipa" | cut -f1)
print_status "iOS IPA size: $ipa_size"

# Upload iOS to Firebase App Distribution
print_status "Uploading iOS IPA to Firebase App Distribution..."
firebase appdistribution:distribute ios/build/ios/ipa/echo_map.ipa \
    --app 1:198276033289:ios:bbaf194d87df38899ac1d8 \
    --release-notes "$release_notes - iOS" || {
    print_error "iOS upload failed! Please check your Firebase CLI setup."
    exit 1
}

print_success "iOS upload completed!"

print_success "🎉 Cross-platform Firebase App Distribution deployment completed!"
echo ""
print_status "Next steps:"
echo "1. 📱 Android: https://console.firebase.google.com/project/echo-map-49a3f/appdistribution/app/android:com.milad9a.echo_map"
echo "2. 🍎 iOS: https://console.firebase.google.com/project/echo-map-49a3f/appdistribution/app/ios:com.milad9a.echoMap"
echo "3. 👥 Add testers to your distribution groups"
echo "4. 📬 Testers will receive Firebase notification with download links"
echo ""
print_status "Build info:"
echo "   📦 Android APK: build/app/outputs/flutter-apk/app-release.apk"
echo "   📏 Android size: $apk_size"
echo "   📦 iOS IPA: ios/build/ios/ipa/echo_map.ipa"
echo "   📏 iOS size: $ipa_size"
echo "   📝 Notes: $release_notes"
echo ""
print_success "Happy testing! 🚀"
