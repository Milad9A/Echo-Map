# Scripts

This folder contains deployment and build automation scripts.

## Files

- **`deploy_testflight.sh`** - iOS TestFlight deployment script
  - Builds iOS IPA for App Store distribution
  - Increments build numbers
  - Uploads to TestFlight
  - Usage: `./deploy_testflight.sh`

- **`deploy_firebase.sh`** - Cross-platform deployment script for Firebase App Distribution
  - Builds both Android APK and iOS IPA
  - Uploads to Firebase App Distribution
  - Usage: `./deploy_firebase.sh`

## Usage

Make scripts executable:
```bash
chmod +x scripts/*.sh
```

Run deployment:
```bash
# TestFlight (iOS only)
./scripts/deploy_testflight.sh

# Firebase App Distribution (both platforms)
./scripts/deploy_firebase.sh
```
