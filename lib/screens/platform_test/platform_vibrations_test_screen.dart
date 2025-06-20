import 'package:flutter/material.dart';
import '../../services/vibration_service.dart';
import '../../utils/theme_config.dart';
import 'dart:io' show Platform;

class PlatformVibrationsTestScreen extends StatefulWidget {
  const PlatformVibrationsTestScreen({super.key});

  @override
  State<PlatformVibrationsTestScreen> createState() =>
      _PlatformVibrationsTestScreenState();
}

class _PlatformVibrationsTestScreenState
    extends State<PlatformVibrationsTestScreen> {
  final VibrationService _vibrationService = VibrationService();
  int _currentIntensity = VibrationService.mediumIntensity;

  String get _platformName {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Platform Vibrations Test ($_platformName)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Platform info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(ThemeConfig.standardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Platform: $_platformName',
                      style: const TextStyle(
                        fontSize: ThemeConfig.largeText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Platform.isIOS
                          ? 'Using iOS-optimized patterns with longer durations'
                          : 'Using Android-native patterns',
                      style: const TextStyle(fontSize: ThemeConfig.mediumText),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Intensity control
            Card(
              child: Padding(
                padding: const EdgeInsets.all(ThemeConfig.standardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Intensity: $_currentIntensity',
                      style: const TextStyle(
                        fontSize: ThemeConfig.mediumText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      value: _currentIntensity.toDouble(),
                      min: 50,
                      max: 255,
                      divisions: 8,
                      onChanged: (value) {
                        setState(() {
                          _currentIntensity = value.round();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Pattern tests
            Card(
              child: Padding(
                padding: const EdgeInsets.all(ThemeConfig.standardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Navigation Patterns',
                      style: TextStyle(
                        fontSize: ThemeConfig.largeText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: ThemeConfig.standardPadding),
                    ...VibrationService.patterns.keys.map((patternName) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _vibrationService.playPattern(
                                patternName,
                                intensity: _currentIntensity,
                              );
                            },
                            child: Text(_getPatternDisplayName(patternName)),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Platform comparison
            Card(
              child: Padding(
                padding: const EdgeInsets.all(ThemeConfig.standardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Platform Differences',
                      style: TextStyle(
                        fontSize: ThemeConfig.largeText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: ThemeConfig.standardPadding),
                    if (Platform.isIOS) ...[
                      const Text('iOS Optimizations:'),
                      const Text('• Longer vibration durations'),
                      const Text('• +20% intensity boost'),
                      const Text('• Fallback for amplitude control'),
                      const Text('• Pattern segmentation for long vibrations'),
                    ] else if (Platform.isAndroid) ...[
                      const Text('Android Features:'),
                      const Text('• Direct intensity mapping'),
                      const Text('• Native pattern support'),
                      const Text('• Full amplitude control'),
                      const Text('• Precise timing control'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Test platform optimization
            ElevatedButton(
              onPressed: () async {
                await _vibrationService.platformOptimizedVibrate(
                  duration: 500,
                  intensity: _currentIntensity,
                );
              },
              child: const Text('Test Platform Optimized Vibration'),
            ),
          ],
        ),
      ),
    );
  }

  String _getPatternDisplayName(String patternName) {
    switch (patternName) {
      case 'onRoute':
        return 'On Route';
      case 'approachingTurn':
        return 'Approaching Turn';
      case 'leftTurn':
        return 'Left Turn';
      case 'rightTurn':
        return 'Right Turn';
      case 'wrongDirection':
        return 'Wrong Direction';
      case 'destinationReached':
        return 'Destination Reached';
      case 'crossingStreet':
        return 'Crossing Street';
      case 'hazardWarning':
        return 'Hazard Warning';
      default:
        return patternName;
    }
  }
}
