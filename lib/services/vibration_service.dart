import 'dart:math' show min, max;

import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class VibrationService {
  // Singleton pattern
  static final VibrationService _instance = VibrationService._internal();

  factory VibrationService() => _instance;

  VibrationService._internal();

  // Vibration intensity levels
  static const int lowIntensity = 50;
  static const int mediumIntensity = 150;
  static const int highIntensity = 255;

  // Flag to track initialization status
  bool _isInitialized = false;
  bool _vibrationSupported = false;
  bool _amplitudeSupported = false;
  bool _isIOS = false;
  bool _isAndroid = false;
  String _platformName = 'unknown';

  // Updated vibration pattern library with more distinct patterns
  static const Map<String, List<int>> patterns = {
    // Format: [delay1, duration1, delay2, duration2, ...]
    // Very short, consistent taps - "you're on the right track"
    'onRoute': [0, 100, 200, 100],

    // Ascending intensity pattern - "a turn is coming up"
    'approachingTurn': [0, 100, 150, 200, 150, 300],

    // Strong, long, attention-grabbing pattern - "you're going the wrong way"
    'wrongDirection': [0, 600, 300, 600, 300, 200],

    // Celebratory pattern - "you've arrived!"
    'destinationReached': [0, 100, 80, 100, 80, 100, 80, 300, 80, 500],

    // Urgent, repeating pattern - "caution"
    'hazardWarning': [0, 400, 100, 400, 100, 400],

    // Double-tap pattern followed by a pause - "crossing ahead"
    'crossingStreet': [0, 250, 100, 250, 400, 250, 100, 250],

    // Strong-weak-weak pattern - "turn left"
    'leftTurn': [0, 400, 200, 100, 200, 100],

    // Weak-weak-strong pattern - "turn right"
    'rightTurn': [0, 100, 200, 100, 200, 400],

    // Double-strong pulses - "make a U-turn"
    'uTurn': [0, 400, 200, 400, 200, 400],

    // Rapid, staccato vibrations - "recalculating route"
    'recalculating': [0, 80, 80, 80, 80, 80, 80, 80, 80, 300],

    // Emergency stop - critical pattern for immediate attention
    'emergencyStop': [0, 800, 200, 800, 200, 800, 200, 800, 200, 800],

    // Emergency rerouting - urgent pattern for quick action
    'emergencyRerouting': [0, 500, 100, 500, 100, 200, 100, 200, 100, 500],

    // New route available - notification for user
    'newRoute': [0, 300, 100, 300, 100, 300, 500],

    // Pause navigation - gentle reminder to the user
    'pauseNavigation': [0, 400, 400, 400, 400],

    // Slow down - gradual pattern to indicate slowing down
    'slowDown': [0, 100, 100, 200, 100, 300, 100, 400, 100],
  };

  // Initialize the vibration service
  Future<bool> initialize() async {
    try {
      // Properly identify platform
      if (Platform.isIOS) {
        _isIOS = true;
        _platformName = 'iOS';
      } else if (Platform.isAndroid) {
        _isAndroid = true;
        _platformName = 'Android';
      } else {
        // Handle other platforms
        if (Platform.isMacOS) {
          _platformName = 'macOS';
        } else if (Platform.isWindows) {
          _platformName = 'Windows';
        } else if (Platform.isLinux) {
          _platformName = 'Linux';
        } else if (Platform.isFuchsia) {
          _platformName = 'Fuchsia';
        } else {
          _platformName = 'unknown';
        }
      }

      _vibrationSupported = await hasVibrator();
      _amplitudeSupported = await hasAmplitudeControl();
      _isInitialized = true;

      debugPrint(
        'Vibration service initialized - Platform: $_platformName, '
        'Vibration support: $_vibrationSupported, '
        'Amplitude support: $_amplitudeSupported',
      );

      return _vibrationSupported;
    } catch (e) {
      debugPrint('Error initializing vibration service: $e');
      _isInitialized = false;
      return false;
    }
  }

  // Check if vibration is supported and initialized
  bool get isReady => _isInitialized && _vibrationSupported;

  // Check if device supports vibration
  Future<bool> hasVibrator() async {
    try {
      final result = await Vibration.hasVibrator();
      return result;
    } catch (e) {
      debugPrint('Error checking vibrator support: $e');
      return false;
    }
  }

  // Check if device supports amplitude control
  Future<bool> hasAmplitudeControl() async {
    try {
      final result = await Vibration.hasAmplitudeControl();
      return result;
    } catch (e) {
      debugPrint('Error checking amplitude support: $e');
      return false;
    }
  }

  // Test if vibration is working
  Future<bool> testVibration() async {
    if (!await hasVibrator()) {
      return false;
    }

    try {
      await Vibration.vibrate(duration: 300);
      return true;
    } catch (e) {
      debugPrint('Error during vibration test: $e');
      return false;
    }
  }

  // On route - slight vibration
  Future<void> onRouteFeedback({int intensity = lowIntensity}) async {
    if (!await hasVibrator()) return;

    try {
      await Vibration.vibrate(duration: 100, amplitude: intensity);
    } catch (e) {
      debugPrint('Error during onRouteFeedback: $e');
    }
  }

  // Approaching turn - double pulse
  Future<void> approachingTurnFeedback({
    int intensity = mediumIntensity,
  }) async {
    if (!await hasVibrator()) return;

    try {
      Vibration.vibrate(
        pattern: patterns['approachingTurn']!,
        amplitude: intensity,
      );
    } catch (e) {
      debugPrint('Error during approachingTurnFeedback: $e');
    }
  }

  // Wrong direction - long vibration
  Future<void> wrongDirectionFeedback({int intensity = highIntensity}) async {
    if (!await hasVibrator()) return;

    try {
      Vibration.vibrate(duration: 500, amplitude: intensity);
    } catch (e) {
      debugPrint('Error during wrongDirectionFeedback: $e');
    }
  }

  // Destination reached - triple pulse
  Future<void> destinationReachedFeedback({
    int intensity = mediumIntensity,
  }) async {
    if (!await hasVibrator()) return;

    try {
      Vibration.vibrate(
        pattern: patterns['destinationReached']!,
        amplitude: intensity,
      );
    } catch (e) {
      debugPrint('Error during destinationReachedFeedback: $e');
    }
  }

  // Left turn specific pattern
  Future<void> leftTurnFeedback({int intensity = mediumIntensity}) async {
    if (!await hasVibrator()) return;

    try {
      Vibration.vibrate(pattern: patterns['leftTurn']!, amplitude: intensity);
    } catch (e) {
      debugPrint('Error during leftTurnFeedback: $e');
    }
  }

  // Right turn specific pattern
  Future<void> rightTurnFeedback({int intensity = mediumIntensity}) async {
    if (!await hasVibrator()) return;

    try {
      Vibration.vibrate(pattern: patterns['rightTurn']!, amplitude: intensity);
    } catch (e) {
      debugPrint('Error during rightTurnFeedback: $e');
    }
  }

  // U-turn specific pattern
  Future<void> uTurnFeedback({int intensity = highIntensity}) async {
    if (!await hasVibrator()) return;

    try {
      Vibration.vibrate(pattern: patterns['uTurn']!, amplitude: intensity);
    } catch (e) {
      debugPrint('Error during uTurnFeedback: $e');
    }
  }

  // Street crossing warning
  Future<void> crossingStreetFeedback({int intensity = highIntensity}) async {
    if (!await hasVibrator()) return;

    try {
      Vibration.vibrate(
        pattern: patterns['crossingStreet']!,
        amplitude: intensity,
      );
    } catch (e) {
      debugPrint('Error during crossingStreetFeedback: $e');
    }
  }

  // Hazard warning
  Future<void> hazardWarningFeedback({int intensity = highIntensity}) async {
    if (!await hasVibrator()) return;

    try {
      Vibration.vibrate(
        pattern: patterns['hazardWarning']!,
        amplitude: intensity,
      );
    } catch (e) {
      debugPrint('Error during hazardWarningFeedback: $e');
    }
  }

  // Recalculating route
  Future<void> recalculatingRouteFeedback({
    int intensity = mediumIntensity,
  }) async {
    if (!await hasVibrator()) return;

    try {
      Vibration.vibrate(
        pattern: patterns['recalculating']!,
        amplitude: intensity,
      );
    } catch (e) {
      debugPrint('Error during recalculatingRouteFeedback: $e');
    }
  }

  // Play a pattern by name - enhanced implementation for better distinctiveness
  Future<void> playPattern(
    String patternName, {
    int intensity = mediumIntensity,
    bool repeat = false,
  }) async {
    if (!await hasVibrator()) {
      debugPrint('Device does not have vibration capability');
      return;
    }

    try {
      if (patterns.containsKey(patternName)) {
        debugPrint(
          'Playing pattern: $patternName with intensity: $intensity on $_platformName',
        );
        final pattern = patterns[patternName]!;
        debugPrint('Pattern: $pattern');

        // Stop any existing vibration first
        await stopVibration();
        await Future.delayed(const Duration(milliseconds: 150));

        if (_isIOS) {
          // iOS-specific implementation with intensity consideration
          await _playPatternForIOS(pattern, intensity);
        } else if (_isAndroid) {
          // Android implementation
          await _playPatternForAndroid(pattern, intensity, repeat);
        } else {
          // For unsupported platforms, log a message
          debugPrint('Vibration not implemented for $_platformName platform');
        }
      } else {
        debugPrint('Pattern not found: $patternName');
      }
    } catch (e) {
      debugPrint('Error playing pattern $patternName: $e');
      // Attempt fallback to simple vibration
      try {
        await Vibration.vibrate(duration: 300, amplitude: intensity);
      } catch (error) {
        debugPrint('Fallback vibration also failed: $error');
      }
    }
  }

  // Android-specific implementation
  Future<void> _playPatternForAndroid(
    List<int> pattern,
    int intensity,
    bool repeat,
  ) async {
    final hasAmplitude = await hasAmplitudeControl();
    if (hasAmplitude) {
      // Create varying intensities for more distinctiveness
      final intensities = _createVaryingIntensities(pattern, intensity);
      debugPrint('Intensities: $intensities');

      await Vibration.vibrate(
        pattern: pattern,
        intensities: intensities,
        repeat: repeat ? 0 : -1,
      );
    } else {
      // Fallback for devices without amplitude control
      await Vibration.vibrate(pattern: pattern, repeat: repeat ? 0 : -1);
    }
  }

  // iOS-specific implementation for playing patterns - improved for distinctiveness
  Future<void> _playPatternForIOS(List<int> pattern, int intensity) async {
    debugPrint(
      'Using improved iOS-specific vibration implementation with intensity: $intensity',
    );

    // Adjust the number of repetitions based on intensity to simulate stronger vibrations
    // Higher intensity = more repetitions on iOS
    int repetitions = 1;
    if (intensity > mediumIntensity + 50) {
      repetitions = 3; // High intensity
    } else if (intensity > lowIntensity + 20) {
      repetitions = 2; // Medium intensity
    }

    // For iOS, we manually implement the pattern with more precise timing
    for (int rep = 0; rep < repetitions; rep++) {
      for (int i = 0; i < pattern.length; i += 2) {
        int delay = pattern[i];
        int duration = i + 1 < pattern.length ? pattern[i + 1] : 0;

        // For low intensity, add more delay between vibrations
        if (intensity < lowIntensity + 20 && delay > 0) {
          await Future.delayed(Duration(milliseconds: delay + 50));
        } else if (delay > 0) {
          await Future.delayed(Duration(milliseconds: delay));
        }

        if (duration > 0) {
          // For iOS, we can't control amplitude, but we can adjust duration slightly
          // to give perception of different intensities
          int adjustedDuration = duration;
          if (intensity < lowIntensity + 20) {
            adjustedDuration = max(
              50,
              duration - 50,
            ); // Shorter for low intensity
          } else if (intensity > mediumIntensity + 50) {
            adjustedDuration = min(
              600,
              duration + 50,
            ); // Longer for high intensity
          }

          await Vibration.vibrate(duration: adjustedDuration);

          // Add a minimum gap to ensure vibrations are distinct
          if (i + 2 < pattern.length) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      }

      // Add pause between repetitions if doing multiple
      if (rep < repetitions - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  // Simple vibration test - improved for platform-specific behavior
  Future<bool> simpleVibrate({int duration = 300, int? amplitude}) async {
    try {
      if (_isIOS) {
        // For iOS, ignore amplitude
        await Vibration.vibrate(duration: duration);
      } else if (_isAndroid &&
          amplitude != null &&
          await hasAmplitudeControl()) {
        // For Android with amplitude support
        await Vibration.vibrate(duration: duration, amplitude: amplitude);
      } else if (_vibrationSupported) {
        // Generic implementation for other platforms with vibration
        await Vibration.vibrate(duration: duration);
      } else {
        debugPrint('Vibration not supported on this platform: $_platformName');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Simple vibration test failed: $e');
      return false;
    }
  }

  // Helper method to generate intensity array for patterns - fixed implementation
  List<int> _generateIntensities(List<int> pattern, int baseIntensity) {
    // For each vibration in pattern (even indices are delays, odd indices are durations)
    // We need to create an intensity value
    int vibrationCount = pattern.length ~/ 2;

    // Create a list with the same intensity for each vibration duration
    return List<int>.filled(vibrationCount, baseIntensity);
  }

  // Create varying intensities for more distinctive patterns
  List<int> _createVaryingIntensities(List<int> pattern, int baseIntensity) {
    // For each vibration in pattern (even indices are delays, odd indices are durations)
    // We need to create an intensity value
    List<int> intensities = [];

    for (int i = 0; i < pattern.length; i += 2) {
      if (i + 1 < pattern.length) {
        // Vary intensity based on duration to make patterns more distinctive
        int duration = pattern[i + 1];

        // Base the variation on the provided intensity parameter
        int intensity = baseIntensity;

        // Longer vibrations get higher intensity (up to maximum)
        if (duration > 300) {
          intensity = min(255, baseIntensity + 30);
        } else if (duration < 150) {
          intensity = max(1, baseIntensity - 20);
        }

        // Ensure intensity is within valid range (1-255)
        intensity = max(1, min(255, intensity));

        intensities.add(intensity);
      }
    }

    return intensities;
  }

  // Better implementation of customVibration
  Future<void> customVibration({
    required List<int> pattern,
    int amplitude = mediumIntensity,
    bool repeat = false,
  }) async {
    if (!await hasVibrator()) return;

    try {
      final hasAmplitude = await hasAmplitudeControl();

      if (hasAmplitude) {
        Vibration.vibrate(
          pattern: pattern,
          intensities: _generateIntensities(pattern, amplitude),
          repeat: repeat ? 0 : -1,
        );
      } else {
        Vibration.vibrate(pattern: pattern, repeat: repeat ? 0 : -1);
      }
    } catch (e) {
      debugPrint('Error during customVibration: $e');

      // Try fallback
      try {
        await Vibration.vibrate(duration: 300);
      } catch (_) {
        // Fallback failed
      }
    }
  }

  // Stop ongoing vibration
  Future<void> stopVibration() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('Error stopping vibration: $e');
    }
  }

  // Emergency stop feedback - most intense and longest pattern
  Future<void> emergencyStopFeedback() async {
    return playPattern('emergencyStop', intensity: highIntensity);
  }

  // Emergency rerouting feedback
  Future<void> emergencyReroutingFeedback() async {
    return playPattern('emergencyRerouting', intensity: highIntensity);
  }

  // New route available feedback
  Future<void> newRouteFeedback() async {
    return playPattern('newRoute', intensity: mediumIntensity);
  }

  // Pause navigation feedback
  Future<void> pauseNavigationFeedback() async {
    return playPattern('pauseNavigation', intensity: mediumIntensity);
  }

  // Slow down feedback
  Future<void> slowDownFeedback() async {
    return playPattern('slowDown', intensity: mediumIntensity);
  }
}
