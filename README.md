# EchoMap

EchoMap is a vibration-only navigation app built in Flutter to empower blind and low-vision users to travel independently and confidently. By translating turn-by-turn directions into distinct haptic cues, EchoMap keeps you on the right path—no sight required.

## Project Status

EchoMap is currently in active development. The core functionality includes:

- ✅ Vibration pattern system for navigation feedback
- ✅ Location tracking and route deviation detection
- ✅ Turn detection and advance notification
- ✅ Google Maps integration for routing
- ✅ Testing utilities for vibration patterns

## Vibration Patterns

EchoMap uses carefully designed haptic patterns to communicate navigation information:

| Pattern            | Description                        | Usage                                      |
| ------------------ | ---------------------------------- | ------------------------------------------ |
| onRoute            | Short, consistent taps             | Confirms you're following the correct path |
| approachingTurn    | Ascending intensity pattern        | Warns about an upcoming turn               |
| leftTurn           | Strong-weak-weak pattern           | Indicates a left turn                      |
| rightTurn          | Weak-weak-strong pattern           | Indicates a right turn                     |
| uTurn              | Double-strong pulses               | Signals to make a U-turn                   |
| wrongDirection     | Strong, attention-grabbing pattern | Alerts when you're off route               |
| destinationReached | Celebratory pattern                | Confirms arrival at destination            |
| crossingStreet     | Double-tap pattern with pause      | Warns about street crossings               |
| hazardWarning      | Urgent, repeating pattern          | Alerts about potential hazards             |
| recalculating      | Rapid, staccato vibrations         | Indicates route recalculation              |

## Environment Setup

This project uses environment variables to manage API keys and other sensitive information.

### Setup Steps

1. Create a copy of the `.env.example` file and name it `.env`:

   ```
   cp .env.example .env
   ```

2. Edit the `.env` file and add your API keys:

   ```
   GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
   ```

3. The `.env` file is gitignored, so your sensitive information won't be committed to version control.

## Running the Project

After setting up your environment variables:

```bash
flutter pub get
flutter run
```

## API Keys Required

- Google Maps API with the following APIs enabled:
  - Maps SDK for Android
  - Maps SDK for iOS
  - Directions API
  - Places API

## Project Overview

EchoMap uses distinct vibration patterns to guide users along a route without requiring visual feedback. The app leverages:

- **Haptic feedback** to communicate navigation instructions
- **GPS location services** to track user position
- **Mapping services** to determine routes and navigation
- **Accessible UI design** to ensure compatibility with screen readers
- **Turn detection service** to predict and notify about upcoming turns

## Key Features

- **Vibration-based turn-by-turn navigation** with distinct patterns for different instructions
- **Advanced turn detection** to provide timely notifications before turns
- **Route deviation detection** to alert when off course
- **Accessible user interface** optimized for screen readers
- **Safety features** for street crossings and hazards
- **Vibration pattern testing tool** to fine-tune haptic feedback

## Getting Started

### Prerequisites

- Flutter SDK (3.8.0 or higher)
- Android Studio / VS Code with Flutter extensions
- iOS simulator / Android emulator or physical device
- Google Maps API key

### Installation

1. Clone the repository

```
git clone https://github.com/yourusername/echo_map.git
```

2. Install dependencies

```
flutter pub get
```

3. Set up environment variables as described above

4. Run the app

```
flutter run
```

## Deployment

EchoMap uses Firebase App Distribution for beta testing and app distribution across both iOS and Android platforms.

### Firebase App Distribution (Cross-Platform)

For beta testing across both iOS and Android platforms:

### Quick Deploy

```bash
# First time setup
chmod +x scripts/deploy_firebase.sh

# Deploy both platforms
./scripts/deploy_firebase.sh
```

### Console Links

- 📲 **Android**: https://console.firebase.google.com/project/echo-map-49a3f/appdistribution/app/android:com.milad9a.echo_map
- 🍎 **iOS**: https://console.firebase.google.com/project/echo-map-49a3f/appdistribution/app/ios:com.milad9a.echoMap

### Prerequisites for Deployment

```bash
npm install -g firebase-tools
firebase login
firebase use echo-map-49a3f
```

For detailed deployment instructions, see [docs/firebase-app-distribution.md](docs/firebase-app-distribution.md).

## Firebase Analytics

EchoMap includes Firebase Analytics to track user interactions and app performance for accessibility improvements.

### Analytics Events Tracked

- **Screen Navigation**: Track which screens users visit most frequently
- **Navigation Usage**: Monitor route calculations and navigation sessions
- **Vibration Patterns**: Understand which haptic feedback patterns are most effective
- **Accessibility Features**: Track usage of accessibility features
- **Settings Changes**: Monitor which settings users modify most often
- **Performance Metrics**: Track app performance for optimization

### Privacy Considerations

- Analytics are anonymous and help improve accessibility features
- No personal location data is stored in analytics
- Users can disable analytics in the Firebase Console if needed

## Quick Links

- 📚 **Documentation**: [`docs/`](docs/) - Setup guides, deployment instructions, and testing materials
- 🚀 **Scripts**: [`scripts/`](scripts/) - Automated deployment and build scripts  
- 📱 **TestFlight Setup**: [`docs/testflight-setup-guide.md`](docs/testflight-setup-guide.md)
- 🔥 **Firebase Distribution**: [`docs/firebase-app-distribution.md`](docs/firebase-app-distribution.md)

## Testing Features

EchoMap includes dedicated testing screens to validate core functionality:

- **Vibration Test Screen**: Test and compare different haptic patterns
- **Location Test Screen**: Verify GPS tracking and accuracy
- **Map Screen**: Test route calculation and visualization

## Contributing

Contributions to EchoMap are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
