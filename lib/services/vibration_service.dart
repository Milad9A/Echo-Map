import 'package:vibration/vibration.dart';

class VibrationService {
  // Singleton pattern
  static final VibrationService _instance = VibrationService._internal();

  factory VibrationService() => _instance;

  VibrationService._internal();

  // Vibration intensity levels
  static const int lowIntensity = 50;
  static const int mediumIntensity = 150;
  static const int highIntensity = 255;

  // Vibration pattern library
  static const Map<String, List<int>> patterns = {
    'onRoute': [0, 100],
    'approachingTurn': [0, 150, 100, 150],
    'wrongDirection': [0, 500],
    'destinationReached': [0, 100, 100, 100, 100, 100],
    'hazardWarning': [0, 100, 50, 100, 50, 300],
    'crossingStreet': [0, 200, 100, 200, 100, 200],
    'leftTurn': [0, 150, 100, 300],
    'rightTurn': [0, 300, 100, 150],
    'uTurn': [0, 300, 100, 300, 100, 300],
    'recalculating': [0, 100, 50, 100, 50, 100, 50, 100],
  };

  // Check if device supports vibration
  Future<bool> hasVibrator() async {
    return await Vibration.hasVibrator() ?? false;
  }

  // Check if device supports amplitude control
  Future<bool> hasAmplitudeControl() async {
    return await Vibration.hasAmplitudeControl() ?? false;
  }

  // On route - slight vibration
  Future<void> onRouteFeedback({int intensity = lowIntensity}) async {
    Vibration.vibrate(duration: 100, amplitude: intensity);
  }

  // Approaching turn - double pulse
  Future<void> approachingTurnFeedback({
    int intensity = mediumIntensity,
  }) async {
    Vibration.vibrate(
      pattern: patterns['approachingTurn']!,
      amplitude: intensity,
    );
  }

  // Wrong direction - long vibration
  Future<void> wrongDirectionFeedback({int intensity = highIntensity}) async {
    Vibration.vibrate(duration: 500, amplitude: intensity);
  }

  // Destination reached - triple pulse
  Future<void> destinationReachedFeedback({
    int intensity = mediumIntensity,
  }) async {
    Vibration.vibrate(
      pattern: patterns['destinationReached']!,
      amplitude: intensity,
    );
  }

  // Left turn specific pattern
  Future<void> leftTurnFeedback({int intensity = mediumIntensity}) async {
    Vibration.vibrate(pattern: patterns['leftTurn']!, amplitude: intensity);
  }

  // Right turn specific pattern
  Future<void> rightTurnFeedback({int intensity = mediumIntensity}) async {
    Vibration.vibrate(pattern: patterns['rightTurn']!, amplitude: intensity);
  }

  // U-turn specific pattern
  Future<void> uTurnFeedback({int intensity = highIntensity}) async {
    Vibration.vibrate(pattern: patterns['uTurn']!, amplitude: intensity);
  }

  // Street crossing warning
  Future<void> crossingStreetFeedback({int intensity = highIntensity}) async {
    Vibration.vibrate(
      pattern: patterns['crossingStreet']!,
      amplitude: intensity,
    );
  }

  // Hazard warning
  Future<void> hazardWarningFeedback({int intensity = highIntensity}) async {
    Vibration.vibrate(
      pattern: patterns['hazardWarning']!,
      amplitude: intensity,
    );
  }

  // Recalculating route
  Future<void> recalculatingRouteFeedback({
    int intensity = mediumIntensity,
  }) async {
    Vibration.vibrate(
      pattern: patterns['recalculating']!,
      amplitude: intensity,
    );
  }

  // Play a pattern by name
  Future<void> playPattern(
    String patternName, {
    int intensity = mediumIntensity,
  }) async {
    if (patterns.containsKey(patternName)) {
      Vibration.vibrate(pattern: patterns[patternName]!, amplitude: intensity);
    }
  }

  // Custom pattern for testing or custom notifications
  Future<void> customVibration({
    required List<int> pattern,
    int amplitude = mediumIntensity,
  }) async {
    Vibration.vibrate(pattern: pattern, amplitude: amplitude);
  }

  // Stop ongoing vibration
  Future<void> stopVibration() async {
    Vibration.cancel();
  }
}
