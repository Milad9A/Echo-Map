import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'settings_service.dart';
import 'text_to_speech_service.dart';

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  final SettingsService _settingsService = SettingsService();
  final TextToSpeechService _ttsService = TextToSpeechService();

  // Platform detection
  static final bool _isIOS = Platform.isIOS;

  // Intensity levels
  static const int lowIntensity = 50;
  static const int mediumIntensity = 128;
  static const int highIntensity = 255;

  // Unified vibration patterns (duration in milliseconds) - [vibration, pause, vibration, pause, ...]
  static const Map<String, List<int>> _vibrationPatterns = {
    'onRoute': [400], // Single medium vibration

    'approachingTurn': [
      200,
      300,
      200,
      300,
      200,
      500,
      600,
      300,
      400
    ], // Building rhythm: short-short-short-long-LONGER

    'leftTurn': [
      100,
      200,
      100,
      200,
      100,
      200,
      100,
      200,
      100,
      300,
      1200
    ], // "tap-tap-tap-tap-tap-LOOOOOOONG" - builds up to climax

    'rightTurn': [
      1200,
      1200,
      100,
      300,
      100,
      300,
      100,
      300,
      100,
      300,
      100,
      300,
      100
    ], // "LOOOOOOONG-pause-tap-pause-tap-pause-tap-pause-tap-pause-tap" - starts strong, then clear details

    'wrongDirection': [
      250,
      150,
      250,
      150,
      250,
      800,
      250,
      150,
      250,
      150,
      250,
      800,
      400,
      200,
      400
    ], // Double urgent pattern with finale

    'destinationReached': [
      300,
      200,
      400,
      200,
      500,
      200,
      600,
      200,
      700,
      300,
      200,
      300,
      200,
      300,
      800
    ], // Celebration: ascending crescendo with finale

    'crossingStreet': [
      500,
      1000,
      500,
      1000,
      500,
      1000,
      500,
      500,
      200
    ], // Slow deliberate warning pattern

    'hazardWarning': [
      80,
      80,
      80,
      80,
      80,
      80,
      80,
      400,
      80,
      80,
      80,
      80,
      80,
      80,
      80,
      800,
      300
    ], // Rapid fire, pause, rapid fire, long pause, finale
  };

  // Get patterns (unified for all platforms)
  static Map<String, List<int>> get patterns => _vibrationPatterns;

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
      // Always use manual playback for consistent pattern distinction
      await _playPatternManually(pattern, intensity);
    }
  }

  // Manual pattern playback for better control and clearer distinction
  Future<void> _playPatternManually(List<int> pattern, int intensity) async {
    for (int i = 0; i < pattern.length; i++) {
      if (i % 2 == 0) {
        // Even indices are vibration durations
        await Vibration.vibrate(duration: pattern[i], amplitude: intensity);
      } else {
        // Odd indices are pause durations - crucial for pattern distinction
        await Future.delayed(Duration(milliseconds: pattern[i]));
      }
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

    if (withTTS && _settingsService.currentSettings.ttsEnabled) {
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

    if (withTTS && _settingsService.currentSettings.ttsEnabled) {
      await _ttsService.announceHazard(hazardType ?? 'hazard',
          description: description);
    }
  }

  // Emergency feedback methods with TTS integration
  Future<void> emergencyStopWithTTSFeedback({bool withTTS = false}) async {
    await emergencyStopFeedback();

    if (withTTS && _settingsService.currentSettings.ttsEnabled) {
      await _ttsService.announceEmergency('emergency', 'stop');
    }
  }

  Future<void> emergencyReroutingWithTTSFeedback({bool withTTS = false}) async {
    await emergencyReroutingFeedback();

    if (withTTS && _settingsService.currentSettings.ttsEnabled) {
      await _ttsService.announceEmergency('rerouting', 'recalculating');
    }
  }

  // Platform-specific intensity calibration
  int _calibrateIntensityForPlatform(int requestedIntensity) {
    if (_isIOS) {
      // iOS tends to feel weaker, so boost intensity slightly
      return (requestedIntensity * 1.2).round().clamp(1, 255);
    } else {
      // Android intensity is more direct
      return requestedIntensity;
    }
  }

  // Platform-aware simple vibrate with calibrated intensity
  Future<void> platformOptimizedVibrate({
    int duration = 200,
    int intensity = mediumIntensity,
  }) async {
    final calibratedIntensity = _calibrateIntensityForPlatform(intensity);

    if (await hasVibrator()) {
      if (_isIOS && duration > 1000) {
        // iOS has limitations on long vibrations, break them down
        final segments = (duration / 500).ceil();
        final segmentDuration = duration ~/ segments;

        for (int i = 0; i < segments; i++) {
          await Vibration.vibrate(
              duration: segmentDuration, amplitude: calibratedIntensity);
          if (i < segments - 1) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
      } else {
        await Vibration.vibrate(
            duration: duration, amplitude: calibratedIntensity);
      }
    }
  }

  // Debug method to test all patterns in sequence
  Future<void> testAllPatterns({int intensity = mediumIntensity}) async {
    final patternNames = patterns.keys.toList();

    for (String patternName in patternNames) {
      debugPrint('Testing pattern: $patternName');
      await playPattern(patternName, intensity: intensity);
      await Future.delayed(
          const Duration(seconds: 2)); // Pause between patterns
    }
  }

  // Test a specific pattern with announcement
  Future<void> testPatternWithAnnouncement(String patternName,
      {int intensity = mediumIntensity}) async {
    if (_settingsService.currentSettings.ttsEnabled) {
      await _ttsService.speak('Testing $patternName pattern');
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await playPattern(patternName, intensity: intensity);
  }
}
