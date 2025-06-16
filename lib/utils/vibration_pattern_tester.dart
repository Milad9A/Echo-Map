import 'dart:async';
import 'dart:io' show Platform;
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

  /// Compare two vibration patterns by playing them one after another
  Future<void> comparePatterns(
    String pattern1,
    String pattern2, {
    int intensity = 128,
    Duration delayBetween = const Duration(seconds: 2),
  }) async {
    debugPrint('Comparing patterns: $pattern1 vs $pattern2');

    // Play first pattern
    await _vibrationService.playPattern(pattern1, intensity: intensity);

    // Wait between patterns
    await Future.delayed(delayBetween);

    // Play second pattern
    await _vibrationService.playPattern(pattern2, intensity: intensity);
  }

  /// Test all available patterns in sequence
  Future<void> testAllPatternsSequentially({
    int intensity = 128,
    Duration delayBetween = const Duration(seconds: 1),
  }) async {
    final patterns = VibrationService.patterns.keys.toList();

    debugPrint('Testing ${patterns.length} vibration patterns');

    for (int i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      debugPrint('Testing pattern ${i + 1}/${patterns.length}: $pattern');

      await _vibrationService.playPattern(pattern, intensity: intensity);

      // Don't wait after the last pattern
      if (i < patterns.length - 1) {
        await Future.delayed(delayBetween);
      }
    }

    debugPrint('Pattern testing complete');
  }

  /// Test a specific pattern multiple times
  Future<void> repeatPattern(
    String patternName, {
    int repetitions = 3,
    int intensity = 128,
    Duration delayBetween = const Duration(milliseconds: 800),
  }) async {
    debugPrint('Repeating pattern "$patternName" $repetitions times');

    for (int i = 0; i < repetitions; i++) {
      await _vibrationService.playPattern(patternName, intensity: intensity);

      if (i < repetitions - 1) {
        await Future.delayed(delayBetween);
      }
    }
  }

  /// Test pattern at different intensities
  Future<void> testPatternIntensities(
    String patternName, {
    List<int> intensities = const [64, 128, 192, 255],
    Duration delayBetween = const Duration(seconds: 1),
  }) async {
    debugPrint('Testing pattern "$patternName" at different intensities');

    for (int i = 0; i < intensities.length; i++) {
      final intensity = intensities[i];
      debugPrint('Testing intensity: $intensity');

      await _vibrationService.playPattern(patternName, intensity: intensity);

      if (i < intensities.length - 1) {
        await Future.delayed(delayBetween);
      }
    }
  }

  /// Get pattern information for display
  Map<String, dynamic> getPatternInfo(String patternName) {
    final pattern = VibrationService.patterns[patternName];
    if (pattern == null) {
      return {
        'exists': false,
        'error': 'Pattern not found',
      };
    }

    return {
      'exists': true,
      'name': patternName,
      'description': _getPatternDescription(patternName),
      'complexity': _calculatePatternComplexity(pattern),
      'duration': _calculatePatternDuration(patternName),
    };
  }

  String _getPatternDescription(String patternName) {
    switch (patternName) {
      case 'onRoute':
        return 'Gentle confirmation you\'re on the right path';
      case 'approachingTurn':
        return 'Alerts you when a turn is coming up';
      case 'offRoute':
        return 'Warning that you\'ve deviated from the path';
      case 'destinationReached':
        return 'Celebration when you arrive at your destination';
      case 'crossingStreet':
        return 'Safety alert when approaching a street crossing';
      case 'hazardWarning':
        return 'Strong warning for obstacles or hazards ahead';
      default:
        return 'Navigation feedback pattern';
    }
  }

  int _calculatePatternComplexity(List<int> pattern) {
    // Simple complexity calculation based on pattern length and variation
    int complexity = pattern.length;

    // Add complexity for pauses (0 values)
    int pauses = pattern.where((value) => value == 0).length;
    complexity += pauses;

    return complexity.clamp(1, 10);
  }

  /// Get recommendations for pattern testing
  List<String> getTestingRecommendations() {
    return [
      'Test patterns in a quiet environment',
      'Hold the device firmly while testing',
      'Test at different intensity levels to find your preference',
      'Compare similar patterns to learn the differences',
      'Take breaks between testing sessions to avoid sensory fatigue',
      'Test patterns you\'ll use most frequently first',
    ];
  }
}
