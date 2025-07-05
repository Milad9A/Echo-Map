import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  // Platform-specific vibration patterns
  // iOS patterns - optimized for iOS haptic feedback characteristics
  static const Map<String, List<int>> _iOSVibrationPatterns = {
    'onRoute': [350], // Single vibration with good presence

    'approachingTurn': [
      200,
      250,
      200,
      250,
      200,
      500,
      600,
      300,
      400
    ], // Balanced rhythm for iOS

    'leftTurn': [
      100,
      180,
      100,
      180,
      100,
      180,
      100,
      180,
      100,
      300,
      1200
    ], // Crisp taps with stronger ending

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
    ], // Strong start with clear taps

    'wrongDirection': [
      250,
      120,
      250,
      120,
      250,
      700,
      250,
      120,
      250,
      120,
      250,
      700,
      400,
      180,
      400
    ], // More pronounced urgent pattern

    'destinationReached': [
      300,
      180,
      400,
      180,
      500,
      180,
      600,
      180,
      700,
      300,
      180,
      300,
      180,
      300,
      800
    ], // Celebration with good presence

    'crossingStreet': [
      500,
      900,
      500,
      900,
      500,
      900,
      500,
      500,
      200
    ], // Deliberate warning pattern

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
    ], // Rapid fire with stronger punctuation
  };

  // Android patterns - optimized for Android vibration motor characteristics
  static const Map<String, List<int>> _androidVibrationPatterns = {
    'onRoute': [400], // Slightly longer but not excessive

    'approachingTurn': [
      220,
      280,
      220,
      280,
      220,
      550,
      650,
      330,
      430
    ], // Balanced for Android motors

    'leftTurn': [
      110,
      200,
      110,
      200,
      110,
      200,
      110,
      200,
      110,
      320,
      1300
    ], // Crisp but substantial taps

    'rightTurn': [
      1300,
      1300,
      110,
      320,
      110,
      320,
      110,
      320,
      110,
      320,
      110,
      320,
      110
    ], // Strong but controlled

    'wrongDirection': [
      280,
      140,
      280,
      140,
      280,
      800,
      280,
      140,
      280,
      140,
      280,
      800,
      450,
      200,
      450
    ], // Urgent but not overwhelming

    'destinationReached': [
      320,
      200,
      420,
      200,
      520,
      200,
      620,
      200,
      720,
      320,
      200,
      320,
      200,
      320,
      850
    ], // Celebration with good feel

    'crossingStreet': [
      550,
      1000,
      550,
      1000,
      550,
      1000,
      550,
      550,
      220
    ], // Deliberate but not excessive

    'hazardWarning': [
      90,
      90,
      90,
      90,
      90,
      90,
      90,
      450,
      90,
      90,
      90,
      90,
      90,
      90,
      90,
      900,
      350
    ], // Rapid fire with strong punctuation
  };

  // Get platform-appropriate patterns
  static Map<String, List<int>> get patterns {
    if (_isIOS) {
      return _iOSVibrationPatterns;
    } else {
      return _androidVibrationPatterns;
    }
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
      final calibratedIntensity = _calibrateIntensityForPlatform(amplitude);
      await _platformOptimizedVibrate(
        duration: duration,
        intensity: calibratedIntensity,
      );
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

  // Platform-specific intensity calibration
  int _calibrateIntensityForPlatform(int requestedIntensity) {
    if (_isIOS) {
      // iOS haptic feedback tends to feel weaker and less consistent
      // Significant boost needed to match Android feel
      final boosted = (requestedIntensity * 1.5).round();
      return boosted.clamp(
          100, 255); // Higher minimum for iOS to be felt clearly
    } else {
      // Android motors are more direct but can vary widely by device
      // Apply moderate boost for consistency and to match iOS feel
      final adjusted = (requestedIntensity * 1.2).round();
      return adjusted.clamp(50, 255); // Ensure minimum perceptible level
    }
  }

  // Platform-aware pattern playback with optimized timing
  Future<void> _playPatternManually(List<int> pattern, int intensity) async {
    final calibratedIntensity = _calibrateIntensityForPlatform(intensity);

    // Pre-warm the haptic engine on iOS for better consistency
    if (_isIOS) {
      try {
        await HapticFeedback.selectionClick();
        await Future.delayed(const Duration(milliseconds: 30));
      } catch (e) {
        // If system haptic fails, continue without pre-warm
        debugPrint('iOS haptic pre-warm failed: $e');
      }
    }

    for (int i = 0; i < pattern.length; i++) {
      if (i % 2 == 0) {
        // Even indices are vibration durations
        await _platformOptimizedVibrate(
            duration: pattern[i], intensity: calibratedIntensity);
      } else {
        // Odd indices are pause durations - crucial for pattern distinction
        // iOS needs slightly longer pauses for pattern clarity
        // Android needs consistent pauses for pattern recognition
        final pauseDuration = _isIOS
            ? (pattern[i] * 1.15).round()
            : (pattern[i] * 1.05).round(); // Slight boost for Android too
        await Future.delayed(Duration(milliseconds: pauseDuration));
      }
    }
  }

  // Enhanced iOS haptic feedback for better consistency
  Future<void> _enhancedIOSHaptic({
    required int duration,
    required int intensity,
  }) async {
    if (_isIOS) {
      // Use iOS system haptic feedback as a primer
      try {
        if (intensity >= 200) {
          await HapticFeedback.heavyImpact();
        } else if (intensity >= 100) {
          await HapticFeedback.mediumImpact();
        } else {
          await HapticFeedback.lightImpact();
        }

        // Small delay to let system haptic settle
        await Future.delayed(const Duration(milliseconds: 20));
      } catch (e) {
        // If system haptic fails, continue with regular vibration
        debugPrint('iOS haptic feedback failed: $e');
      }
    }

    // Follow with regular vibration for consistency
    await Vibration.vibrate(duration: duration, amplitude: intensity);
  }

  // Platform-optimized vibration method
  Future<void> _platformOptimizedVibrate({
    required int duration,
    required int intensity,
  }) async {
    if (_isIOS) {
      // iOS has better results with enhanced haptic feedback
      if (duration > 600) {
        // Break long vibrations into segments for iOS with enhanced haptics
        final segments = (duration / 300).ceil();
        final segmentDuration = duration ~/ segments;
        final gapDuration = 30; // Very short gap between segments

        for (int i = 0; i < segments; i++) {
          await _enhancedIOSHaptic(
              duration: segmentDuration, intensity: intensity);
          if (i < segments - 1) {
            await Future.delayed(Duration(milliseconds: gapDuration));
          }
        }
      } else {
        // For shorter vibrations, use enhanced haptic feedback
        await _enhancedIOSHaptic(duration: duration, intensity: intensity);
      }
    } else {
      // Android can handle longer vibrations better, but add consistency measures
      if (duration > 1000) {
        // Even Android benefits from segmentation for very long vibrations
        final segments = (duration / 500).ceil();
        final segmentDuration = duration ~/ segments;
        final gapDuration = 20; // Minimal gap for Android

        for (int i = 0; i < segments; i++) {
          await Vibration.vibrate(
              duration: segmentDuration, amplitude: intensity);
          if (i < segments - 1) {
            await Future.delayed(Duration(milliseconds: gapDuration));
          }
        }
      } else {
        await Vibration.vibrate(duration: duration, amplitude: intensity);
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

  // Platform-aware simple vibrate with calibrated intensity (public method)
  Future<void> platformOptimizedVibrate({
    int duration = 200,
    int intensity = mediumIntensity,
  }) async {
    final calibratedIntensity = _calibrateIntensityForPlatform(intensity);

    if (await hasVibrator()) {
      await _platformOptimizedVibrate(
        duration: duration,
        intensity: calibratedIntensity,
      );
    }
  }

  // Test method to compare platform vibration patterns
  Future<void> testPlatformConsistency(
      {int intensity = mediumIntensity}) async {
    debugPrint('Testing platform consistency on ${_isIOS ? 'iOS' : 'Android'}');

    // Test basic vibration with new calibration
    debugPrint('Testing basic vibration with enhanced calibration...');
    await platformOptimizedVibrate(duration: 500, intensity: intensity);
    await Future.delayed(const Duration(seconds: 1));

    // Test intensity levels
    debugPrint('Testing intensity levels...');
    await platformOptimizedVibrate(duration: 300, intensity: lowIntensity);
    await Future.delayed(const Duration(milliseconds: 800));
    await platformOptimizedVibrate(duration: 300, intensity: mediumIntensity);
    await Future.delayed(const Duration(milliseconds: 800));
    await platformOptimizedVibrate(duration: 300, intensity: highIntensity);
    await Future.delayed(const Duration(seconds: 1));

    // Test all patterns with platform optimization
    final patternNames = patterns.keys.toList();
    for (String patternName in patternNames) {
      debugPrint(
          'Testing $patternName pattern with enhanced platform optimization...');
      await playPattern(patternName, intensity: intensity);
      await Future.delayed(const Duration(seconds: 2));
    }

    debugPrint('Platform consistency test completed');
  }

  // New method to test cross-platform feel similarity
  Future<void> testCrossPlatformFeel({int intensity = mediumIntensity}) async {
    debugPrint('Testing cross-platform feel similarity...');

    // Test the key patterns that should feel similar across platforms
    final keyPatterns = ['onRoute', 'leftTurn', 'rightTurn', 'wrongDirection'];

    for (String pattern in keyPatterns) {
      debugPrint('Testing $pattern for cross-platform consistency...');
      if (_settingsService.currentSettings.ttsEnabled) {
        await _ttsService.speak('Testing $pattern');
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await playPattern(pattern, intensity: intensity);
      await Future.delayed(const Duration(seconds: 2));
    }

    debugPrint('Cross-platform feel test completed');
  }

  // Get platform information for debugging
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': _isIOS ? 'iOS' : 'Android',
      'patternsCount': patterns.length,
      'intensityCalibration':
          _isIOS ? '1.5x boost, min 100' : '1.2x boost, min 50',
      'patternOptimization': _isIOS
          ? 'Shorter durations, longer pauses, pre-warm'
          : 'Moderate durations, consistent pauses',
      'longVibrationHandling': _isIOS
          ? 'Segmented (max 600ms) with pre-vibration'
          : 'Segmented (max 1000ms)',
      'improvements': [
        'Enhanced intensity calibration for cross-platform consistency',
        'Pre-warming haptic engine on iOS for better responsiveness',
        'Optimized pause durations for better pattern recognition',
        'Balanced vibration patterns between platforms',
        'Improved segmentation for long vibrations'
      ],
    };
  }

  // Check device capabilities and adjust accordingly
  Future<Map<String, bool>> getDeviceCapabilities() async {
    final hasVibrator = await this.hasVibrator();
    final hasAmplitude = await hasAmplitudeControl();

    return {
      'hasVibrator': hasVibrator,
      'hasAmplitudeControl': hasAmplitude,
      'isPlatformOptimized': true,
      'supportsPatterns': hasVibrator,
    };
  }

  // Enhanced simple vibrate with device capability awareness
  Future<void> adaptiveVibrate({
    int duration = 200,
    int intensity = mediumIntensity,
  }) async {
    final capabilities = await getDeviceCapabilities();

    if (!capabilities['hasVibrator']!) return;

    final calibratedIntensity = _calibrateIntensityForPlatform(intensity);

    if (capabilities['hasAmplitudeControl']!) {
      // Device supports amplitude control
      await _platformOptimizedVibrate(
        duration: duration,
        intensity: calibratedIntensity,
      );
    } else {
      // Fallback for devices without amplitude control
      await _platformOptimizedVibrate(
        duration: duration,
        intensity:
            255, // Use max intensity for devices without amplitude control
      );
    }
  }
}
