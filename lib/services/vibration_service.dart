import 'package:vibration/vibration.dart';

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  // Intensity levels
  static const int lowIntensity = 50;
  static const int mediumIntensity = 128;
  static const int highIntensity = 255;

  // Vibration patterns (duration in milliseconds)
  static const Map<String, List<int>> patterns = {
    'onRoute': [100, 50, 100],
    'approachingTurn': [200, 100, 400],
    'leftTurn': [300, 100, 100, 100, 100],
    'rightTurn': [100, 100, 100, 100, 300],
    'wrongDirection': [500, 200, 500],
    'destinationReached': [200, 100, 200, 100, 200],
    'crossingStreet': [150, 100, 150, 300],
    'hazardWarning': [100, 50, 100, 50, 100],
  };

  Future<void> initialize() async {
    // Initialize vibration service
  }

  Future<bool> hasVibrator() async {
    return await Vibration.hasVibrator();
  }

  Future<bool> hasAmplitudeControl() async {
    return await Vibration.hasAmplitudeControl();
  }

  Future<bool> testVibration() async {
    try {
      await simpleVibrate(duration: 200);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> simpleVibrate(
      {int duration = 200, int amplitude = mediumIntensity}) async {
    if (await hasVibrator()) {
      await Vibration.vibrate(duration: duration, amplitude: amplitude);
    }
  }

  Future<void> playPattern(String patternName,
      {int intensity = mediumIntensity}) async {
    if (!patterns.containsKey(patternName)) return;

    final pattern = patterns[patternName]!;
    if (await hasVibrator()) {
      await Vibration.vibrate(
          pattern: pattern,
          intensities: List.filled(pattern.length, intensity));
    }
  }

  Future<void> stopVibration() async {
    await Vibration.cancel();
  }

  // Navigation-specific feedback methods
  Future<void> onRouteFeedback({int intensity = lowIntensity}) async {
    await playPattern('onRoute', intensity: intensity);
  }

  Future<void> approachingTurnFeedback(
      {int intensity = mediumIntensity}) async {
    await playPattern('approachingTurn', intensity: intensity);
  }

  Future<void> leftTurnFeedback({int intensity = mediumIntensity}) async {
    await playPattern('leftTurn', intensity: intensity);
  }

  Future<void> rightTurnFeedback({int intensity = mediumIntensity}) async {
    await playPattern('rightTurn', intensity: intensity);
  }

  Future<void> wrongDirectionFeedback({int intensity = highIntensity}) async {
    await playPattern('wrongDirection', intensity: intensity);
  }

  Future<void> destinationReachedFeedback(
      {int intensity = highIntensity}) async {
    await playPattern('destinationReached', intensity: intensity);
  }

  Future<void> crossingStreetFeedback({int intensity = mediumIntensity}) async {
    await playPattern('crossingStreet', intensity: intensity);
  }

  Future<void> hazardWarningFeedback({int intensity = highIntensity}) async {
    await playPattern('hazardWarning', intensity: intensity);
  }

  // Emergency feedback methods
  Future<void> emergencyStopFeedback() async {
    await simpleVibrate(duration: 1000, amplitude: highIntensity);
  }

  Future<void> emergencyReroutingFeedback() async {
    await playPattern('wrongDirection', intensity: highIntensity);
  }

  Future<void> pauseNavigationFeedback() async {
    await simpleVibrate(duration: 300, amplitude: mediumIntensity);
  }

  Future<void> newRouteFeedback() async {
    await playPattern('onRoute', intensity: mediumIntensity);
  }

  Future<void> slowDownFeedback() async {
    await playPattern('approachingTurn', intensity: lowIntensity);
  }
}
