import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import '../services/vibration_service.dart';
import 'package:flutter/foundation.dart';

class VibrationPatternTester {
  final VibrationService _vibrationService = VibrationService();
  final bool _isIOS = Platform.isIOS;
  final bool _isAndroid = Platform.isAndroid;
  final String _platformName = _getPlatformName();

  static String _getPlatformName() {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isFuchsia) return 'Fuchsia';
    return 'unknown';
  }

  // Test a specific pattern
  Future<void> testPattern(
    String patternName, {
    int intensity = VibrationService.mediumIntensity,
  }) async {
    debugPrint(
      'Testing pattern: $patternName on $_platformName with intensity: $intensity',
    );

    // Check if platform is supported
    if (!_isIOS && !_isAndroid) {
      debugPrint(
        'Warning: Vibration testing on $_platformName may not be supported',
      );
    }

    // Ensure any previous vibration is stopped
    await _vibrationService.stopVibration();
    await Future.delayed(const Duration(milliseconds: 200));

    // Play the requested pattern
    return await _vibrationService.playPattern(
      patternName,
      intensity: intensity,
    );
  }

  // Test all patterns in sequence with a delay between each
  Future<void> testAllPatterns({
    int intensity = VibrationService.mediumIntensity,
    int delaySeconds = 2,
  }) async {
    debugPrint(
      'Testing all patterns with intensity: $intensity on $_platformName',
    );

    // Check if platform is supported
    if (!_isIOS && !_isAndroid) {
      debugPrint(
        'Warning: Vibration testing on $_platformName may not be supported',
      );
    }

    // First, ensure vibration is working with a simple test
    await _vibrationService.simpleVibrate(duration: 300, amplitude: intensity);
    await Future.delayed(const Duration(seconds: 1));

    // On iOS, we need longer delays between patterns
    final betweenPatternDelay = _isIOS ? 3 : delaySeconds;

    for (final patternName in VibrationService.patterns.keys) {
      debugPrint('Testing pattern: $patternName with intensity: $intensity');

      // Ensure previous vibration is stopped
      await _vibrationService.stopVibration();
      await Future.delayed(const Duration(milliseconds: 500));

      // Play the pattern
      await _vibrationService.playPattern(patternName, intensity: intensity);

      // Wait for pattern to complete - longer for iOS
      await Future.delayed(Duration(seconds: betweenPatternDelay));
    }

    // Stop vibration at the end
    await _vibrationService.stopVibration();
  }

  // Calculate approximate duration of a pattern
  int _calculatePatternDuration(String patternName) {
    if (!VibrationService.patterns.containsKey(patternName)) {
      return 1000; // Default duration if pattern not found
    }

    // Sum all delays and durations in the pattern
    final pattern = VibrationService.patterns[patternName]!;
    int totalDuration = pattern.fold(0, (sum, duration) => sum + duration);

    // Add extra time for iOS to account for implementation delays
    if (_isIOS) {
      totalDuration += 500;
    }

    return totalDuration;
  }

  // Compare two patterns side by side with enhanced distinctiveness
  Future<void> comparePatterns(
    String pattern1,
    String pattern2, {
    int intensity = VibrationService.mediumIntensity,
    int delaySeconds = 2,
  }) async {
    // On iOS, use longer delays
    final compareDelay = _isIOS ? delaySeconds + 1 : delaySeconds;

    debugPrint(
      'Comparing patterns: $pattern1 vs $pattern2 on $_platformName with intensity: $intensity',
    );

    // Check if platform is supported
    if (!_isIOS && !_isAndroid) {
      debugPrint(
        'Warning: Vibration comparison on $_platformName may not be supported',
      );
    }

    // Play first pattern
    await _vibrationService.stopVibration();
    await Future.delayed(const Duration(milliseconds: 500));

    // Announce first pattern
    debugPrint('Now playing: $pattern1');
    await _vibrationService.playPattern(pattern1, intensity: intensity);

    // Wait for the pattern to complete
    int pattern1Duration = _calculatePatternDuration(pattern1);
    await Future.delayed(Duration(milliseconds: max(pattern1Duration, 1000)));

    // Stop vibration between patterns
    await _vibrationService.stopVibration();
    await Future.delayed(Duration(seconds: compareDelay));

    // Announce second pattern
    debugPrint('Now playing: $pattern2');
    await _vibrationService.playPattern(pattern2, intensity: intensity);
  }

  // Test pattern at different intensity levels
  Future<void> testPatternIntensities(String patternName) async {
    debugPrint('Testing pattern: $patternName at different intensity levels');

    // Test at low intensity
    debugPrint('Testing at LOW intensity: ${VibrationService.lowIntensity}');
    await _vibrationService.playPattern(
      patternName,
      intensity: VibrationService.lowIntensity,
    );
    await Future.delayed(const Duration(seconds: 2));
    await _vibrationService.stopVibration();
    await Future.delayed(const Duration(milliseconds: 500));

    // Test at medium intensity
    debugPrint(
      'Testing at MEDIUM intensity: ${VibrationService.mediumIntensity}',
    );
    await _vibrationService.playPattern(
      patternName,
      intensity: VibrationService.mediumIntensity,
    );
    await Future.delayed(const Duration(seconds: 2));
    await _vibrationService.stopVibration();
    await Future.delayed(const Duration(milliseconds: 500));

    // Test at high intensity
    debugPrint('Testing at HIGH intensity: ${VibrationService.highIntensity}');
    await _vibrationService.playPattern(
      patternName,
      intensity: VibrationService.highIntensity,
    );
  }

  // Cancel any ongoing vibration test
  void cancelTest() {
    _vibrationService.stopVibration();
  }

  // Test navigation sequence simulation
  Future<void> testNavigationSequence() async {
    debugPrint('Testing navigation sequence...');

    // Simulate navigation start
    await _vibrationService.onRouteFeedback();
    await Future.delayed(const Duration(seconds: 2));

    // Simulate approaching turn
    await _vibrationService.approachingTurnFeedback();
    await Future.delayed(const Duration(seconds: 2));

    // Simulate left turn
    await _vibrationService.leftTurnFeedback();
    await Future.delayed(const Duration(seconds: 3));

    // Back on route
    await _vibrationService.onRouteFeedback();
    await Future.delayed(const Duration(seconds: 2));

    // Simulate destination reached
    await _vibrationService.destinationReachedFeedback();

    debugPrint('Navigation sequence test completed');
  }

  // Test error conditions
  Future<void> testErrorPatterns() async {
    debugPrint('Testing error patterns...');

    // Wrong direction
    await _vibrationService.wrongDirectionFeedback();
    await Future.delayed(const Duration(seconds: 2));

    // Hazard warning
    await _vibrationService.hazardWarningFeedback();
    await Future.delayed(const Duration(seconds: 2));

    debugPrint('Error pattern testing completed');
  }

  // Test intensity levels for a specific pattern
  Future<void> testIntensityLevels(String pattern) async {
    debugPrint('Testing intensity levels for: $pattern');

    // Low intensity
    debugPrint('Low intensity');
    await _vibrationService.playPattern(pattern,
        intensity: VibrationService.lowIntensity);
    await Future.delayed(const Duration(seconds: 1));

    // Medium intensity
    debugPrint('Medium intensity');
    await _vibrationService.playPattern(pattern,
        intensity: VibrationService.mediumIntensity);
    await Future.delayed(const Duration(seconds: 1));

    // High intensity
    debugPrint('High intensity');
    await _vibrationService.playPattern(pattern,
        intensity: VibrationService.highIntensity);

    debugPrint('Intensity testing completed');
  }
}
