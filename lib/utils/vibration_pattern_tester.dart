import 'dart:async';
import '../services/vibration_service.dart';

class VibrationPatternTester {
  final VibrationService _vibrationService = VibrationService();

  // Test a specific pattern
  Future<void> testPattern(
    String patternName, {
    int intensity = VibrationService.mediumIntensity,
  }) async {
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
    for (final patternName in VibrationService.patterns.keys) {
      await _vibrationService.playPattern(patternName, intensity: intensity);
      await Future.delayed(Duration(seconds: delaySeconds));
    }
  }

  // Compare two patterns side by side with a delay between
  Future<void> comparePatterns(
    String pattern1,
    String pattern2, {
    int intensity = VibrationService.mediumIntensity,
    int delaySeconds = 2,
  }) async {
    await _vibrationService.playPattern(pattern1, intensity: intensity);
    await Future.delayed(Duration(seconds: delaySeconds));
    await _vibrationService.playPattern(pattern2, intensity: intensity);
  }

  // Test pattern at different intensity levels
  Future<void> testPatternIntensities(String patternName) async {
    // Test at low intensity
    await _vibrationService.playPattern(
      patternName,
      intensity: VibrationService.lowIntensity,
    );
    await Future.delayed(const Duration(seconds: 2));

    // Test at medium intensity
    await _vibrationService.playPattern(
      patternName,
      intensity: VibrationService.mediumIntensity,
    );
    await Future.delayed(const Duration(seconds: 2));

    // Test at high intensity
    await _vibrationService.playPattern(
      patternName,
      intensity: VibrationService.highIntensity,
    );
  }

  // Cancel any ongoing vibration test
  void cancelTest() {
    _vibrationService.stopVibration();
  }
}
