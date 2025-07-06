#!/bin/bash

# TestFlight Deployment Script for Echo Map
# This script automates the process of building and uploading to TestFlight

set -e  # Exit on any error

echo "🚀 Starting TestFlight deployment for Echo Map..."

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

# Check if we're in the right directory
if [[ ! -f "pubspec.yaml" ]]; then
    print_error "pubspec.yaml not found. Please run this script from the project root directory."
    exit 1
fi

# Get current version from pubspec.yaml
current_version=$(grep "^version:" pubspec.yaml | sed 's/version: //')
print_status "Current version: $current_version"

# Ask if user wants to increment build number
read -p "Do you want to increment the build number? (y/N): " increment_build

if [[ $increment_build =~ ^[Yy]$ ]]; then
    # Extract version and build number
    version_number=$(echo $current_version | cut -d'+' -f1)
    build_number=$(echo $current_version | cut -d'+' -f2)
    
    # Increment build number
    new_build_number=$((build_number + 1))
    new_version="${version_number}+${new_build_number}"
    
    print_status "Updating version to: $new_version"
    
    # Update pubspec.yaml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version: .*/version: $new_version/" pubspec.yaml
    else
        # Linux
        sed -i "s/^version: .*/version: $new_version/" pubspec.yaml
    fi
    
    print_success "Version updated to $new_version"
fi

# Get release notes
echo ""
read -p "Enter release notes for this build (optional): " release_notes
if [[ -z "$release_notes" ]]; then
    release_notes="Latest updates and improvements"
fi

print_status "Release notes: $release_notes"

# Clean Flutter
print_status "Cleaning Flutter project..."
flutter clean

# Get dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Build IPA for App Store
print_status "Building IPA for App Store distribution..."
flutter build ipa --export-method app-store --release

# Check if build was successful
if [[ ! -f "build/ios/ipa/echo_map.ipa" ]]; then
    print_error "Build failed! IPA file not found."
    exit 1
fi

print_success "IPA built successfully!"

# Get file size
ipa_size=$(du -h "build/ios/ipa/echo_map.ipa" | cut -f1)
print_status "IPA size: $ipa_size"

# Upload options
echo ""
echo "📤 Upload Options:"
echo "1. Apple Transporter (Manual - opens app)"
echo "2. Command line (altool - requires Apple ID credentials)"
echo "3. Skip upload (just build)"

read -p "Choose upload method (1-3): " upload_choice

case $upload_choice in
    1)
        print_status "Opening Apple Transporter..."
        if command -v open &> /dev/null; then
            # Try to open Apple Transporter
            open -a "Transporter" 2>/dev/null || {
                print_warning "Apple Transporter not found. Please install it from the Mac App Store."
                print_status "Manual upload: Drag build/ios/ipa/echo_map.ipa into Apple Transporter"
            }
        else
            print_status "Manual upload: Drag build/ios/ipa/echo_map.ipa into Apple Transporter"
        fi
        ;;
    2)
        echo ""
        read -p "Enter your Apple ID email: " apple_id
        read -s -p "Enter your app-specific password: " app_password
        echo ""
        
        print_status "Uploading to App Store Connect..."
        xcrun altool --upload-app --type ios -f build/ios/ipa/echo_map.ipa \
            --username "$apple_id" --password "$app_password" || {
            print_error "Upload failed! Please check your credentials."
            exit 1
        }
        print_success "Upload completed!"
        ;;
    3)
        print_warning "Skipping upload. IPA ready at: build/ios/ipa/echo_map.ipa"
        ;;
    *)
        print_error "Invalid choice. Skipping upload."
        ;;
esac

# Final instructions
echo ""
print_success "🎉 TestFlight deployment process completed!"
echo ""
print_status "Next steps:"
echo "1. 📱 Go to App Store Connect: https://appstoreconnect.apple.com"
echo "2. 🔍 Navigate to your Echo Map app → TestFlight tab"
echo "3. ⏱️  Wait for build to process (5-10 minutes)"
echo "4. 👥 Add build to test groups or invite testers"
echo "5. 📬 Testers will receive TestFlight notification"
echo ""
print_status "Build info:"
echo "   📦 IPA: build/ios/ipa/echo_map.ipa"
echo "   📏 Size: $ipa_size"
echo "   📝 Notes: $release_notes"
if [[ $increment_build =~ ^[Yy]$ ]]; then
    echo "   🔢 Version: $new_version"
fi
echo ""
print_success "Happy testing! 🚀"
