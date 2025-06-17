import 'dart:async';
import 'package:vibration/vibration.dart';
import 'settings_service.dart';
import 'text_to_speech_service.dart';

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  final SettingsService _settingsService = SettingsService();
  final TextToSpeechService _ttsService = TextToSpeechService();

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

  Future<void> basicApproachingTurnFeedback(
      {int intensity = mediumIntensity}) async {
    await playPattern('approachingTurn', intensity: intensity);
  }

  Future<void> basicLeftTurnFeedback({int intensity = mediumIntensity}) async {
    await playPattern('leftTurn', intensity: intensity);
  }

  Future<void> basicRightTurnFeedback({int intensity = mediumIntensity}) async {
    await playPattern('rightTurn', intensity: intensity);
  }

  Future<void> basicWrongDirectionFeedback(
      {int intensity = highIntensity}) async {
    await playPattern('wrongDirection', intensity: intensity);
  }

  Future<void> basicDestinationReachedFeedback(
      {int intensity = highIntensity}) async {
    await playPattern('destinationReached', intensity: intensity);
  }

  Future<void> basicCrossingStreetFeedback(
      {int intensity = mediumIntensity}) async {
    await playPattern('crossingStreet', intensity: intensity);
  }

  Future<void> basicHazardWarningFeedback(
      {int intensity = highIntensity}) async {
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

  // Enhanced feedback methods that combine vibration and TTS
  Future<void> leftTurnFeedback(
      {bool withTTS = false, String? streetName}) async {
    await playPattern('leftTurn');

    if (withTTS && _settingsService.currentSettings.ttsEnabled) {
      await _ttsService.announceTurn('left', streetName: streetName);
    }
  }

  Future<void> rightTurnFeedback(
      {bool withTTS = false, String? streetName}) async {
    await playPattern('rightTurn');

    if (withTTS && _settingsService.currentSettings.ttsEnabled) {
      await _ttsService.announceTurn('right', streetName: streetName);
    }
  }

  Future<void> approachingTurnFeedback(
      {bool withTTS = false,
      String? direction,
      String? streetName,
      int? distance}) async {
    await playPattern('approachingTurn');

    if (withTTS &&
        _settingsService.currentSettings.ttsEnabled &&
        direction != null) {
      await _ttsService.announceTurn(direction,
          streetName: streetName, distance: distance);
    }
  }

  Future<void> destinationReachedFeedback({bool withTTS = false}) async {
    await playPattern('destinationReached');

    if (withTTS && _settingsService.currentSettings.ttsEnabled) {
      await _ttsService.announceDestinationReached();
    }
  }

  Future<void> wrongDirectionFeedback({bool withTTS = false}) async {
    await playPattern('wrongDirection');

    if (withTTS && _settingsService.currentSettings.ttsEnabled) {
      await _ttsService.announceOffRoute();
    }
  }

  Future<void> crossingStreetFeedback(
      {int intensity = mediumIntensity,
      bool withTTS = false,
      String? streetName,
      String? crossingType}) async {
    await playPattern('crossingStreet', intensity: intensity);

    if (withTTS &&
        _settingsService.currentSettings.ttsEnabled &&
        _settingsService.currentSettings.announceHazards) {
      await _ttsService.announceCrossing(
          streetName: streetName, crossingType: crossingType);
    }
  }

  Future<void> hazardWarningFeedback(
      {int intensity = highIntensity,
      bool withTTS = false,
      String? hazardType,
      String? description}) async {
    await playPattern('hazardWarning', intensity: intensity);

    if (withTTS &&
        _settingsService.currentSettings.ttsEnabled &&
        _settingsService.currentSettings.announceHazards) {
      await _ttsService.announceHazard(hazardType ?? 'unknown',
          description: description);
    }
  }

  // Emergency feedback methods with TTS integration
  Future<void> emergencyStopWithTTSFeedback({bool withTTS = false}) async {
    await playPattern('emergencyStop');

    if (withTTS && _settingsService.currentSettings.ttsEnabled) {
      await _ttsService.announceEmergency('stop', 'stop');
    }
  }

  Future<void> emergencyReroutingWithTTSFeedback({bool withTTS = false}) async {
    await playPattern('emergencyRerouting');

    if (withTTS && _settingsService.currentSettings.ttsEnabled) {
      await _ttsService.announceEmergency('rerouting', 'reroute');
    }
  }
}
