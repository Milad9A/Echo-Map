# EchoMap

EchoMap is a vibration-only navigation app built in Flutter to empower blind and low-vision users to travel independently and confidently. By translating turn-by-turn directions into distinct haptic cues, EchoMap keeps you on the right path—no sight required.

## Project Overview

EchoMap uses distinct vibration patterns to guide users along a route without requiring visual feedback. The app leverages:

- **Haptic feedback** to communicate navigation instructions
- **GPS location services** to track user position
- **Mapping services** to determine routes and navigation
- **Accessible UI design** to ensure compatibility with screen readers

## Architecture

EchoMap uses the BLoC (Business Logic Component) pattern for state management with the following structure:

```
lib/
├── blocs/          # BLoC classes for state management
├── models/         # Data models
├── repositories/   # Data access layer
├── screens/        # UI screens
├── services/       # Business logic and services
├── utils/          # Utility functions
├── widgets/        # Reusable UI components
└── main.dart       # App entry point
```

## Features

- Vibration-based turn-by-turn navigation
- Accessible user interface optimized for screen readers
- Safety features for street crossings and hazards
- Voice command input for destinations

## Getting Started

### Prerequisites

- Flutter SDK (3.8.0 or higher)
- Android Studio / VS Code with Flutter extensions
- iOS simulator / Android emulator or physical device

### Installation

1. Clone the repository

```
git clone https://github.com/yourusername/echo_map.git
```

2. Install dependencies

```
flutter pub get
```

3. Run the app

```
flutter run
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
